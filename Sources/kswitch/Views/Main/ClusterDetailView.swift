import SwiftUI

struct ClusterDetailView: View {
    @Environment(AppState.self) private var appState
    let cluster: Cluster
    @State private var showingEditSheet = false

    private var status: ClusterStatus? {
        appState.clusterStatuses[cluster.contextName]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                Divider()

                // Kubernetes Info
                if let status = status {
                    kubernetesInfoSection(status: status)

                    Divider()

                    // Flux Info
                    fluxInfoSection(status: status)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(cluster.effectiveName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.switchContext(to: cluster.contextName) }
                } label: {
                    Label("Switch to Context", systemImage: "arrow.triangle.swap")
                }
                .disabled(cluster.contextName == appState.currentContext || !cluster.isInKubeconfig)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.refreshStatus(for: cluster.contextName) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!cluster.isInKubeconfig)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ClusterEditSheet(cluster: cluster)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(cluster.color)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cluster.effectiveName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if cluster.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }

                    if cluster.contextName == appState.currentContext {
                        Text("Current")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    if !cluster.isInKubeconfig {
                        Text("Removed")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(cluster.contextName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let status = status {
                StatusIndicator(status: status.statusColor)
                    .scaleEffect(1.5)
            }
        }
    }

    @ViewBuilder
    private func kubernetesInfoSection(status: ClusterStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kubernetes")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    reachabilityText(status.reachability)
                }

                if let version = status.kubernetesVersion {
                    GridRow {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Text(version)
                    }
                }

                if let nodes = status.nodeCount {
                    GridRow {
                        Text("Nodes")
                            .foregroundStyle(.secondary)
                        Text("\(nodes)")
                    }
                }

                if let lastChecked = status.lastChecked {
                    GridRow {
                        Text("Last Checked")
                            .foregroundStyle(.secondary)
                        Text(lastChecked.formatted(.relative(presentation: .named)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fluxInfoSection(status: ClusterStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flux")
                .font(.headline)

            switch status.fluxOperator {
            case .notInstalled:
                Text("Flux Operator not installed")
                    .foregroundStyle(.secondary)

            case .installed(let version, let healthy):
                fluxDetailsGrid(version: version, healthy: healthy, status: status)

            case .degraded(let version, let failing):
                fluxDetailsGrid(version: version, healthy: false, failing: failing, status: status)

            case .checking:
                ProgressView("Checking Flux status...")

            case .unknown:
                Text("Status unknown")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func fluxDetailsGrid(version: String, healthy: Bool, failing: Int = 0, status: ClusterStatus) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Distribution")
                    .foregroundStyle(.secondary)
                Text(version)
            }

            if let summary = status.fluxSummary {
                GridRow {
                    Text("Operator")
                        .foregroundStyle(.secondary)
                    Text(summary.operatorVersion)
                }

                GridRow {
                    Text("Health")
                        .foregroundStyle(.secondary)
                    HStack {
                        if healthy {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Healthy")
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("\(failing) failing")
                        }
                    }
                }

                GridRow {
                    Text("Running")
                        .foregroundStyle(.secondary)
                    Text("\(summary.totalRunning)")
                }

                if summary.totalSuspended > 0 {
                    GridRow {
                        Text("Suspended")
                            .foregroundStyle(.secondary)
                        Text("\(summary.totalSuspended)")
                    }
                }

                if let syncPath = summary.syncPath {
                    GridRow {
                        Text("Sync Path")
                            .foregroundStyle(.secondary)
                        Text(syncPath)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reachabilityText(_ reachability: ClusterStatus.Reachability) -> some View {
        switch reachability {
        case .reachable:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Reachable")
            }
        case .unreachable(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Unreachable")
            }
            .help(error)
        case .checking:
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Checking...")
            }
        case .unknown:
            Text("Unknown")
                .foregroundStyle(.secondary)
        }
    }
}
