// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Thread-safe data accumulator for shell output.
///
/// Marked `@unchecked Sendable` because thread safety is manually guaranteed via `NSLock`.
/// All mutable state (`data`) is protected by the lock in both `append` and `finalize`.
private final class ShellDataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func finalize(with remainingData: Data) -> Data {
        lock.lock()
        data.append(remainingData)
        let result = data
        lock.unlock()
        return result
    }
}

/// Provides access to shell environment and executable discovery.
/// Gets PATH from the user's login shell to find tools like aws, gcloud, etc.
public actor ShellEnvironment {
    public static let shared = ShellEnvironment()

    private var cachedShellPath: String?

    /// Common installation paths for executables on macOS.
    private static let commonPaths: [String] = [
        "/opt/homebrew/bin",              // Apple Silicon Homebrew
        "/usr/local/bin",                 // Intel Homebrew, manual installs
        "/opt/local/bin",                 // MacPorts
        "/usr/bin",                       // System binaries
        "/bin",                           // Core system binaries
        "/run/current-system/sw/bin",     // Nix (nix-darwin)
        "/nix/var/nix/profiles/default/bin", // Nix (default profile)
    ]

    public init() {}

    /// Returns minimal environment variables for kubectl subprocesses.
    /// Uses the user's login shell PATH to ensure exec credential plugins (aws, gcloud, etc.) are found.
    public func getEnvironment(kubeconfigPaths: [String] = []) async -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]

        if !kubeconfigPaths.isEmpty {
            env["KUBECONFIG"] = kubeconfigPaths.joined(separator: ":")
        }
        if let home = processEnv["HOME"] {
            env["HOME"] = home
        }
        env["PATH"] = await getShellPath()

        return env
    }

    /// Gets the user's PATH from their login shell.
    /// This ensures we have access to tools installed via Homebrew, nix-darwin, asdf, etc.
    private func getShellPath() async -> String {
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

        let result = await runShellProcess(process, pipe: pipe, shell: shell, fallback: fallback)
        cachedShellPath = result
        return result
    }

    private func runShellProcess(_ process: Process, pipe: Pipe, shell: Shell, fallback: String) async -> String {
        await withCheckedContinuation { continuation in
            let accumulator = ShellDataAccumulator()

            pipe.fileHandleForReading.readabilityHandler = { handle in
                accumulator.append(handle.availableData)
            }

            process.terminationHandler = { [weak self] terminatedProcess in
                pipe.fileHandleForReading.readabilityHandler = nil

                let data = accumulator.finalize(with: pipe.fileHandleForReading.readDataToEndOfFile())

                guard terminatedProcess.terminationStatus == 0 else {
                    AppLog.debug("Shell exited with status \(terminatedProcess.terminationStatus), using fallback PATH", category: .shell)
                    Task { await self?.setCachedPath(fallback) }
                    continuation.resume(returning: fallback)
                    return
                }

                // Use lossy UTF-8 conversion
                let output = String(decoding: data, as: UTF8.self)
                let path = shell.parsePathOutput(output)

                if path.isEmpty {
                    AppLog.debug("Shell returned empty PATH, using fallback", category: .shell)
                    Task { await self?.setCachedPath(fallback) }
                    continuation.resume(returning: fallback)
                    return
                }

                let shellName = process.executableURL?.lastPathComponent ?? "shell"
                AppLog.debug("Got PATH from \(shellName): \(path.prefix(100))...", category: .shell)
                Task { await self?.setCachedPath(path) }
                continuation.resume(returning: path)
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                AppLog.debug("Failed to run shell: \(error), using fallback PATH", category: .shell)
                continuation.resume(returning: fallback)
            }
        }
    }

    private func setCachedPath(_ path: String) {
        cachedShellPath = path
    }

    /// Finds an executable by name using `which` through the user's login shell.
    /// Falls back to searching common paths if shell lookup fails.
    /// Returns the full path if found, nil otherwise.
    public func findExecutable(named name: String) async -> String? {
        // First try shell which
        if let path = await findExecutableViaShell(named: name) {
            return path
        }

        // Fallback: search common paths directly
        if let path = searchCommonPaths(for: name) {
            AppLog.debug("Found \(name) via fallback search at: \(path)", category: .shell)
            return path
        }

        return nil
    }

    /// Searches common paths for an executable when shell `which` fails.
    private func searchCommonPaths(for name: String) -> String? {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let homePaths = [
            "\(homeDir)/bin",
            "\(homeDir)/.nix-profile/bin",  // Nix (user profile)
            "\(homeDir)/.asdf/shims",       // asdf version manager
        ]
        let searchPaths = Self.commonPaths + homePaths

        for dir in searchPaths {
            let fullPath = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    /// Finds an executable by name using `which` through the user's login shell.
    private func findExecutableViaShell(named name: String) async -> String? {
        let processEnv = ProcessInfo.processInfo.environment
        let shellBinary = processEnv["SHELL"] ?? "/bin/zsh"
        let shell = Shell.detect(from: shellBinary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellBinary)
        process.arguments = shell.whichArguments(for: name)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        return await withCheckedContinuation { continuation in
            let accumulator = ShellDataAccumulator()

            pipe.fileHandleForReading.readabilityHandler = { handle in
                accumulator.append(handle.availableData)
            }

            process.terminationHandler = { terminatedProcess in
                pipe.fileHandleForReading.readabilityHandler = nil

                let data = accumulator.finalize(with: pipe.fileHandleForReading.readDataToEndOfFile())

                guard terminatedProcess.terminationStatus == 0 else {
                    AppLog.debug("Could not find \(name) via shell which", category: .shell)
                    continuation.resume(returning: nil)
                    return
                }

                // Use lossy UTF-8 conversion
                let output = String(decoding: data, as: UTF8.self)
                guard let path = shell.parseWhichOutput(output) else {
                    AppLog.debug("Could not parse which output for \(name)", category: .shell)
                    continuation.resume(returning: nil)
                    return
                }

                AppLog.debug("Found \(name) at: \(path)", category: .shell)
                continuation.resume(returning: path)
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                AppLog.debug("Failed to run which for \(name): \(error)", category: .shell)
                continuation.resume(returning: nil)
            }
        }
    }
}
