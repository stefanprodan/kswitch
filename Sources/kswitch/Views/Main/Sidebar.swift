import SwiftUI

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    var searchText: String

    var body: some View {
        List {
            NavigationLink(destination: ClustersListView(
                searchText: searchText,
                showFavoritesOnly: true
            )) {
                Label("Favorites", systemImage: "star.fill")
                    .badge(appState.favoriteClusters.count)
            }

            NavigationLink(destination: ClustersListView(
                searchText: searchText,
                showFavoritesOnly: false
            )) {
                Label("All Clusters", systemImage: "square.stack.3d.up")
                    .badge(appState.visibleClusters.count)
            }

            NavigationLink(destination: ClustersListView(
                searchText: searchText,
                showHiddenOnly: true
            )) {
                Label("Hidden", systemImage: "eye.slash")
                    .badge(appState.hiddenClusters.count)
            }

            Divider()

            NavigationLink(destination: SettingsView()) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
