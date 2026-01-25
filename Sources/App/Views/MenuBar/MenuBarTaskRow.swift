// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MenuBarTaskRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    let task: ScriptTask

    private var isRunning: Bool {
        appState.isTaskRunning(task)
    }

    private var lastRun: TaskRun? {
        appState.taskRun(for: task)
    }

    var body: some View {
        HStack(spacing: 8) {
            runButton

            // Clickable area for name + spacer + status
            Button {
                appState.pendingTaskNavigation = task
                dismiss()
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Text(task.name)
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    statusIcon
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Run Button

    private var runButton: some View {
        Button {
            if isRunning {
                Task { await appState.stopTask(task) }
            } else if task.hasRequiredInputs {
                // Open TaskRunView for tasks with required inputs
                appState.pendingTaskNavigation = task
                dismiss()
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } else {
                Task { await appState.runTask(task) }
            }
        } label: {
            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        if isRunning {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)
        } else if let run = lastRun {
            if run.succeeded {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
            }
        } else {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Task Search Field

struct MenuBarTaskSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Search tasks...", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
    }
}
