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
        .safeAreaInset(edge: .top) {
            // Error banner
            if let error = appState.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        appState.error = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.red.opacity(0.1))
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
    }

    @ViewBuilder
    private var detailView: some View {
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
