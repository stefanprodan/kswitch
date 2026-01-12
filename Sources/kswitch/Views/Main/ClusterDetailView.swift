import SwiftUI

struct ClusterDetailView: View {
    @Environment(AppState.self) private var appState
    let cluster: Cluster
    @State private var showingEditSheet = false

    private var status: ClusterStatus? {
        appState.clusterStatuses[cluster.contextName]
    }

    // Get current cluster from AppState to reflect live changes
    private var currentCluster: Cluster {
        appState.clusters.first { $0.contextName == cluster.contextName } ?? cluster
    }

    var body: some View {
        Group {
            if status == nil {
                // Full page loader - no data yet
                ProgressView("Loading cluster status...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection

                        Divider()

                        kubernetesInfoSection(status: status!)

                        Divider()

                        fluxInfoSection(status: status!)

                        if status!.fluxReport?.sync != nil {
                            Divider()

                            fluxSyncSection(status: status!)
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(currentCluster.effectiveName)
        .toolbar {
            ToolbarItem {
                Text("Cluster")
                    .font(.headline)
            }

            ToolbarItem(id: "detail-flexible-space") {
                Spacer()
            }

            ToolbarItem {
                Button {
                    Task { await appState.refreshStatus(for: cluster.contextName) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(!cluster.isInKubeconfig)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ClusterEditSheet(cluster: currentCluster)
        }
        .task {
            // Refresh status when view appears (needed for hidden clusters that are skipped in refreshAllStatuses)
            if status == nil {
                await appState.refreshStatus(for: cluster.contextName)
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cluster info row
            HStack(spacing: 12) {
                // Colored icon instead of color dot
                Image(systemName: "cube.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(currentCluster.color)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button {
                            showingEditSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                                Text(currentCluster.effectiveName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            var updated = currentCluster
                            updated.isFavorite.toggle()
                            appState.updateCluster(updated)
                        } label: {
                            Image(systemName: currentCluster.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(currentCluster.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)

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
                    reachabilityText(status)
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
            }
        }
    }

    @ViewBuilder
    private func fluxInfoSection(status: ClusterStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flux")
                .font(.headline)

            // If we have summary data, always show it (even during refresh)
            if let summary = status.fluxSummary {
                fluxSummaryGrid(summary: summary)
            } else {
                // No previous data - show status based on operator state
                switch status.fluxOperator {
                case .notInstalled:
                    Text("Flux Operator not installed")
                        .foregroundStyle(.secondary)

                case .installed, .degraded:
                    // Shouldn't happen if we have no summary, but handle it
                    Text("Loading...")
                        .foregroundStyle(.secondary)

                case .checking:
                    ProgressView("Checking Flux status...")

                case .unknown:
                    Text("Status unknown")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func fluxSyncSection(status: ClusterStatus) -> some View {
        if let sync = status.fluxReport?.sync {
            VStack(alignment: .leading, spacing: 12) {
                Text("Flux Sync")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        HStack {
                            if sync.ready {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Ready")
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Not Ready")
                            }
                        }
                    }

                    if let source = sync.source {
                        GridRow {
                            Text("Source")
                                .foregroundStyle(.secondary)
                            Text(source)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    if let path = sync.path {
                        GridRow {
                            Text("Path")
                                .foregroundStyle(.secondary)
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                }
            }
        }
    }

    @ViewBuilder
    private func fluxSummaryGrid(summary: FluxReportSummary) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            // Status first (renamed from Health)
            GridRow {
                Text("Status")
                    .foregroundStyle(.secondary)
                HStack {
                    if summary.totalFailing == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Healthy")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("\(summary.totalFailing) failing")
                    }
                }
            }

            GridRow {
                Text("Distribution")
                    .foregroundStyle(.secondary)
                Text(summary.distributionVersion)
            }

            GridRow {
                Text("Operator")
                    .foregroundStyle(.secondary)
                Text(summary.operatorVersion)
            }

            GridRow {
                Text("Controllers")
                    .foregroundStyle(.secondary)
                Text("\(summary.componentsTotal)")
            }
        }
    }

    @ViewBuilder
    private func reachabilityText(_ status: ClusterStatus) -> some View {
        switch status.reachability {
        case .reachable:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: 14, height: 14)
                Text("Reachable")
            }
        case .unreachable(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .frame(width: 14, height: 14)
                Text("Unreachable")
            }
            .help(error)
        case .checking:
            HStack {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
                Text("Checking...")
            }
        case .unknown:
            Text("Unknown")
                .foregroundStyle(.secondary)
        }
    }
}
