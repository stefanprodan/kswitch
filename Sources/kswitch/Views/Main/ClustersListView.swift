import SwiftUI

struct ClustersListView: View {
    @Environment(AppState.self) private var appState
    @Binding var searchText: String
    var showFavoritesOnly: Bool = false
    var showHiddenOnly: Bool = false
    @Binding var navigationPath: NavigationPath

    init(searchText: Binding<String>, showFavoritesOnly: Bool = false, showHiddenOnly: Bool = false, navigationPath: Binding<NavigationPath>) {
        self._searchText = searchText
        self.showFavoritesOnly = showFavoritesOnly
        self.showHiddenOnly = showHiddenOnly
        self._navigationPath = navigationPath
    }

    private var filteredClusters: [Cluster] {
        var clusters: [Cluster]

        if showHiddenOnly {
            clusters = appState.hiddenClusters
        } else if showFavoritesOnly {
            clusters = appState.favoriteClusters
        } else {
            clusters = appState.visibleClusters
        }

        if searchText.isEmpty {
            return clusters
        }

        return clusters.filter {
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
                }
            }
        }
    }

    private var emptyTitle: String {
        if showHiddenOnly { return "No Hidden Clusters" }
        if showFavoritesOnly { return "No Favorites" }
        if !searchText.isEmpty { return "No Results" }
        return "No Clusters"
    }

    private var emptyIcon: String {
        if showHiddenOnly { return "eye.slash" }
        if showFavoritesOnly { return "star" }
        return "square.stack.3d.up"
    }

    private var emptyDescription: String {
        if showHiddenOnly { return "Hidden clusters will appear here." }
        if showFavoritesOnly { return "Mark clusters as favorites to see them here." }
        if !searchText.isEmpty { return "Try a different search term." }
        return "No Kubernetes contexts found in your kubeconfig."
    }
}

struct ClusterRow: View {
    @Environment(AppState.self) private var appState
    let cluster: Cluster

    private var status: ClusterStatus? {
        appState.clusterStatuses[cluster.contextName]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First line: dot + name + star + [current badge]
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(cluster.effectiveName)
                    .fontWeight(cluster.contextName == appState.currentContext ? .semibold : .regular)
                    .foregroundStyle(cluster.isInKubeconfig ? .primary : .secondary)

                Image(systemName: cluster.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(cluster.isFavorite ? .yellow : .secondary)
                    .font(.system(size: 12))

                Spacer()

                if cluster.contextName == appState.currentContext {
                    Text("Current")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            // Second line: status text (indented to align with name)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
        }
        .padding(.vertical, 4)
        .opacity(cluster.isInKubeconfig ? 1 : 0.5)
    }

    private var statusColor: Color {
        guard let status = status else { return .gray }
        switch status.statusColor {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        case .gray: return .gray
        }
    }

    private var statusText: String {
        guard let status = status else { return "—" }

        // Build version/nodes string if available
        var parts: [String] = []
        if let version = status.kubernetesVersion {
            parts.append(version)
        }
        if let nodes = status.nodeCount {
            parts.append("\(nodes) \(nodes == 1 ? "node" : "nodes")")
        }
        let previousInfo = parts.isEmpty ? nil : parts.joined(separator: " · ")

        switch status.reachability {
        case .unknown:
            return "—"
        case .checking:
            // Show previous info if available, otherwise show Checking...
            return previousInfo ?? "Checking..."
        case .unreachable:
            return "Unreachable"
        case .reachable:
            return previousInfo ?? "Connected"
        }
    }

}
