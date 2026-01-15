// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Shell-specific command and parsing rules for getting environment from user's shell.
enum Shell: Sendable {
    case posix  // bash, zsh, sh
    case fish
    case nushell

    static func detect(from shellPath: String) -> Shell {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
        switch shellName {
        case "nu", "nushell":
            return .nushell
        case "fish":
            return .fish
        default:
            return .posix
        }
    }

    /// Arguments to pass to the shell to print PATH.
    func pathArguments() -> [String] {
        switch self {
        case .posix, .fish:
            return ["-l", "-c", "echo $PATH"]
        case .nushell:
            return ["-l", "-c", "$env.PATH | str join ':'"]
        }
    }

    /// Arguments to pass to the shell to run `which`.
    func whichArguments(for tool: String) -> [String] {
        guard let safeTool = Self.sanitizedToolName(tool) else {
            return ["-l", "-c", "which ''"]
        }

        switch self {
        case .posix, .fish:
            return ["-l", "-c", "which \(safeTool)"]
        case .nushell:
            // ^which calls the external binary, avoiding Nushell's table-outputting built-in
            return ["-l", "-c", "^which \(safeTool)"]
        }
    }

    static func sanitizedToolName(_ tool: String) -> String? {
        let pattern = "^[A-Za-z0-9._-]+$"
        guard tool.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return tool
    }

    /// Parse the output of the PATH command.
    func parsePathOutput(_ output: String) -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the output of the `which` command.
    func parseWhichOutput(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch self {
        case .posix, .fish:
            return trimmed
        case .nushell:
            // Reject table output that may have leaked through (check for box-drawing chars)
            let tableChars = CharacterSet(charactersIn: "│╭╮╯╰─┼┤├┬┴┌┐└┘")
            if trimmed.rangeOfCharacter(from: tableChars) != nil {
                return nil
            }
            return trimmed
        }
    }
}
