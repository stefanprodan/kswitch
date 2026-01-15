import Foundation
import Domain

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

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
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

                    continuation.resume(returning: CommandResult(
                        output: finalOutput,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
