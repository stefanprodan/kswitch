import SwiftUI
import Domain
import Infrastructure

struct ClustersListView: View {
    @Environment(AppState.self) private var appState
    @Binding var searchText: String
    @Binding var navigationPath: NavigationPath
    @State private var clusterToEdit: Cluster?

    private var sortedClusters: [Cluster] {
        let favorites = appState.clusters
            .filter { $0.isFavorite && !$0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        let nonFavorites = appState.clusters
            .filter { !$0.isFavorite && !$0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        let hidden = appState.clusters
            .filter { $0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        return favorites + nonFavorites + hidden
    }

    private var filteredClusters: [Cluster] {
        if searchText.isEmpty {
            return sortedClusters
        }

        return sortedClusters.filter {
            $0.effectiveName.localizedCaseInsensitiveContains(searchText) ||
            $0.contextName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if appState.isRefreshing && filteredClusters.isEmpty {
                ProgressView("Loading clusters...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredClusters.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptyIcon)
                } description: {
                    Text(emptyDescription)
                }
            } else {
                List(filteredClusters) { cluster in
                    NavigationLink(value: cluster) {
                        ClusterRow(cluster: cluster)
                    }
                    .listRowBackground(
                        cluster.contextName == appState.currentContext
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                    .contextMenu {
                        contextMenuItems(for: cluster)
                    }
                }
                .scrollContentBackground(.hidden)
                .sheet(item: $clusterToEdit) { cluster in
                    ClusterEditSheet(cluster: cluster)
                        .environment(appState)
                }
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "No Results" }
        return "No Clusters"
    }

    private var emptyIcon: String {
        return "square.stack.3d.up"
    }

    private var emptyDescription: String {
        if !searchText.isEmpty { return "Try a different search term." }
        return "No Kubernetes contexts found in your kubeconfig."
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for cluster: Cluster) -> some View {
        Button {
            Task { await appState.switchContext(to: cluster.contextName) }
        } label: {
            Label("Set as Current", systemImage: "checkmark.circle")
        }
        .disabled(cluster.contextName == appState.currentContext || !cluster.isInKubeconfig)

        Divider()

        Button {
            clusterToEdit = cluster
        } label: {
            Label("Edit...", systemImage: "pencil")
        }

        Divider()

        Button {
            var updated = cluster
            updated.isFavorite.toggle()
            appState.updateCluster(updated)
        } label: {
            Label(cluster.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: cluster.isFavorite ? "star.slash" : "star")
        }

        Button {
            var updated = cluster
            updated.isHidden.toggle()
            appState.updateCluster(updated)
            if !updated.isHidden {
                Task { await appState.refreshStatus(for: cluster.contextName) }
            }
        } label: {
            Label(cluster.isHidden ? "Unhide" : "Hide",
                  systemImage: cluster.isHidden ? "eye" : "eye.slash")
        }
    }
}

struct ClusterRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let cluster: Cluster

    private var status: ClusterStatus? {
        appState.clusterStatuses[cluster.contextName]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: star + name + status badge
            HStack {
                Text(cluster.isFavorite ? "★" : "☆")
                    .font(.system(size: 14))
                    .foregroundStyle(cluster.isFavorite ? .yellow : .secondary)

                Text(cluster.effectiveName)
                    .font(.system(size: 13, weight: cluster.contextName == appState.currentContext ? .semibold : .regular))
                    .foregroundStyle(cluster.isHidden ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                statusBadge
            }

            // Version info
            VStack(alignment: .leading, spacing: 2) {
                Text(kubernetesText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(fluxText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 20)
        }
        .padding(.vertical, 4)
        .opacity(cluster.isInKubeconfig ? 1 : 0.5)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.1)
                    : Color.black.opacity(0.05))
        )
    }

    private var statusLabel: String {
        if cluster.isHidden {
            return "Hidden"
        }

        guard let status = status else {
            return "Unknown"
        }

        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                return "Degraded"
            }
            return "Healthy"
        case .unreachable:
            return "Offline"
        case .checking:
            if status.kubernetesVersion != nil {
                if let summary = status.fluxSummary, summary.totalFailing > 0 {
                    return "Degraded"
                }
                return "Healthy"
            }
            return "Checking"
        case .unknown:
            return "Unknown"
        }
    }

    private var statusColor: Color {
        if cluster.isHidden {
            return .gray
        }

        guard let status = status else {
            return .gray
        }

        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                return .yellow
            }
            return .green
        case .unreachable:
            return .red
        case .checking:
            if status.kubernetesVersion != nil {
                if let summary = status.fluxSummary, summary.totalFailing > 0 {
                    return .yellow
                }
                return .green
            }
            return .gray
        case .unknown:
            return .gray
        }
    }

    // MARK: - Version Text

    private var kubernetesText: String {
        if cluster.isHidden {
            return "Status check paused"
        }

        guard let status = status else {
            return "Kubernetes status unknown"
        }

        switch status.reachability {
        case .checking:
            if let version = status.kubernetesVersion {
                return formatKubernetesLine(version: version, nodes: status.nodeCount)
            }
            return "Checking Kubernetes..."
        case .reachable:
            if let version = status.kubernetesVersion {
                return formatKubernetesLine(version: version, nodes: status.nodeCount)
            }
            return "Kubernetes connected"
        case .unreachable:
            return "Kubernetes unreachable"
        case .unknown:
            return "Kubernetes status unknown"
        }
    }

    private func formatKubernetesLine(version: String, nodes: Int?) -> String {
        if let nodes = nodes {
            return "Kubernetes \(version) · \(nodes) \(nodes == 1 ? "node" : "nodes")"
        }
        return "Kubernetes \(version)"
    }

    private var fluxText: String {
        if cluster.isHidden {
            return ""
        }

        guard let status = status else {
            return "Flux status unknown"
        }

        if case .unreachable = status.reachability {
            return "Flux unreachable"
        }

        switch status.fluxOperator {
        case .checking:
            if let summary = status.fluxSummary {
                return formatFluxLine(summary)
            }
            return "Checking Flux..."
        case .installed, .degraded:
            if let summary = status.fluxSummary {
                return formatFluxLine(summary)
            }
            return "Flux installed"
        case .notInstalled:
            return "Flux not installed"
        case .unknown:
            return "Flux status unknown"
        }
    }

    private func formatFluxLine(_ summary: FluxReportSummary) -> String {
        let flux = summary.distributionVersion
        let op = summary.operatorVersion

        if flux != "unknown" && op != "unknown" {
            return "Flux \(flux) · Operator \(op)"
        } else if op != "unknown" {
            return "Flux Operator \(op)"
        } else if flux != "unknown" {
            return "Flux \(flux)"
        }
        return "Flux installed"
    }
}
