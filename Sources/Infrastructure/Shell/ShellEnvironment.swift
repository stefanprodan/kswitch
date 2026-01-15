// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Provides access to shell environment and executable discovery.
/// Gets PATH from the user's login shell to find tools like aws, gcloud, etc.
public actor ShellEnvironment {
    public static let shared = ShellEnvironment()

    private var cachedShellPath: String?

    public init() {}

    /// Returns minimal environment variables for kubectl subprocesses.
    /// Uses the user's login shell PATH to ensure exec credential plugins (aws, gcloud, etc.) are found.
    public func getEnvironment(kubeconfigPaths: [String] = []) -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]

        if !kubeconfigPaths.isEmpty {
            env["KUBECONFIG"] = kubeconfigPaths.joined(separator: ":")
        }
        if let home = processEnv["HOME"] {
            env["HOME"] = home
        }
        env["PATH"] = getShellPath()

        return env
    }

    /// Gets the user's PATH from their login shell.
    /// This ensures we have access to tools installed via Homebrew, nix-darwin, asdf, etc.
    private func getShellPath() -> String {
        if let cached = cachedShellPath {
            return cached
        }

        let processEnv = ProcessInfo.processInfo.environment
        let fallback = processEnv["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let shellBinary = processEnv["SHELL"] ?? "/bin/zsh"
        let shell = Shell.detect(from: shellBinary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellBinary)
        process.arguments = shell.pathArguments()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                AppLog.debug("Shell exited with status \(process.terminationStatus), using fallback PATH", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                AppLog.debug("Could not decode shell output, using fallback PATH", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            let path = shell.parsePathOutput(output)
            if path.isEmpty {
                AppLog.debug("Shell returned empty PATH, using fallback", category: .shell)
                cachedShellPath = fallback
                return fallback
            }

            AppLog.debug("Got PATH from login shell: \(path.prefix(100))...", category: .shell)
            cachedShellPath = path
            return path
        } catch {
            AppLog.debug("Failed to run shell: \(error), using fallback PATH", category: .shell)
            cachedShellPath = fallback
            return fallback
        }
    }

    /// Finds an executable by name using `which` through the user's login shell.
    /// Returns the full path if found, nil otherwise.
    public func findExecutable(named name: String) async -> String? {
        let processEnv = ProcessInfo.processInfo.environment
        let shellBinary = processEnv["SHELL"] ?? "/bin/zsh"
        let shell = Shell.detect(from: shellBinary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellBinary)
        process.arguments = shell.whichArguments(for: name)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                AppLog.debug("Could not find \(name) in PATH", category: .shell)
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  let path = shell.parseWhichOutput(output) else {
                AppLog.debug("Could not find \(name) in PATH", category: .shell)
                return nil
            }

            AppLog.debug("Found \(name) at: \(path)", category: .shell)
            return path
        } catch {
            AppLog.debug("Failed to run which for \(name): \(error)", category: .shell)
            return nil
        }
    }
}
