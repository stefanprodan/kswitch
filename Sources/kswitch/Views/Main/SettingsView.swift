import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var kubeconfigPath: String = ""
    @State private var kubectlPath: String = ""
    @State private var detectedKubectl: String = ""

    private var defaultKubeconfig: String {
        NSHomeDirectory() + "/.kube/config"
    }

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Paths") {
                VStack(alignment: .trailing, spacing: 2) {
                    TextField("kubeconfig", text: $kubeconfigPath)
                    pathStatus(exists: FileManager.default.fileExists(atPath: kubeconfigPath))
                }

                VStack(alignment: .trailing, spacing: 2) {
                    TextField("kubectl", text: $kubectlPath)
                    pathStatus(exists: FileManager.default.fileExists(atPath: kubectlPath))
                }
            }
            .onAppear {
                loadPaths()
            }

            Section("Refresh") {
                Picker("Refresh Interval", selection: $state.settings.refreshIntervalSeconds) {
                    Text("Manual only").tag(0)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $state.settings.notificationsEnabled)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $state.settings.launchAtLogin)
                Toggle("Check for Updates Automatically", isOn: $state.settings.checkForUpdatesAutomatically)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save Settings") {
                        saveSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func loadPaths() {
        // Pre-fill with effective values (user-set OR defaults)
        kubeconfigPath = appState.settings.kubeconfigPaths.first ?? defaultKubeconfig

        // Detect kubectl and pre-fill
        Task {
            if let detected = try? await ShellEnvironment.shared.findExecutable(named: "kubectl") {
                await MainActor.run {
                    detectedKubectl = detected
                    kubectlPath = appState.settings.kubectlPath ?? detected
                }
            }
        }
    }

    private func saveSettings() {
        // Validate paths exist
        guard FileManager.default.fileExists(atPath: kubeconfigPath),
              FileManager.default.fileExists(atPath: kubectlPath) else {
            return
        }

        // Only persist if different from defaults
        appState.settings.kubeconfigPaths = kubeconfigPath == defaultKubeconfig ? [] : [kubeconfigPath]
        appState.settings.kubectlPath = kubectlPath == detectedKubectl ? nil : kubectlPath
        appState.saveToDisk()
        appState.startBackgroundRefresh()
    }

    @ViewBuilder
    private func pathStatus(exists: Bool) -> some View {
        if exists {
            Text("✓ Valid")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Text("⚠ Not found")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
