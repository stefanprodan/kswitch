import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Current cluster info section
        if let cluster = appState.currentCluster {
            currentClusterSection(cluster: cluster)
        } else if !appState.currentContext.isEmpty {
            Section {
                Text(appState.currentContext)
                    .fontWeight(.medium)
            }
        }

        Divider()

        // Cluster submenu
        Menu("Switch Cluster") {
            ForEach(appState.visibleClusters.filter { $0.isInKubeconfig }) { cluster in
                clusterButton(cluster: cluster)
            }

            // Show grayed-out removed clusters
            let removedClusters = appState.visibleClusters.filter { !$0.isInKubeconfig }
            if !removedClusters.isEmpty {
                Divider()
                ForEach(removedClusters) { cluster in
                    clusterButton(cluster: cluster)
                        .disabled(true)
                }
            }
        }

        Divider()

        Button("Open KSwitch...") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o", modifiers: .command)

        Button {
            Task {
                await appState.refreshStatus(for: appState.currentContext)
            }
        } label: {
            if appState.isRefreshing {
                Text("Refreshing...")
            } else {
                Text("Refresh")
            }
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(appState.isRefreshing)

        Divider()

        Link("Give Feedback...", destination: URL(string: "https://github.com/controlplaneio-fluxcd/kswitch/issues")!)

        Button("Check for Updates...") {
            UpdateService.shared.checkForUpdates()
        }
        .disabled(!UpdateService.shared.canCheckForUpdates)

        Button("About KSwitch") {
            NSApplication.shared.orderFrontStandardAboutPanel()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private func currentClusterSection(cluster: Cluster) -> some View {
        // Clickable cluster name - opens main window
        Button {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            Text(cluster.effectiveName)
        }

        // Status info with symbol (non-interactive)
        if let status = appState.clusterStatuses[cluster.contextName] {
            let symbol = statusSymbol(for: cluster)
            let info: String = {
                switch status.reachability {
                case .unreachable:
                    return "\(symbol) Unreachable"
                case .checking:
                    return "\(symbol) Checking..."
                case .unknown:
                    return "\(symbol) Unknown"
                case .reachable:
                    if let version = status.kubernetesVersion, let nodes = status.nodeCount {
                        return "\(symbol) \(version) • \(nodes) nodes"
                    } else if let version = status.kubernetesVersion {
                        return "\(symbol) \(version)"
                    } else {
                        return "\(symbol) Connected"
                    }
                }
            }()
            Text(info)
        }
    }

    private func statusSymbol(for cluster: Cluster) -> String {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return "○"
        }
        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                return "⚠"
            }
            return "✓"
        case .unreachable:
            return "✗"
        case .checking:
            return "↻"
        case .unknown:
            return "○"
        }
    }

    @ViewBuilder
    private func clusterButton(cluster: Cluster) -> some View {
        Button {
            Task { await appState.switchContext(to: cluster.contextName) }
        } label: {
            HStack {
                Circle()
                    .fill(cluster.color)
                    .frame(width: 8, height: 8)
                Text(cluster.effectiveName)

                Spacer()

                // Status indicator
                if let status = appState.clusterStatuses[cluster.contextName] {
                    statusIndicator(for: status)
                }

                // Checkmark for current context
                if cluster.contextName == appState.currentContext {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(for status: ClusterStatus) -> some View {
        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                Circle().fill(.yellow).frame(width: 6, height: 6)
            } else {
                Circle().fill(.green).frame(width: 6, height: 6)
            }
        case .unreachable:
            Circle().fill(.red).frame(width: 6, height: 6)
        case .checking:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 6, height: 6)
        case .unknown:
            Circle().fill(.gray).frame(width: 6, height: 6)
        }
    }
}
