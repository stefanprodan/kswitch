import SwiftUI

struct ClusterEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let cluster: Cluster

    @State private var displayName: String = ""
    @State private var selectedColor: String = ""
    @State private var isFavorite: Bool = false
    @State private var isHidden: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Cluster")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()

            Divider()

            Form {
                Section("Display") {
                    TextField("Display Name", text: $displayName, prompt: Text(cluster.contextName))

                    ColorPickerGrid(selectedColor: $selectedColor)
                }

                Section("Organization") {
                    Toggle("Favorite", isOn: $isFavorite)

                    Toggle("Hidden from Menu Bar", isOn: $isHidden)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 350)
        .onAppear {
            displayName = cluster.displayName ?? ""
            selectedColor = cluster.colorHex
            isFavorite = cluster.isFavorite
            isHidden = cluster.isHidden
        }
    }

    private func save() {
        let wasHidden = cluster.isHidden
        var updated = cluster
        updated.displayName = displayName.isEmpty ? nil : displayName
        updated.colorHex = selectedColor
        updated.isFavorite = isFavorite
        updated.isHidden = isHidden
        appState.updateCluster(updated)

        // Refresh status if cluster was unhidden
        if wasHidden && !isHidden {
            Task {
                await appState.refreshStatus(for: cluster.contextName)
            }
        }
    }
}

struct ColorPickerGrid: View {
    @Binding var selectedColor: String

    private let colors = Cluster.defaultColors

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 8), spacing: 8) {
            ForEach(colors, id: \.self) { colorHex in
                Button {
                    selectedColor = colorHex
                } label: {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if selectedColor == colorHex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
