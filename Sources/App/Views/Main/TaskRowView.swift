// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct TaskRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let task: ScriptTask

    private var isRunning: Bool {
        appState.isTaskRunning(task)
    }

    private var lastRun: TaskRun? {
        appState.taskRun(for: task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: name + status badge
            HStack {
                Text(task.name)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                statusBadge
            }

            // Script path and last run info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.scriptPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let run = lastRun {
                    Text(lastRunText(run))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
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
        if isRunning {
            return "Running"
        }
        guard let run = lastRun else {
            return "Never run"
        }
        if run.timedOut {
            return "Timed out"
        }
        return run.succeeded ? "Success" : "Failed"
    }

    private var statusColor: Color {
        if isRunning {
            return .blue
        }
        guard let run = lastRun else {
            return .gray
        }
        if run.timedOut {
            return .orange
        }
        return run.succeeded ? .green : .red
    }

    private func lastRunText(_ run: TaskRun) -> String {
        let status = run.timedOut ? "Timed out" : (run.succeeded ? "Succeeded" : "Failed")
        return "\(status) in \(run.formattedDuration)"
    }
}
