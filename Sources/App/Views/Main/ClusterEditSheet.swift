// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

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
                    TextField("Display Name", text: $displayName)

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
            // Prefill with effectiveName so users can edit instead of typing from scratch
            displayName = cluster.effectiveName
            selectedColor = cluster.colorHex
            isFavorite = cluster.isFavorite
            isHidden = cluster.isHidden
        }
    }

    private func save() {
        let wasHidden = cluster.isHidden
        var updated = cluster
        // Save nil if empty or same as context name (use default)
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        updated.displayName = (trimmed.isEmpty || trimmed == cluster.contextName) ? nil : trimmed
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
