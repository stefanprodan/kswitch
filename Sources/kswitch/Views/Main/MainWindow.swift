import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var selectedItem: SidebarItem? = .allClusters
    @State private var navigationPath = NavigationPath()
    @State private var isSearching: Bool = false

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedItem)
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailView
                    .navigationDestination(for: Cluster.self) { cluster in
                        ClusterDetailView(cluster: cluster)
                    }
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(navigationPath.isEmpty)
                }

                ToolbarItem {
                    Button(action: { /* forward not supported by NavigationPath */ }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(true)
                }

                ToolbarItem {
                    Text(currentTitle)
                        .font(.headline)
                }

                ToolbarItem(id: "flexible-space") {
                    Spacer()
                }

                ToolbarItem {
                    if selectedItem != .settings && isSearching {
                        TextField("Search clusters", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .onExitCommand {
                                isSearching = false
                                searchText = ""
                            }
                    }
                }

                ToolbarItem {
                    if selectedItem != .settings {
                        Button(action: {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = ""
                            }
                        }) {
                            Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .task {
            await appState.refreshAllStatuses()
        }
        .onChange(of: selectedItem) {
            // Clear search when switching sections
            isSearching = false
            searchText = ""
        }
        .task(id: appState.pendingClusterNavigation?.id) {
            if let cluster = appState.pendingClusterNavigation {
                appState.pendingClusterNavigation = nil
                selectedItem = .allClusters
                navigationPath = NavigationPath()
                navigationPath.append(cluster)
            }
        }
        .onChange(of: appState.pendingSettingsNavigation) {
            if appState.pendingSettingsNavigation {
                appState.pendingSettingsNavigation = false
                selectedItem = .settings
                navigationPath = NavigationPath()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if selectedItem == .settings {
            SettingsView()
        } else if let error = appState.error {
            errorStateView(message: error)
        } else if appState.clusters.isEmpty {
            emptyStateView
        } else {
            switch selectedItem {
            case .favorites:
                ClustersListView(
                    searchText: $searchText,
                    showFavoritesOnly: true,
                    navigationPath: $navigationPath
                )
            case .allClusters, .none:
                ClustersListView(
                    searchText: $searchText,
                    showFavoritesOnly: false,
                    navigationPath: $navigationPath
                )
            case .hidden:
                ClustersListView(
                    searchText: $searchText,
                    showHiddenOnly: true,
                    navigationPath: $navigationPath
                )
            case .settings:
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Configuration Error")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 12) {
                Button("Dismiss") {
                    appState.error = nil
                }
                .buttonStyle(.bordered)

                Button("Open Settings") {
                    selectedItem = .settings
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Clusters Found")
                .font(.title2.weight(.semibold))

            Text("No Kubernetes contexts found in your kubeconfig file. Check your settings to configure the correct path.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Open Settings") {
                selectedItem = .settings
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentTitle: String {
        if !navigationPath.isEmpty {
            return "Cluster Details"
        }
        return selectedItem?.title ?? "All Clusters"
    }

    private func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}
