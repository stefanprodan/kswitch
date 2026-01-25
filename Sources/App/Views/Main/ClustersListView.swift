// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct ClustersListView: View {
    @Environment(AppState.self) private var appState
    @Binding var searchText: String
    @Binding var navigationPath: NavigationPath
    @State private var clusterToEdit: Cluster?

    private var sortedClusters: [Cluster] {
        appState.clusters.sortedByFavorites()
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
                        ClusterRowView(cluster: cluster)
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
