// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

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

                        KubernetesSectionView(status: status)

                        if case .reachable = status.reachability {
                            Divider()

                            FluxSectionView(status: status)
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
                    if appState.refreshingContexts.contains(cluster.contextName) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(!cluster.isInKubeconfig || appState.refreshingContexts.contains(cluster.contextName))
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

    // MARK: - Header Section

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
}
