import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Paths") {
                LabeledContent("kubectl") {
                    TextField("Auto-detect", text: Binding(
                        get: { state.settings.kubectlPath ?? "" },
                        set: { state.settings.kubectlPath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
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
                Button("Save Settings") {
                    appState.saveToDisk()
                    appState.startBackgroundRefresh()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
