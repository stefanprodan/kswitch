import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable {
    case clusters
    case settings

    var title: String {
        switch self {
        case .clusters: return "Clusters"
        case .settings: return "Settings"
        }
    }
}

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label("Clusters", systemImage: "square.stack.3d.up")
                .badge(appState.clusters.count)
                .tag(SidebarItem.clusters)

            Divider()

            Label("Settings", systemImage: "gearshape")
                .tag(SidebarItem.settings)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
