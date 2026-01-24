// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Represents the result of a task execution.
public struct TaskRun: Sendable {
    /// Raw PTY output with ANSI escape codes preserved.
    public let output: Data

    /// Process exit code (0 = success).
    public let exitCode: Int32

    /// When the task run completed.
    public let timestamp: Date

    /// Input values used for this run.
    public let inputValues: [String: String]

    /// Whether the task timed out.
    public let timedOut: Bool

    /// How long the task took to run.
    public let duration: TimeInterval

    /// Whether the task succeeded (exit code 0 and not timed out).
    public var succeeded: Bool {
        exitCode == 0 && !timedOut
    }

    /// Formatted duration string (ms if < 1s, otherwise seconds).
    public var formattedDuration: String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        } else {
            return String(format: "%.1fs", duration)
        }
    }

    public init(
        output: Data,
        exitCode: Int32,
        timestamp: Date = Date(),
        inputValues: [String: String] = [:],
        timedOut: Bool = false,
        duration: TimeInterval = 0
    ) {
        self.output = output
        self.exitCode = exitCode
        self.timestamp = timestamp
        self.inputValues = inputValues
        self.timedOut = timedOut
        self.duration = duration
    }
}
