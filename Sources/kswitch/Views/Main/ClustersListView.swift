import SwiftUI

struct ClustersListView: View {
    @Environment(AppState.self) private var appState
    var searchText: String = ""
    var showFavoritesOnly: Bool = false
    var showHiddenOnly: Bool = false

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
            if appState.isRefreshing {
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
                    NavigationLink(destination: ClusterDetailView(cluster: cluster)) {
                        ClusterRow(cluster: cluster)
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
    }

    private var navigationTitle: String {
        if showHiddenOnly { return "Hidden Clusters" }
        if showFavoritesOnly { return "Favorites" }
        return "All Clusters"
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
        HStack {
            Circle()
                .fill(cluster.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(cluster.effectiveName)
                        .fontWeight(cluster.contextName == appState.currentContext ? .semibold : .regular)
                        .foregroundStyle(cluster.isInKubeconfig ? .primary : .secondary)

                    if cluster.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }

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

                if let status = status {
                    HStack(spacing: 8) {
                        if let version = status.kubernetesVersion {
                            Text(version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let nodes = status.nodeCount {
                            Text("\(nodes) nodes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Status indicator
            if let status = status {
                StatusIndicator(status: status.statusColor)
            }
        }
        .padding(.vertical, 4)
        .opacity(cluster.isInKubeconfig ? 1 : 0.5)
    }
}
