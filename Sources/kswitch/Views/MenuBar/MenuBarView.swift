import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var needsSetup: Bool {
        appState.error != nil
    }

    var body: some View {
        if needsSetup {
            MenuBarSetupView()
                .environment(appState)
        } else {
            normalView
        }
    }

    private var normalView: some View {
        VStack(spacing: 0) {
            if let cluster = appState.currentCluster {
                // Current cluster section (header)
                currentClusterSection(cluster: cluster)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            } else if !appState.currentContext.isEmpty {
                noClusterSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }

            Divider()
                .padding(.horizontal, 16)

            // Cluster list (scrollable)
            clusterListSection
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            // Action buttons
            actionBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundGradient)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.15), Color(white: 0.1)]
                : [Color(white: 0.98), Color(white: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Current Cluster Section

    @ViewBuilder
    private func currentClusterSection(cluster: Cluster) -> some View {
        Button {
            appState.pendingClusterNavigation = cluster
            dismiss()
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Header row: Cluster name + Status badge
                HStack {
                    Text(cluster.effectiveName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(for: cluster))
                            .frame(width: 6, height: 6)
                        Text(statusLabel(for: cluster))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
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

                // Divider
                Rectangle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.1))
                    .frame(height: 1)

                // Info rows
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kubernetesVersionText(for: cluster))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(fluxOperatorText(for: cluster))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(height: 95)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark
                        ? Color.white.opacity(0.2)
                        : Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(cluster.contextName)
    }

    private func statusLabel(for cluster: Cluster) -> String {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return "Unknown"
        }
        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                return "Degraded"
            }
            return "Healthy"
        case .unreachable:
            return "Offline"
        case .checking:
            // Show previous status if we have data
            if status.kubernetesVersion != nil {
                if let summary = status.fluxSummary, summary.totalFailing > 0 {
                    return "Degraded"
                }
                return "Healthy"
            }
            return "Checking"
        case .unknown:
            return "Unknown"
        }
    }

    private var noClusterSection: some View {
        HStack {
            Text(appState.currentContext)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
            Spacer()
        }
        .padding(12)
        .clusterCard()
    }

    // MARK: - Status Dot

    @ViewBuilder
    private func statusDot(for cluster: Cluster) -> some View {
        let color = statusColor(for: cluster)

        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .frame(width: 18, height: 18)
            )
    }

    private func statusColor(for cluster: Cluster) -> Color {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return .gray
        }
        switch status.reachability {
        case .reachable:
            if let summary = status.fluxSummary, summary.totalFailing > 0 {
                return .yellow
            }
            return .green
        case .unreachable:
            return .red
        case .checking:
            // Show previous color if we have data
            if status.kubernetesVersion != nil {
                if let summary = status.fluxSummary, summary.totalFailing > 0 {
                    return .yellow
                }
                return .green
            }
            return .gray
        case .unknown:
            return .gray
        }
    }

    @ViewBuilder
    private func statusIndicatorView(for cluster: Cluster) -> some View {
        let status = appState.clusterStatuses[cluster.contextName]

        Group {
            if status?.reachability == .checking {
                // Show spinner when checking
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                // Show status dot
                statusDot(for: cluster)
            }
        }
        .frame(width: 18, height: 18)
    }

    // MARK: - Cluster List

    private var clusterListSection: some View {
        let activeClusters = appState.visibleClusters.filter { $0.isInKubeconfig }
        let favorites = activeClusters.filter { $0.isFavorite }.sorted { $0.effectiveName < $1.effectiveName }
        let nonFavorites = activeClusters.filter { !$0.isFavorite }.sorted { $0.effectiveName < $1.effectiveName }
        let removedClusters = appState.visibleClusters.filter { !$0.isInKubeconfig }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                // Favorites first
                ForEach(favorites) { cluster in
                    clusterRow(cluster: cluster)
                }

                // Then non-favorites
                ForEach(nonFavorites) { cluster in
                    clusterRow(cluster: cluster)
                }

                // Removed clusters (grayed out)
                if !removedClusters.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    ForEach(removedClusters) { cluster in
                        clusterRow(cluster: cluster)
                            .opacity(0.5)
                            .disabled(true)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 200)
    }

    @ViewBuilder
    private func clusterRow(cluster: Cluster) -> some View {
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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            // Open main window
            actionButton(icon: "macwindow", label: "Open") {
                dismiss()
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o", modifiers: .command)

            // Refresh
            refreshButton
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isCurrentClusterRefreshing)

            Spacer()

            // Quit
            actionButton(icon: "power", label: "Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var isCurrentClusterRefreshing: Bool {
        guard let status = appState.clusterStatuses[appState.currentContext] else {
            return false
        }
        return status.reachability == .checking
    }

    private var refreshButton: some View {
        Button {
            Task {
                await appState.refreshStatus(for: appState.currentContext)
            }
        } label: {
            HStack(spacing: 4) {
                Group {
                    if isCurrentClusterRefreshing {
                        ProgressView()
                            .scaleEffect(0.45)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                }
                .frame(width: 11, height: 11)

                Text(isCurrentClusterRefreshing ? "Syncing" : "Refresh")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Functions

    private func kubernetesVersionText(for cluster: Cluster) -> String {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return "Kubernetes status unknown"
        }

        switch status.reachability {
        case .checking:
            // Show previous version if available
            if let version = status.kubernetesVersion {
                return "Kubernetes \(version)"
            }
            return "Checking Kubernetes..."
        case .reachable:
            if let version = status.kubernetesVersion {
                return "Kubernetes \(version)"
            }
            return "Kubernetes connected"
        case .unreachable:
            return "Kubernetes unreachable"
        case .unknown:
            return "Kubernetes status unknown"
        }
    }

    private func fluxOperatorText(for cluster: Cluster) -> String {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return "Flux Operator status unknown"
        }

        // If cluster is unreachable, Flux is also unreachable
        if case .unreachable = status.reachability {
            return "Flux Operator unreachable"
        }

        switch status.fluxOperator {
        case .checking:
            // Show previous info if available
            if let summary = status.fluxSummary {
                return formatFluxVersions(summary)
            }
            return "Checking Flux Operator..."
        case .installed:
            if let summary = status.fluxSummary {
                return formatFluxVersions(summary)
            }
            return "Flux Operator installed"
        case .degraded:
            if let summary = status.fluxSummary {
                return formatFluxVersions(summary)
            }
            return "Flux Operator degraded"
        case .notInstalled:
            return "Flux Operator not installed"
        case .unknown:
            return "Flux Operator status unknown"
        }
    }

    private func formatFluxVersions(_ summary: FluxReportSummary) -> String {
        let flux = summary.distributionVersion
        let op = summary.operatorVersion

        if flux != "unknown" && op != "unknown" {
            return "Flux \(flux) Operator \(op)"
        } else if op != "unknown" {
            return "Flux Operator \(op)"
        } else if flux != "unknown" {
            return "Flux \(flux)"
        }
        return "Flux Operator installed"
    }
}
