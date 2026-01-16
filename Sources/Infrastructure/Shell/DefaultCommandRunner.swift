// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Thread-safe flag to track if a timeout occurred.
private actor DidTimeout {
    private(set) var value = false
    func set() { value = true }
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
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    await didTimeout.set()
                    process.terminate()
                }
            }

            Task {
                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutTask.cancel()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorOutput = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    // Combine stdout and stderr for error cases
                    let finalOutput = process.terminationStatus == 0 ? output : errorOutput
                    let timedOut = await didTimeout.value

                    continuation.resume(returning: CommandResult(
                        output: finalOutput,
                        exitCode: process.terminationStatus,
                        timedOut: timedOut
                    ))
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
