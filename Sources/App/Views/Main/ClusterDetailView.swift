import SwiftUI
import Domain
import Infrastructure

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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if let status = status {
                        Divider()

                        kubernetesInfoSection(status: status)

                        if case .unreachable(let error) = status.reachability {
                            errorPanel(message: error)
                        } else {
                            Divider()

                            fluxInfoSection(status: status)

                            if status.fluxReport?.sync != nil {
                                Divider()

                                fluxSyncSection(status: status)
                            }

                            if let reconcilers = status.fluxReport?.reconcilers, !reconcilers.isEmpty {
                                Divider()

                                fluxReconcilersSection(reconcilers: reconcilers)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Cluster")
        .toolbar {
            ToolbarItem(id: "detail-flexible-space") {
                Spacer()
            }

            if !cluster.isInKubeconfig {
                ToolbarItem {
                    Button {
                        appState.deleteCluster(cluster)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete cluster from saved list")
                }
            }

            ToolbarItem {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit cluster")
            }

            ToolbarItem {
                Button {
                    Task { await appState.refreshStatus(for: cluster.contextName) }
                } label: {
                    if status?.reachability == .checking {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(!cluster.isInKubeconfig || status?.reachability == .checking)
                .help("Refresh cluster status")
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
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
                // Kubernetes helm icon
                Image(systemName: "helm")
                    .font(.system(size: 32))
                    .foregroundStyle(currentCluster.color)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(currentCluster.effectiveName)
                            .font(.title3)
                            .fontWeight(.semibold)

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
                        .textSelection(.enabled)
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
                            .textSelection(.enabled)
                    }
                }

                if let nodes = status.nodeCount {
                    GridRow {
                        Text("Nodes")
                            .foregroundStyle(.secondary)
                        Text("\(nodes)")
                            .textSelection(.enabled)
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
                    Text("Checking...")
                        .foregroundStyle(.secondary)

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
                                .textSelection(.enabled)
                        }
                    }

                    if let path = sync.path {
                        GridRow {
                            Text("Path")
                                .foregroundStyle(.secondary)
                            Text(path)
                                .textSelection(.enabled)
                        }
                    }

                    if let message = sync.status, !message.isEmpty {
                        GridRow {
                            Text("Message")
                                .foregroundStyle(.secondary)
                                .alignmentGuide(.top) { _ in 0 }
                            Text(message)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fluxReconcilersSection(reconcilers: [FluxReconciler]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flux Reconcilers")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                // Header row
                GridRow {
                    Text("Kind")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Running")
                        .fontWeight(.medium)
                    Text("Failing")
                        .fontWeight(.medium)
                    Text("Suspended")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                ForEach(reconcilers, id: \.kind) { reconciler in
                    GridRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reconciler.kind)
                                .textSelection(.enabled)
                            Text(reconciler.apiVersion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(reconciler.stats.running)")
                            .textSelection(.enabled)
                        Text("\(reconciler.stats.failing)")
                            .foregroundStyle(reconciler.stats.failing > 0 ? .red : .primary)
                            .textSelection(.enabled)
                        Text("\(reconciler.stats.suspended)")
                            .foregroundStyle(reconciler.stats.suspended > 0 ? .orange : .primary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity)
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
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Operator")
                    .foregroundStyle(.secondary)
                Text(summary.operatorVersion)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Controllers")
                    .foregroundStyle(.secondary)
                Text("\(summary.componentsTotal)")
                    .textSelection(.enabled)
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
                Text("Online")
            }
        case .unreachable:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .frame(width: 14, height: 14)
                Text("Offline")
            }
        case .checking:
            // Show previous state if we have data, otherwise show checking
            if status.kubernetesVersion != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 14, height: 14)
                    Text("Online")
                }
            } else {
                Text("Checking...")
                    .foregroundStyle(.secondary)
            }
        case .unknown:
            Text("Unknown")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorPanel(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Connection Error")
                    .font(.headline)
            }

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
