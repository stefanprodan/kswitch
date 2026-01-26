// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct TaskRunView: View {
    @Environment(AppState.self) private var appState
    let task: ScriptTask

    @State private var inputValues: [String: String] = [:]
    @State private var showingInspector: Bool = false
    @State private var scriptContent: String?
    @State private var highlightedScript: AttributedString?

    /// Returns the current version of this task from AppState, or falls back to the passed-in task.
    private var currentTask: ScriptTask {
        appState.tasks.first { $0.id == task.id } ?? task
    }

    /// True if the task script has been deleted from disk.
    private var isDeleted: Bool {
        !appState.tasks.contains { $0.id == task.id }
    }

    private var isRunning: Bool {
        appState.isTaskRunning(currentTask)
    }

    private var lastRun: TaskRun? {
        appState.taskRun(for: currentTask)
    }

    private var canRun: Bool {
        // Can't run if deleted or already running
        guard !isDeleted, !isRunning else { return false }
        for input in currentTask.inputs where input.isRequired {
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

            Divider()

            // Inputs (if any)
            if !currentTask.inputs.isEmpty {
                inputsSection
                    .padding()

                Divider()
            }

            // Run button
            runSection
                .padding()

            Divider()

            // Terminal output
            outputSection
        }
        .navigationTitle("Task")
        .toolbar {
            ToolbarItem(id: "task-reveal", placement: .automatic) {
                Button {
                    NSWorkspace.shared.selectFile(currentTask.scriptPath, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .onAppear {
            // Initialize input values from last run if available
            if let run = lastRun {
                inputValues = run.inputValues
            }
        }
        .onChange(of: task.id) {
            // Reset input values when switching to a different task
            inputValues = [:]
            scriptContent = nil
            highlightedScript = nil
            // Restore from last run if available
            if let run = appState.taskRun(for: currentTask) {
                inputValues = run.inputValues
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 32))
                .foregroundStyle(isDeleted ? .red : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(currentTask.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if isDeleted {
                        Text("Deleted")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                    }
                }

                Text(currentTask.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()
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
            ForEach(currentTask.inputs, id: \.name) { input in
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text(input.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        if input.isRequired {
                            Text("*")
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(minWidth: 120, alignment: .leading)

                    TextField(input.description.isEmpty ? (input.isRequired ? "Required" : "Optional") : input.description, text: inputBinding(for: input.name))
                        .textFieldStyle(.roundedBorder)
                        .disabled(isRunning)
                }
            }
        }
    }

    // MARK: - Run Section

    private var runSection: some View {
        HStack {
            if isRunning {
                Button {
                    Task { await appState.stopTask(currentTask) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    showingInspector = false
                    Task { await appState.runTask(currentTask, inputValues: inputValues) }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRun)
            }

            Picker("Mode", selection: $showingInspector) {
                Label("Output", systemImage: "text.alignleft").tag(false)
                Label("Script", systemImage: "doc.text").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            if let run = lastRun {
                HStack(spacing: 8) {
                    statusIndicator(for: run)
                    Text(lastRunText(run))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
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
            if showingInspector {
                scriptInspectorView
            } else if let run = lastRun, !run.output.isEmpty {
                TaskTerminalView(output: run.output, isStreaming: isRunning)
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

    // MARK: - Script Inspector

    private var scriptInspectorView: some View {
        ScrollView {
            if let highlighted = highlightedScript {
                Text(highlighted)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                ProgressView("Loading script...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: currentTask.scriptPath) {
            loadScriptContent()
        }
    }

    private func loadScriptContent() {
        do {
            let content = try String(contentsOfFile: currentTask.scriptPath, encoding: .utf8)
            scriptContent = content
            highlightedScript = ShellSyntaxHighlighter.highlight(content)
        } catch {
            let errorMessage = "# Error loading script: \(error.localizedDescription)"
            scriptContent = errorMessage
            highlightedScript = ShellSyntaxHighlighter.highlight(errorMessage)
        }
    }
}
