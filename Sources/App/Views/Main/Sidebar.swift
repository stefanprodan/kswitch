// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

enum SidebarItem: String, Hashable, CaseIterable {
    case clusters
    case settings
    case about

    var title: String {
        switch self {
        case .clusters: return "Clusters"
        case .settings: return "Settings"
        case .about: return "About"
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

            Label("About", systemImage: "info.circle")
                .tag(SidebarItem.about)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
