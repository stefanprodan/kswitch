// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Thread-safe flag to track if a timeout occurred.
private actor DidTimeout {
    private(set) var value = false
    func set() { value = true }
}

/// Thread-safe data accumulator for concurrent pipe reading.
///
/// Marked `@unchecked Sendable` because thread safety is manually guaranteed via `NSLock`.
/// All mutable state (`data`) is protected by the lock in both `append` and `finalize`.
private final class DataAccumulator: @unchecked Sendable {
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

/// Default implementation of CommandRunner using Foundation's Process.
public struct DefaultCommandRunner: CommandRunner {
    public init() {}

    public func run(
        _ executablePath: String,
        args: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = args
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        // Track whether timeout fired before process completed
        let didTimeout = DidTimeout()

        return try await withCheckedThrowingContinuation { continuation in
            // Thread-safe accumulators for pipe data
            let stdoutAccumulator = DataAccumulator()
            let stderrAccumulator = DataAccumulator()

            // Set up readability handlers to drain data continuously (prevents 64KB buffer deadlock)
            stdout.fileHandleForReading.readabilityHandler = { handle in
                stdoutAccumulator.append(handle.availableData)
            }

            stderr.fileHandleForReading.readabilityHandler = { handle in
                stderrAccumulator.append(handle.availableData)
            }

            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    await didTimeout.set()
                    process.terminate()
                }
            }

            // Use terminationHandler instead of blocking waitUntilExit
            process.terminationHandler = { terminatedProcess in
                timeoutTask.cancel()

                // Clear handlers and read any remaining data
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                let finalStdout = stdoutAccumulator.finalize(with: stdout.fileHandleForReading.readDataToEndOfFile())
                let finalStderr = stderrAccumulator.finalize(with: stderr.fileHandleForReading.readDataToEndOfFile())

                // Use lossy UTF-8 conversion to handle malformed output
                let output = String(decoding: finalStdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let errorOutput = String(decoding: finalStderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                // Combine stdout and stderr for error cases
                let finalOutput = terminatedProcess.terminationStatus == 0 ? output : errorOutput

                Task {
                    let timedOut = await didTimeout.value
                    continuation.resume(returning: CommandResult(
                        output: finalOutput,
                        exitCode: terminatedProcess.terminationStatus,
                        timedOut: timedOut
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
