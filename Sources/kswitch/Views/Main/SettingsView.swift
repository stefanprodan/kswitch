import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var kubeconfigPath: String = ""
    @State private var kubectlPath: String = ""

    private var defaultKubeconfig: String {
        NSHomeDirectory() + "/.kube/config"
    }

    private var canSavePaths: Bool {
        FileManager.default.fileExists(atPath: kubeconfigPath) &&
        FileManager.default.fileExists(atPath: kubectlPath)
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

                HStack {
                    Spacer()
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

            Section("Startup") {
                Toggle("Launch at Login", isOn: $state.settings.launchAtLogin)
                    .onChange(of: state.settings.launchAtLogin) {
                        appState.saveToDisk()
                    }

                Toggle("Check for updates", isOn: $state.settings.checkForUpdatesAutomatically)
                    .onChange(of: state.settings.checkForUpdatesAutomatically) {
                        appState.saveToDisk()
                    }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }

    private func loadPaths() {
        kubeconfigPath = appState.settings.kubeconfigPaths.first ?? defaultKubeconfig

        Task {
            if let detected = try? await ShellEnvironment.shared.findExecutable(named: "kubectl") {
                await MainActor.run {
                    kubectlPath = appState.settings.kubectlPath ?? detected
                }
            }
        }
    }

    private func savePaths() {
        guard canSavePaths else { return }

        appState.settings.kubeconfigPaths = kubeconfigPath.isEmpty ? [] : [kubeconfigPath]
        appState.settings.kubectlPath = kubectlPath.isEmpty ? nil : kubectlPath
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
