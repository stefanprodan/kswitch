// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
#if ENABLE_SPARKLE
import Sparkle
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    #if ENABLE_SPARKLE
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    #endif
    @State private var kubeconfigPath: String = ""
    @State private var kubectlPath: String = ""
    @State private var tasksDirectory: String = ""
    @State private var pathsSaved: Bool = false
    @State private var taskSettingsSaved: Bool = false

    private var defaultKubeconfig: String {
        NSHomeDirectory() + "/.kube/config"
    }

    private var kubeconfigPaths: [String] {
        kubeconfigPath
            .split(separator: ":")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var validKubeconfigCount: Int {
        kubeconfigPaths.filter { FileManager.default.fileExists(atPath: $0) }.count
    }

    private var canSavePaths: Bool {
        !kubeconfigPaths.isEmpty &&
        validKubeconfigCount > 0 &&
        FileManager.default.fileExists(atPath: kubectlPath)
    }

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Paths") {
                VStack(alignment: .trailing, spacing: 2) {
                    TextField("kubeconfig", text: $kubeconfigPath)
                        .help("Colon-separated paths (e.g. ~/.kube/config:~/.kube/work)")
                    kubeconfigStatus
                }

                VStack(alignment: .trailing, spacing: 2) {
                    TextField("kubectl", text: $kubectlPath)
                    kubectlStatus
                }

                HStack {
                    Spacer()
                    if pathsSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Saved")
                        }
                        .foregroundStyle(.green)
                        .font(.caption)
                    }
                    Button("Save") {
                        savePaths()
                    }
                    .disabled(!canSavePaths)
                }
            }
            .onAppear {
                loadPaths()
            }

            Section("Status check") {
                Picker("Interval", selection: $state.settings.refreshIntervalSeconds) {
                    Text("Manual only").tag(0)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
                .onChange(of: state.settings.refreshIntervalSeconds) {
                    appState.saveToDisk()
                    appState.startBackgroundRefresh()
                }

                Toggle("Notify on failures", isOn: $state.settings.notificationsEnabled)
                    .onChange(of: state.settings.notificationsEnabled) {
                        appState.saveToDisk()
                    }
            }

            Section("Task Runner") {
                VStack(alignment: .trailing, spacing: 2) {
                    TextField("Tasks directory", text: $tasksDirectory)
                        .help("Directory containing *.kswitch.sh scripts (e.g. ~/.kswitch/tasks)")
                    tasksDirectoryStatus
                }

                Stepper("Timeout: \(state.settings.taskTimeoutMinutes) min",
                        value: $state.settings.taskTimeoutMinutes, in: 1...60)
                    .onChange(of: state.settings.taskTimeoutMinutes) {
                        appState.saveToDisk()
                    }

                HStack {
                    Spacer()
                    if taskSettingsSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Saved")
                        }
                        .foregroundStyle(.green)
                        .font(.caption)
                    }
                    Button("Save") {
                        saveTaskSettings()
                    }
                    .disabled(tasksDirectory.isEmpty)
                }
            }
            .onAppear {
                loadTaskSettings()
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $state.settings.launchAtLogin)
                    .onChange(of: state.settings.launchAtLogin) {
                        appState.saveToDisk()
                    }

                Toggle("Check for updates", isOn: $state.settings.autoupdate)
                    .onChange(of: state.settings.autoupdate) {
                        #if ENABLE_SPARKLE
                        sparkleUpdater?.automaticallyChecksForUpdates = state.settings.autoupdate
                        #endif
                        appState.saveToDisk()
                    }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }

    private func loadPaths() {
        let paths = appState.settings.kubeconfigPaths
        kubeconfigPath = paths.isEmpty ? defaultKubeconfig : paths.joined(separator: ":")

        // Use saved path, or fall back to detected path from startup
        kubectlPath = appState.settings.kubectlPath ?? appState.detectedKubectlPath ?? ""
    }

    private func savePaths() {
        guard canSavePaths else { return }

        appState.settings.kubeconfigPaths = kubeconfigPaths
        appState.settings.kubectlPath = kubectlPath.isEmpty ? nil : kubectlPath
        appState.saveToDisk()
        appState.startBackgroundRefresh()

        withAnimation { pathsSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { pathsSaved = false }
        }
    }

    @ViewBuilder
    private var kubeconfigStatus: some View {
        let total = kubeconfigPaths.count
        let valid = validKubeconfigCount

        if total == 0 {
            Text("⚠ No paths specified")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if valid == total {
            if total == 1 {
                Text("✓ Valid")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("✓ All \(total) paths valid (first path watched)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } else {
            Text("⚠ \(valid) of \(total) paths valid")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var kubectlStatus: some View {
        if FileManager.default.fileExists(atPath: kubectlPath) {
            Text("✓ Valid")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Text("⚠ Not found")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Task Runner Settings

    private func loadTaskSettings() {
        tasksDirectory = appState.settings.tasksDirectory ?? ""
    }

    private func saveTaskSettings() {
        appState.settings.tasksDirectory = tasksDirectory.isEmpty ? nil : tasksDirectory
        appState.saveToDisk()
        appState.setupTasksWatcher()

        withAnimation { taskSettingsSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { taskSettingsSaved = false }
        }
    }

    @ViewBuilder
    private var tasksDirectoryStatus: some View {
        if tasksDirectory.isEmpty {
            Text("Not configured")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if appState.tasks.isEmpty {
            Text("No tasks defined")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("✓ \(appState.tasks.count) task\(appState.tasks.count == 1 ? "" : "s") found")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
}
