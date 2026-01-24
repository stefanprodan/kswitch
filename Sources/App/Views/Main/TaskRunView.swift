// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct TaskRunView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let task: ScriptTask

    @State private var inputValues: [String: String] = [:]

    private var isRunning: Bool {
        appState.isTaskRunning(task)
    }

    private var lastRun: TaskRun? {
        appState.taskRun(for: task)
    }

    private var canRun: Bool {
        // Can run if not running and all required inputs are filled
        guard !isRunning else { return false }
        for input in task.inputs where input.isRequired {
            if inputValues[input.name]?.isEmpty ?? true {
                return false
            }
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding()
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.05)
                        : Color.black.opacity(0.02)
                )

            Divider()

            // Inputs section (if task has inputs)
            if !task.inputs.isEmpty {
                inputsSection
                    .padding()

                Divider()
            }

            // Terminal output
            outputSection
        }
        .navigationTitle(task.name)
        .onAppear {
            // Initialize input values from last run if available
            if let run = lastRun {
                inputValues = run.inputValues
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.scriptPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let run = lastRun {
                    HStack(spacing: 8) {
                        statusIndicator(for: run)
                        Text(lastRunText(run))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Run/Stop button
            HStack {
                if isRunning {
                    Button {
                        Task { await appState.stopTask(task) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        Task { await appState.runTask(task, inputValues: inputValues) }
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRun)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.selectFile(task.scriptPath, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(for run: TaskRun) -> some View {
        if isRunning {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else {
            Circle()
                .fill(run.timedOut ? .orange : (run.succeeded ? .green : .red))
                .frame(width: 8, height: 8)
        }
    }

    private func lastRunText(_ run: TaskRun) -> String {
        if isRunning {
            return "Running..."
        }

        var status = run.succeeded ? "Succeeded" : "Failed"
        if run.timedOut {
            status = "Timed out"
        }

        return "\(status) in \(run.formattedDuration)"
    }

    // MARK: - Inputs Section

    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inputs")
                .font(.headline)

            ForEach(task.inputs, id: \.name) { input in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(input.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        if input.isRequired {
                            Text("*")
                                .foregroundStyle(.red)
                        }
                    }

                    if !input.description.isEmpty {
                        Text(input.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    TextField(input.isRequired ? "Required" : "Optional", text: inputBinding(for: input.name))
                        .textFieldStyle(.roundedBorder)
                        .disabled(isRunning)
                }
            }
        }
    }

    private func inputBinding(for name: String) -> Binding<String> {
        Binding(
            get: { inputValues[name] ?? "" },
            set: { inputValues[name] = $0 }
        )
    }

    // MARK: - Output Section

    private var outputSection: some View {
        Group {
            if let run = lastRun, !run.output.isEmpty {
                TerminalOutputView(output: run.output)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isRunning {
                VStack {
                    ProgressView("Running...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No output yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Run the task to see output here")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
