import SwiftUI

struct MenuBarIcon: View {
    let appState: AppState

    var body: some View {
        if let _ = NSImage(named: "MenuBarIcon") {
            Image("MenuBarIcon")
                .renderingMode(.template)
        } else {
            // Fallback to SF Symbol
            Image(systemName: "helm")
                .symbolRenderingMode(.hierarchical)
        }
    }
}
