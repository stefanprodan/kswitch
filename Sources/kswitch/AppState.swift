import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    // Persisted
    var clusters: [Cluster] = []
    var settings: AppSettings = .default

    // Runtime
    var currentContext: String = ""
    var clusterStatuses: [String: ClusterStatus] = [:]
    var isRefreshing: Bool = false
    var error: String?
    var pendingClusterNavigation: Cluster?
    var pendingSettingsNavigation: Bool = false

    // Background refresh
    private var refreshTask: Task<Void, Never>?
    private var isBackgroundRefreshEnabled: Bool = true

    // Services (not observed)
    @ObservationIgnored
    private var _kubectl: KubectlService?

    @ObservationIgnored
    private var _kubeconfigWatcher: KubeconfigWatcher?

    @ObservationIgnored
    nonisolated(unsafe) private var _settingsSnapshot: AppSettings = .default

    private func getKubectl() -> KubectlService {
        // Update settings snapshot for the service
        _settingsSnapshot = settings

        if let kubectl = _kubectl {
            return kubectl
        }

        // Capture a reference to the snapshot that can be read from any context
        let service = KubectlService { [weak self] in
            self?._settingsSnapshot ?? .default
        }
        _kubectl = service
        return service
    }

    init() {
        loadFromDisk()
        Log.info("AppState initialized")

        // Start watching kubeconfig for external changes
        setupKubeconfigWatcher()

        // Initialize on launch
        Task { @MainActor [weak self] in
            await NotificationService.shared.requestAuthorization()
            guard let self else { return }
            Log.info("Starting context refresh...")
            await self.refreshContexts()
            Log.info("Contexts refreshed, current: \(self.currentContext)")
            if !self.currentContext.isEmpty {
                await self.refreshStatus(for: self.currentContext)
            }
            self.startBackgroundRefresh()
            Log.info("Initialization complete")
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
        Log.info("Handling kubeconfig change...")
        let newContext = try? await getKubectl().getCurrentContext()
        if let newContext, newContext != currentContext {
            Log.info("Context changed externally: \(currentContext) -> \(newContext)")
            currentContext = newContext
            await refreshStatus(for: newContext)
        }
        await refreshContexts()
    }

    // MARK: - Storage

    private var storageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KSwitch", isDirectory: true)
    }

    private var clustersFileURL: URL {
        storageURL.appendingPathComponent("clusters.json")
    }

    private var settingsFileURL: URL {
        storageURL.appendingPathComponent("settings.json")
    }

    func loadFromDisk() {
        let fm = FileManager.default

        // Load clusters
        if fm.fileExists(atPath: clustersFileURL.path) {
            do {
                let data = try Data(contentsOf: clustersFileURL)
                clusters = try JSONDecoder().decode([Cluster].self, from: data)
            } catch {
                Log.error("Failed to load clusters: \(error)")
            }
        }

        // Load settings
        if fm.fileExists(atPath: settingsFileURL.path) {
            do {
                let data = try Data(contentsOf: settingsFileURL)
                settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                Log.error("Failed to load settings: \(error)")
            }
        }
    }

    func saveToDisk() {
        let fm = FileManager.default

        do {
            // Ensure directory exists
            try fm.createDirectory(at: storageURL, withIntermediateDirectories: true)

            // Save clusters
            let clustersData = try JSONEncoder().encode(clusters)
            try clustersData.write(to: clustersFileURL)

            // Save settings
            let settingsData = try JSONEncoder().encode(settings)
            try settingsData.write(to: settingsFileURL)

            // Restart kubeconfig watcher in case the path changed
            setupKubeconfigWatcher()
        } catch {
            Log.error("Failed to save: \(error)")
        }
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

            // Build a map of existing clusters by context name
            let existingByContext = Dictionary(uniqueKeysWithValues: clusters.map { ($0.contextName, $0) })

            // Track which contexts are still in kubeconfig
            var seenContexts = Set<String>()
            var updated: [Cluster] = []

            for (index, name) in contextNames.enumerated() {
                seenContexts.insert(name)
                if var existing = existingByContext[name] {
                    existing.sortOrder = index
                    existing.isInKubeconfig = true
                    updated.append(existing)
                } else {
                    var new = Cluster(contextName: name)
                    new.sortOrder = index
                    updated.append(new)
                }
            }

            // Keep clusters that were removed from kubeconfig (grayed out)
            for cluster in clusters where !seenContexts.contains(cluster.contextName) {
                var removed = cluster
                removed.isInKubeconfig = false
                updated.append(removed)
            }

            clusters = updated.sorted { $0.sortOrder < $1.sortOrder }
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
        let previousStatus = clusterStatuses[contextName]
        var status = clusterStatuses[contextName] ?? ClusterStatus()
        status.reachability = .checking
        status.fluxOperator = .checking
        clusterStatuses[contextName] = status

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
                await NotificationService.shared.notifyClusterReachable(clusterName: clusterName)
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
                await NotificationService.shared.notifyClusterUnreachable(clusterName: clusterName)
            }
            return
        }

        // Fetch node count and Flux report concurrently
        async let nodeCount = kubectlService.getNodeCount(context: contextName)
        async let fluxReport = kubectlService.getFluxReport(context: contextName)

        status.nodeCount = try? await nodeCount

        // Process Flux report
        do {
            let report = try await fluxReport
            status.fluxReport = report
            let summary = FluxReportSummary(from: report)
            status.fluxSummary = summary

            if summary.isInstalled {
                if summary.isHealthy {
                    status.fluxOperator = .installed(
                        version: summary.distributionVersion,
                        healthy: true
                    )
                } else {
                    Log.warning("Flux degraded for \(contextName): \(summary.totalFailing) failing")
                    status.fluxOperator = .degraded(
                        version: summary.distributionVersion,
                        failing: summary.totalFailing
                    )
                }
            } else {
                status.fluxOperator = .notInstalled
            }
        } catch KSwitchError.fluxReportNotFound {
            status.fluxOperator = .notInstalled
        } catch {
            status.fluxOperator = .notInstalled
        }

        // Send notification if Flux failures increased
        if settings.notificationsEnabled,
           let summary = status.fluxSummary,
           summary.totalFailing > 0 {
            let previousFailing = previousStatus?.fluxSummary?.totalFailing ?? 0
            if summary.totalFailing > previousFailing {
                await NotificationService.shared.notifyFluxFailures(
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
