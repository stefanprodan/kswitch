// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Combine
import Domain
import Infrastructure

@MainActor
@Observable
final class AppState {
    // Persisted
    var clusters: [Cluster] = []
    var settings: AppSettings = .default

    // Runtime
    var currentContext: String = ""
    var clusterStatuses: [String: ClusterStatus] = [:]
    var refreshingContexts: Set<String> = []
    var isRefreshing: Bool = false
    var error: String?
    var pendingClusterNavigation: Cluster?
    var pendingSettingsNavigation: Bool = false
    var detectedKubectlPath: String?

    // Background refresh
    private var refreshTask: Task<Void, Never>?
    private var isBackgroundRefreshEnabled: Bool = true

    // Services (not observed)
    @ObservationIgnored
    private var _kubectl: KubectlRunner?

    @ObservationIgnored
    private var _kubeconfigWatcher: KubeconfigWatcher?

    @ObservationIgnored
    nonisolated(unsafe) private var _settingsSnapshot: AppSettings = .default

    private func getKubectl() -> KubectlRunner {
        // Update settings snapshot for the service
        _settingsSnapshot = settings

        if let kubectl = _kubectl {
            return kubectl
        }

        // Capture a reference to the snapshot that can be read from any context
        let service = KubectlRunner { [weak self] in
            self?._settingsSnapshot ?? .default
        }
        _kubectl = service
        return service
    }

    init() {
        loadFromDisk()
        AppLog.info("AppState initialized")

        // Start watching kubeconfig for external changes
        setupKubeconfigWatcher()

        // Initialize on launch
        Task { @MainActor [weak self] in
            await NotificationAlerter.shared.requestAuthorization()
            guard let self else { return }

            // Detect kubectl path if not configured
            if self.settings.kubectlPath == nil {
                self.detectedKubectlPath = await ShellEnvironment.shared.findExecutable(named: "kubectl")
                if let path = self.detectedKubectlPath {
                    AppLog.info("Auto-detected kubectl at: \(path)")
                }
            }

            AppLog.info("Starting context refresh...")
            await self.refreshContexts()
            AppLog.info("Contexts refreshed, current: \(self.currentContext)")
            if !self.currentContext.isEmpty {
                await self.refreshStatus(for: self.currentContext)
            }
            self.startBackgroundRefresh()
            AppLog.info("Initialization complete")
        }
    }

    private func setupKubeconfigWatcher() {
        _kubeconfigWatcher?.stop()
        let kubeconfigPath = settings.effectiveKubeconfigPaths.first
        _kubeconfigWatcher = KubeconfigWatcher(kubeconfigPath: kubeconfigPath) { [weak self] in
            guard let self else { return }
            Task {
                await self.handleKubeconfigChange()
            }
        }
        _kubeconfigWatcher?.start()
    }

    private func handleKubeconfigChange() async {
        AppLog.info("Handling kubeconfig change...")
        let newContext = try? await getKubectl().getCurrentContext()
        if let newContext, newContext != currentContext {
            AppLog.info("Context changed externally: \(currentContext) -> \(newContext)")
            currentContext = newContext
            await refreshStatus(for: newContext)
        }
        await refreshContexts()
    }

    // MARK: - Storage

    func loadFromDisk() {
        clusters = AppStorage.shared.loadClusters()
        settings = AppStorage.shared.loadSettings()
    }

    func saveToDisk() {
        AppStorage.shared.save(clusters: clusters, settings: settings)
        setupKubeconfigWatcher()
    }

    // MARK: - Background Refresh

    func startBackgroundRefresh() {
        stopBackgroundRefresh()

        guard settings.refreshIntervalSeconds > 0 else { return }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isBackgroundRefreshEnabled else { break }

                // Sleep first, then refresh
                try? await Task.sleep(for: .seconds(self.settings.refreshIntervalSeconds))

                // Refresh status (context changes handled by KubeconfigWatcher)
                if !self.currentContext.isEmpty {
                    await self.refreshStatus(for: self.currentContext)
                }
            }
        }
    }

    func stopBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func pauseBackgroundRefresh() {
        isBackgroundRefreshEnabled = false
    }

    func resumeBackgroundRefresh() {
        isBackgroundRefreshEnabled = true
        if refreshTask == nil {
            startBackgroundRefresh()
        }
    }

    // MARK: - Context Operations

    func refreshContexts() async {
        do {
            let contextNames = try await getKubectl().getContexts()
            currentContext = (try? await getKubectl().getCurrentContext()) ?? ""
            clusters = clusters.synced(with: contextNames)
            saveToDisk()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func switchContext(to contextName: String) async {
        do {
            try await getKubectl().setCurrentContext(contextName)
            currentContext = contextName
            await refreshStatus(for: contextName)
            startBackgroundRefresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Status Refresh

    func refreshStatus(for contextName: String) async {
        refreshingContexts.insert(contextName)
        defer { refreshingContexts.remove(contextName) }

        let previousStatus = clusterStatuses[contextName]
        var status = clusterStatuses[contextName] ?? ClusterStatus()

        // Only publish checking state if we don't have previous data
        // This prevents UI flickering by keeping stale data visible
        if previousStatus == nil {
            status.reachability = .checking
            status.fluxOperator = .checking
            clusterStatuses[contextName] = status
        }

        let clusterName = cluster(for: contextName)?.effectiveName ?? contextName

        // Try to get version - this also serves as reachability check
        let kubectlService = getKubectl()
        do {
            let version = try await kubectlService.getVersion(context: contextName)
            status.kubernetesVersion = version
            status.reachability = .reachable

            // Send notification if cluster became reachable again
            if settings.notificationsEnabled,
               case .unreachable = previousStatus?.reachability {
                await NotificationAlerter.shared.notifyClusterReachable(clusterName: clusterName)
            }
        } catch {
            let errorMsg: String
            if let kswitchError = error as? KSwitchError {
                errorMsg = kswitchError.errorDescription ?? error.localizedDescription
            } else {
                errorMsg = error.localizedDescription
            }
            status.reachability = .unreachable(errorMsg)
            status.fluxOperator = .unknown
            status.lastChecked = Date()
            clusterStatuses[contextName] = status

            // Send notification if cluster became unreachable
            if settings.notificationsEnabled,
               case .reachable = previousStatus?.reachability {
                await NotificationAlerter.shared.notifyClusterUnreachable(clusterName: clusterName)
            }
            return
        }

        // Fetch nodes and Flux report concurrently
        async let nodesTask = kubectlService.getNodes(context: contextName)
        async let fluxReport = kubectlService.getFluxReport(context: contextName)

        // Process nodes
        do {
            status.nodes = try await nodesTask
            status.nodeError = nil
        } catch {
            status.nodes = []
            if let kswitchError = error as? KSwitchError {
                status.nodeError = kswitchError.errorDescription ?? error.localizedDescription
            } else {
                status.nodeError = error.localizedDescription
            }
            AppLog.warning("Failed to get nodes for \(contextName): \(status.nodeError ?? "unknown")")
        }

        // Process Flux report
        do {
            let report = try await fluxReport
            status.fluxReport = report
            status.fluxError = nil
            let summary = FluxReportSummary(from: report)
            status.fluxSummary = summary

            if summary.isDistributionInstalled {
                if summary.isHealthy {
                    status.fluxOperator = .installed(
                        version: summary.distributionVersion,
                        healthy: true
                    )
                } else {
                    AppLog.warning("Flux degraded for \(contextName): \(summary.totalFailing) failing")
                    status.fluxOperator = .degraded(
                        version: summary.distributionVersion,
                        failing: summary.totalFailing
                    )
                }
            } else {
                // Operator is installed (we have FluxReport) but distribution is not
                status.fluxOperator = .operatorOnly(version: summary.operatorVersion)
            }
        } catch KSwitchError.fluxReportNotFound {
            status.fluxOperator = .notInstalled
            status.fluxError = nil
        } catch {
            status.fluxOperator = .unknown
            if let kswitchError = error as? KSwitchError {
                status.fluxError = kswitchError.errorDescription ?? error.localizedDescription
            } else {
                status.fluxError = error.localizedDescription
            }
            AppLog.warning("Failed to get FluxReport for \(contextName): \(status.fluxError ?? "unknown")")
        }

        // Send notification if Flux failures increased
        if settings.notificationsEnabled,
           let summary = status.fluxSummary,
           summary.totalFailing > 0 {
            let previousFailing = previousStatus?.fluxSummary?.totalFailing ?? 0
            if summary.totalFailing > previousFailing {
                await NotificationAlerter.shared.notifyFluxFailures(
                    clusterName: clusterName,
                    failingCount: summary.totalFailing
                )
            }
        }

        status.lastChecked = Date()
        clusterStatuses[contextName] = status
    }

    func refreshAllStatuses() async {
        isRefreshing = true

        // Refresh kubeconfig first
        await refreshContexts()

        // Refresh all non-hidden cluster statuses in parallel
        await withTaskGroup(of: Void.self) { group in
            for cluster in clusters where !cluster.isHidden && cluster.isInKubeconfig {
                group.addTask {
                    await self.refreshStatus(for: cluster.contextName)
                }
            }
        }

        isRefreshing = false
    }

    // MARK: - Cluster Management

    func updateCluster(_ cluster: Cluster) {
        if let index = clusters.firstIndex(where: { $0.id == cluster.id }) {
            clusters[index] = cluster
            saveToDisk()
        }
    }

    func deleteCluster(_ cluster: Cluster) {
        clusters.removeAll { $0.id == cluster.id }
        clusterStatuses.removeValue(forKey: cluster.contextName)
        saveToDisk()
    }

    func cluster(for contextName: String) -> Cluster? {
        clusters.first { $0.contextName == contextName }
    }

    var visibleClusters: [Cluster] {
        clusters.filter { !$0.isHidden }
    }

    var favoriteClusters: [Cluster] {
        clusters.filter { $0.isFavorite && !$0.isHidden }
    }

    var hiddenClusters: [Cluster] {
        clusters.filter { $0.isHidden }
    }

    var currentCluster: Cluster? {
        cluster(for: currentContext)
    }

    var currentClusterStatus: ClusterStatus? {
        clusterStatuses[currentContext]
    }
}
