// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation
import Domain

/// Thread-safe data accumulator for task output with memory limit.
private final class TaskOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit: Int

    /// Creates an accumulator with a memory limit.
    /// - Parameter limit: Maximum bytes to store (default 10MB).
    init(limit: Int = 10 * 1024 * 1024) {
        self.limit = limit
    }

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        let available = limit - data.count
        if available > 0 {
            data.append(newData.prefix(available))
        }
    }

    func finalize(with remainingData: Data) -> Data {
        lock.lock()
        defer { lock.unlock() }
        let available = limit - data.count
        if available > 0 {
            data.append(remainingData.prefix(available))
        }
        return data
    }

    func currentData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

/// Thread-safe container for timeout state.
private final class TimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var _timedOut = false
    private var _task: Task<Void, Never>?

    var timedOut: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _timedOut
        }
        set {
            lock.lock()
            _timedOut = newValue
            lock.unlock()
        }
    }

    var task: Task<Void, Never>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _task
        }
        set {
            lock.lock()
            _task = newValue
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        _task?.cancel()
        lock.unlock()
    }
}

/// Result of a task execution.
public struct TaskResult: Sendable {
    public let output: Data
    public let exitCode: Int32
    public let timedOut: Bool
    public let runID: UUID
}

/// Executes task scripts directly using their shebang.
///
/// Runs scripts capturing raw output including ANSI escape codes for terminal display.
/// Uses the user's login shell PATH to find tools like kubectl, aws, gcloud, etc.
public actor TaskRunner {
    private var runningProcesses: [UUID: Process] = [:]

    public init() {}

    /// Runs a task script with the given input values.
    ///
    /// - Parameters:
    ///   - task: The task to run.
    ///   - inputValues: Environment variable values for task inputs.
    ///   - timeoutMinutes: Maximum execution time in minutes.
    ///   - onStart: Callback with run ID when the process starts (for tracking/cancellation).
    ///   - onOutput: Callback for streaming output data.
    /// - Returns: TaskResult with output, exit code, timeout status, and run ID.
    public func run(
        task: ScriptTask,
        inputValues: [String: String] = [:],
        timeoutMinutes: Int = 5,
        onStart: (@Sendable (UUID) -> Void)? = nil,
        onOutput: (@Sendable (Data) -> Void)? = nil
    ) async -> TaskResult {
        let runID = UUID()
        let scriptPath = task.scriptPath
        let scriptDir = URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path

        // Create temp file for capturing real exit code (script command always returns 0)
        let exitCodeFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("kswitch-exit-\(runID.uuidString)")

        // Get environment with user's shell PATH (finds kubectl, aws, gcloud, etc.)
        var env = await ShellEnvironment.shared.getEnvironment()
        env["TERM"] = "xterm-256color"
        env["FORCE_COLOR"] = "1"
        env["CLICOLOR_FORCE"] = "1"

        // Add user input values first
        for (key, value) in inputValues {
            env[key] = value
        }

        // Set internal variables LAST to prevent tampering by user inputs
        env["KSWITCH_TARGET_SCRIPT"] = scriptPath
        env["KSWITCH_EXIT_FILE"] = exitCodeFile.path

        // Use /usr/bin/script for PTY emulation (enables colors, progress bars, etc.)
        // Wrap with bash to capture the real exit code to a temp file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = [
            "-q", "/dev/null",
            "/bin/bash", "-c",
            "\"$KSWITCH_TARGET_SCRIPT\"; echo $? > \"$KSWITCH_EXIT_FILE\""
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let accumulator = TaskOutputAccumulator()
        runningProcesses[runID] = process

        // Notify caller of runID immediately so they can track/cancel
        onStart?(runID)

        AppLog.info("Running task: \(task.name) at \(scriptPath) (runID: \(runID))", category: .tasks)

        return await withTaskCancellationHandler {
            await runProcess(
                process,
                pipe: pipe,
                accumulator: accumulator,
                runID: runID,
                scriptPath: scriptPath,
                exitCodeFile: exitCodeFile,
                timeoutMinutes: timeoutMinutes,
                onOutput: onOutput
            )
        } onCancel: {
            Task { await self.stop(runID: runID) }
        }
    }

    private func runProcess(
        _ process: Process,
        pipe: Pipe,
        accumulator: TaskOutputAccumulator,
        runID: UUID,
        scriptPath: String,
        exitCodeFile: URL,
        timeoutMinutes: Int,
        onOutput: (@Sendable (Data) -> Void)?
    ) async -> TaskResult {
        let timeoutState = TimeoutState()

        return await withCheckedContinuation { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    accumulator.append(data)
                    onOutput?(data)
                }
            }

            process.terminationHandler = { [weak self] _ in
                pipe.fileHandleForReading.readabilityHandler = nil
                timeoutState.cancel()

                let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = accumulator.finalize(with: remainingData)
                if !remainingData.isEmpty {
                    onOutput?(remainingData)
                }

                Task { await self?.removeProcess(runID) }

                // Read real exit code from temp file (script command always returns 0)
                var exitCode: Int32 = -1
                if let contents = try? String(contentsOf: exitCodeFile, encoding: .utf8),
                   let code = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    exitCode = code
                }
                try? FileManager.default.removeItem(at: exitCodeFile)

                AppLog.info("Task finished: \(scriptPath) with exit code \(exitCode)", category: .tasks)

                continuation.resume(returning: TaskResult(
                    output: output,
                    exitCode: exitCode,
                    timedOut: timeoutState.timedOut,
                    runID: runID
                ))
            }

            do {
                try process.run()

                // Set up timeout
                timeoutState.task = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeoutMinutes * 60))
                    guard !Task.isCancelled else { return }
                    timeoutState.timedOut = true
                    AppLog.warning("Task timed out after \(timeoutMinutes) minutes: \(scriptPath)", category: .tasks)

                    // Delegate to stop() to avoid duplicating kill logic
                    await self?.stop(runID: runID)
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                try? FileManager.default.removeItem(at: exitCodeFile)
                Task { [weak self] in await self?.removeProcess(runID) }
                AppLog.error("Failed to run task: \(error)", category: .tasks)
                continuation.resume(returning: TaskResult(
                    output: Data(),
                    exitCode: -1,
                    timedOut: false,
                    runID: runID
                ))
            }
        }
    }

    /// Stops a running task by its run ID.
    public func stop(runID: UUID) {
        guard let process = runningProcesses[runID] else {
            AppLog.warning("No process found for runID: \(runID)", category: .tasks)
            return
        }

        let pid = process.processIdentifier
        AppLog.info("Stopping task run: \(runID) (root PID: \(pid))", category: .tasks)

        // Kill entire process tree recursively (children first, then parent)
        if pid > 0 {
            killChildren(of: pid)
        }

        // Finally kill the wrapper process
        if process.isRunning {
            process.terminate()
        }
    }

    /// Recursively finds and kills all descendants of a process.
    private func killChildren(of parentPID: pid_t) {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-P", String(parentPID)]

        let pipe = Pipe()
        pgrep.standardOutput = pipe
        pgrep.standardError = Pipe() // discard errors

        do {
            try pgrep.run()
            pgrep.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let childPIDs = output
                    .components(separatedBy: .newlines)
                    .compactMap { pid_t($0) }
                    .filter { $0 > 0 }

                for childPID in childPIDs {
                    // Recursively kill grandchildren first (bottom-up)
                    killChildren(of: childPID)

                    // Then kill this child
                    AppLog.debug("Killing child PID: \(childPID) (parent: \(parentPID))", category: .tasks)
                    kill(childPID, SIGTERM)
                }
            }
        } catch {
            // Normal if no children exist (pgrep returns exit 1)
        }
    }

    /// Returns true if the specified run is currently running.
    public func isRunning(runID: UUID) -> Bool {
        runningProcesses[runID]?.isRunning ?? false
    }

    private func removeProcess(_ runID: UUID) {
        runningProcesses.removeValue(forKey: runID)
    }
}
