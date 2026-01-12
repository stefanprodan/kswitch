import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable {
    case favorites
    case allClusters
    case hidden
    case settings

    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .allClusters: return "All Clusters"
        case .hidden: return "Hidden"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .allClusters: return "square.stack.3d.up"
        case .hidden: return "eye.slash"
        case .settings: return "gearshape"
        }
    }
}

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label("All Clusters", systemImage: "square.stack.3d.up")
                .badge(appState.visibleClusters.count)
                .tag(SidebarItem.allClusters)

            Label("Favorites", systemImage: "star.fill")
                .badge(appState.favoriteClusters.count)
                .tag(SidebarItem.favorites)

            Label("Hidden", systemImage: "eye.slash")
                .badge(appState.hiddenClusters.count)
                .tag(SidebarItem.hidden)

            Divider()

            Label("Settings", systemImage: "gearshape")
                .tag(SidebarItem.settings)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
