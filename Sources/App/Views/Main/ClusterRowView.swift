// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct ClusterRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let cluster: Cluster

    private var status: ClusterStatus? {
        appState.clusterStatuses[cluster.contextName]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: star + name + status badge
            HStack {
                Text(cluster.isFavorite ? "★" : "☆")
                    .font(.system(size: 14))
                    .foregroundStyle(cluster.isFavorite ? .yellow : .secondary)

                Text(cluster.effectiveName)
                    .font(.system(size: 13, weight: cluster.contextName == appState.currentContext ? .semibold : .regular))
                    .foregroundStyle(cluster.isHidden ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                statusBadge
            }

            // Version info
            VStack(alignment: .leading, spacing: 2) {
                Text(kubernetesText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(fluxText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 20)
        }
        .padding(.vertical, 4)
        .opacity(cluster.isInKubeconfig ? 1 : 0.5)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.1)
                    : Color.black.opacity(0.05))
        )
    }

    private var statusLabel: String {
        if cluster.isHidden {
            return "Hidden"
        }
        return status?.statusLabel ?? "Unknown"
    }

    private var statusColor: Color {
        if cluster.isHidden {
            return .gray
        }
        return status?.statusColor.toSwiftUIColor ?? .gray
    }

    // MARK: - Info Text

    private var kubernetesText: String {
        if cluster.isHidden {
            return "Status check paused"
        }
        return status?.kubernetesInfo ?? "Kubernetes status unknown"
    }

    private var fluxText: String {
        if cluster.isHidden {
            return ""
        }
        return status?.fluxInfo ?? "Flux Operator status unknown"
    }
}
