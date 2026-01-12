import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
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

            NavigationSplitView {
                Sidebar(searchText: searchText)
            } detail: {
                ClustersListView(searchText: searchText, showFavoritesOnly: false)
            }
            .searchable(text: $searchText, prompt: "Search clusters")
        }
        .task {
            await appState.refreshAllStatuses()
        }
    }
}
