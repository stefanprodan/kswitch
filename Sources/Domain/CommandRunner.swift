// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Mockable

/// Protocol for executing shell commands, abstracted for testing.
@Mockable
public protocol CommandRunner: Sendable {
    /// Runs a command and returns the result.
    /// - Parameters:
    ///   - executablePath: Full path to the executable
    ///   - args: Command arguments
    ///   - environment: Environment variables to set
    ///   - timeout: Maximum time to wait for completion
    /// - Returns: The command result with output and exit code
    func run(
        _ executablePath: String,
        args: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> CommandResult
}

/// Result of a command execution.
public struct CommandResult: Sendable, Equatable {
    public let output: String
    public let exitCode: Int32

    public init(output: String, exitCode: Int32) {
        self.output = output
        self.exitCode = exitCode
    }
}
