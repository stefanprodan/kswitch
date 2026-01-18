// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Thread-safe data accumulator for shell output.
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

        return await withCheckedContinuation { continuation in
            let accumulator = ShellDataAccumulator()

            pipe.fileHandleForReading.readabilityHandler = { handle in
                accumulator.append(handle.availableData)
            }

            process.terminationHandler = { terminatedProcess in
                pipe.fileHandleForReading.readabilityHandler = nil

                let data = accumulator.finalize(with: pipe.fileHandleForReading.readDataToEndOfFile())

                guard terminatedProcess.terminationStatus == 0 else {
                    AppLog.debug("Could not find \(name) in PATH", category: .shell)
                    continuation.resume(returning: nil)
                    return
                }

                // Use lossy UTF-8 conversion
                let output = String(decoding: data, as: UTF8.self)
                guard let path = shell.parseWhichOutput(output) else {
                    AppLog.debug("Could not find \(name) in PATH", category: .shell)
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
