// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct TasksListView: View {
    @Environment(AppState.self) private var appState
    @Binding var searchText: String
    @Binding var navigationPath: NavigationPath

    private var filteredTasks: [ScriptTask] {
        if searchText.isEmpty {
            return appState.tasks
        }
        return appState.tasks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if appState.settings.effectiveTasksDirectory == nil {
                noDirectoryView
            } else if appState.tasks.isEmpty {
                emptyStateView
            } else if filteredTasks.isEmpty {
                noResultsView
            } else {
                List(filteredTasks) { task in
                    NavigationLink(value: task) {
                        TaskRowView(task: task)
                    }
                    .contextMenu {
                        contextMenuItems(for: task)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search term.")
        }
    }

    private var noDirectoryView: some View {
        ContentUnavailableView {
            Label("No Tasks Directory", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Configure a tasks directory in Settings to discover task scripts.")
        } actions: {
            Button("Open Settings") {
                appState.pendingSettingsNavigation = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tasks Found", systemImage: "terminal")
        } description: {
            Text("No executable *.kswitch.sh scripts found in the tasks directory.")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for task: ScriptTask) -> some View {
        let isRunning = appState.isTaskRunning(task)

        if isRunning {
            Button {
                Task { await appState.stopTask(task) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        } else {
            Button {
                Task { await appState.runTask(task) }
            } label: {
                Label("Run", systemImage: "play.fill")
            }
        }

        Divider()

        Button {
            NSWorkspace.shared.selectFile(task.scriptPath, inFileViewerRootedAtPath: "")
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
    }
}
