// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MenuBarSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var kubeconfigPath: String = ""
    @State private var kubectlPath: String = ""
    @State private var isLoading: Bool = false

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

    private var kubectlExists: Bool {
        FileManager.default.fileExists(atPath: kubectlPath)
    }

    private var canSave: Bool {
        !kubeconfigPaths.isEmpty && validKubeconfigCount > 0 && kubectlExists && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            formHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Form fields
            VStack(alignment: .leading, spacing: 12) {
                kubeconfigField
                kubectlField
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            actionButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundGradient)
        .onAppear {
            loadPaths()
        }
    }

    private var formHeader: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Setup Required")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
            Spacer()
        }
    }

    private var kubeconfigField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("kubeconfig")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                kubeconfigIndicator
            }
            pathTextField(text: $kubeconfigPath)
        }
    }

    @ViewBuilder
    private var kubeconfigIndicator: some View {
        let total = kubeconfigPaths.count
        let valid = validKubeconfigCount

        if total == 0 {
            pathIndicator(exists: false)
        } else if valid == total {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(total == 1 ? "Valid" : "\(total) paths")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                Text("\(valid)/\(total) valid")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var kubectlField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("kubectl")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                pathIndicator(exists: kubectlExists)
            }
            pathTextField(text: $kubectlPath)
        }
    }

    private func pathTextField(text: Binding<String>) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            saveButton
            discoverButton
            Spacer()
            quitButton
        }
    }

    private var discoverButton: some View {
        Button {
            discover()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                Text("Discover")
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

    private var saveButton: some View {
        Button {
            saveAndRefresh()
        } label: {
            HStack(spacing: 4) {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.45)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                    }
                }
                .frame(width: 11, height: 11)
                Text(isLoading ? "Saving" : "Save")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(canSave ? (colorScheme == .dark ? .white : .black) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                Text("Quit")
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

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.15), Color(white: 0.1)]
                : [Color(white: 0.98), Color(white: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func pathIndicator(exists: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(exists ? .green : .red)
                .frame(width: 6, height: 6)
            Text(exists ? "Valid" : "Not found")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func loadPaths() {
        let paths = appState.settings.kubeconfigPaths
        kubeconfigPath = paths.isEmpty ? defaultKubeconfig : paths.joined(separator: ":")

        // Use saved path, or fall back to detected path from startup
        kubectlPath = appState.settings.kubectlPath ?? appState.detectedKubectlPath ?? ""
    }

    private func discover() {
        Task {
            // Re-run kubectl detection
            if let detected = await ShellEnvironment.shared.findExecutable(named: "kubectl") {
                await MainActor.run {
                    kubectlPath = detected
                    appState.detectedKubectlPath = detected
                }
            }

            // Check default kubeconfig
            await MainActor.run {
                if FileManager.default.fileExists(atPath: defaultKubeconfig) {
                    kubeconfigPath = defaultKubeconfig
                }
            }
        }
    }

    private func saveAndRefresh() {
        isLoading = true
        appState.error = nil

        // Save settings
        appState.settings.kubeconfigPaths = kubeconfigPaths
        appState.settings.kubectlPath = kubectlPath.isEmpty ? nil : kubectlPath
        appState.saveToDisk()

        // Refresh
        Task {
            await appState.refreshContexts()
            await appState.refreshAllStatuses()
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
