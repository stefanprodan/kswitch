// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    #if ENABLE_SPARKLE
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    #endif

    @State private var isTaskSearching: Bool = false
    @State private var taskSearchText: String = ""

    private var needsSetup: Bool {
        appState.error != nil
    }

    private var filteredTasks: [ScriptTask] {
        if taskSearchText.isEmpty {
            return appState.tasks
        }
        return appState.tasks.filter {
            $0.name.localizedCaseInsensitiveContains(taskSearchText)
        }
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
            } else {
                noContextSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }

            Divider()
                .padding(.horizontal, 16)

            // Cluster list (scrollable)
            clusterListSection
                .padding(.vertical, 12)

            // Tasks section (hidden if no tasks)
            if !appState.tasks.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                tasksSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            #if ENABLE_SPARKLE
            if sparkleUpdater?.isUpdateAvailable == true {
                Divider()
                    .padding(.horizontal, 16)

                updateSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            #endif

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
                            .fill(statusColorFor(cluster))
                            .frame(width: 6, height: 6)
                        Text(statusLabelFor(cluster))
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
                        Text(kubernetesInfoFor(cluster))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(fluxInfoFor(cluster))
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
    }

    private func statusLabelFor(_ cluster: Cluster) -> String {
        appState.clusterStatuses[cluster.contextName]?.statusLabel ?? "Unknown"
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

    private var noContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("No context selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Spacer()
            }

            Text("Select a cluster from the list below")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark
                    ? Color.white.opacity(0.1)
                    : Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Status Helpers

    private func statusColorFor(_ cluster: Cluster) -> Color {
        guard let status = appState.clusterStatuses[cluster.contextName] else {
            return .gray
        }
        return status.statusColor.toSwiftUIColor
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
                    MenuBarClusterRow(cluster: cluster)
                }

                // Then non-favorites
                ForEach(nonFavorites) { cluster in
                    MenuBarClusterRow(cluster: cluster)
                }

                // Removed clusters (grayed out)
                if !removedClusters.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    ForEach(removedClusters) { cluster in
                        MenuBarClusterRow(cluster: cluster)
                            .opacity(0.5)
                            .disabled(true)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 165)
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isTaskSearching {
                    MenuBarTaskSearchField(text: $taskSearchText)
                } else {
                    Text(appState.tasks.count > 3 ? "Tasks (\(appState.tasks.count))" : "Tasks")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isTaskSearching.toggle()
                    if !isTaskSearching {
                        taskSearchText = ""
                    }
                } label: {
                    Image(systemName: isTaskSearching ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 16)
            .padding(.horizontal, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(filteredTasks) { task in
                        MenuBarTaskRow(task: task)
                    }
                }
            }
            .frame(height: isTaskSearching ? 100 : nil, alignment: .top)
            .frame(maxHeight: 100)
        }
    }

    // MARK: - Update Section

    #if ENABLE_SPARKLE
    private var updateSection: some View {
        Button {
            sparkleUpdater?.checkForUpdates()
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                if let version = sparkleUpdater?.availableVersion {
                    Text("Update available – v\(version)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    Text("Update available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            // Open main window
            actionButton(icon: "folder", label: "Open") {
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
        appState.refreshingContexts.contains(appState.currentContext)
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

    // MARK: - Info Helpers

    private func kubernetesInfoFor(_ cluster: Cluster) -> String {
        appState.clusterStatuses[cluster.contextName]?.kubernetesInfo ?? "Kubernetes status unknown"
    }

    private func fluxInfoFor(_ cluster: Cluster) -> String {
        appState.clusterStatuses[cluster.contextName]?.fluxInfo ?? "Flux Operator status unknown"
    }
}
