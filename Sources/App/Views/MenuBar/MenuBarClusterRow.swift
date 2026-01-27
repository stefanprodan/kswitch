// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MenuBarClusterRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let cluster: Cluster

    var body: some View {
        Button {
            Task { await appState.switchContext(to: cluster.contextName) }
        } label: {
            HStack(spacing: 8) {
                // Star indicator
                Text(cluster.isFavorite ? "★" : "☆")
                    .font(.system(size: 12))
                    .foregroundStyle(cluster.isFavorite ? .yellow : .secondary)

                // Cluster name with ellipsis for long names
                Text(cluster.effectiveName)
                    .font(.system(size: 13))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Checkmark for current context
                if cluster.contextName == appState.currentContext {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cluster.contextName == appState.currentContext
                        ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(cluster.contextName)
    }
}

// MARK: - Cluster Search Field

struct MenuBarClusterSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Search clusters...", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
            .focused($isFocused)
            .onAppear { isFocused = true }
    }
}
