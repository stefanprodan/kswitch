// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Represents a user-defined input for a task script.
public struct TaskInput: Hashable, Sendable {
    /// The environment variable name (e.g., "AWS_PROFILE").
    public let name: String

    /// Human-readable description (e.g., "AWS profile to use").
    public let description: String

    /// Whether this input is required (KSWITCH_INPUT) or optional (KSWITCH_INPUT_OPT).
    public let isRequired: Bool

    public init(name: String, description: String = "", isRequired: Bool = true) {
        self.name = name
        self.description = description
        self.isRequired = isRequired
    }
}

/// Represents a discoverable task script.
public struct ScriptTask: Identifiable, Hashable, Sendable {
    /// Unique identifier (script path).
    public let id: String

    /// Display name derived from filename.
    public var name: String

    /// Full path to the script.
    public var scriptPath: String

    /// Parsed input definitions from script headers.
    public var inputs: [TaskInput]

    public init(scriptPath: String, inputs: [TaskInput] = []) {
        self.id = scriptPath
        self.scriptPath = scriptPath
        self.name = Self.displayName(from: scriptPath)
        self.inputs = inputs
    }

    /// Derives display name from script filename.
    /// "aws-sso-login.kswitch.sh" → "aws sso login"
    public static func displayName(from path: String) -> String {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let name = filename.replacingOccurrences(of: ".kswitch.sh", with: "")
        return name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    /// Parses KSWITCH_INPUT comments from script header (first 50 lines).
    /// Format: # KSWITCH_INPUT: VAR_NAME "Description"
    /// Format: # KSWITCH_INPUT_OPT: VAR_NAME "Description"
    public static func parseInputs(from scriptPath: String) -> [TaskInput] {
        guard let content = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            return []
        }

        var inputs: [TaskInput] = []
        let lines = content.components(separatedBy: .newlines).prefix(50)

        // Regex patterns for required and optional inputs
        // Matches: # KSWITCH_INPUT: VAR_NAME "Description" or # KSWITCH_INPUT: VAR_NAME
        let requiredPattern = #"#\s*KSWITCH_INPUT:\s*(\w+)(?:\s+"([^"]*)")?"#
        let optionalPattern = #"#\s*KSWITCH_INPUT_OPT:\s*(\w+)(?:\s+"([^"]*)")?"#

        let requiredRegex = try? NSRegularExpression(pattern: requiredPattern)
        let optionalRegex = try? NSRegularExpression(pattern: optionalPattern)

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)

            // Check for required input
            if let match = requiredRegex?.firstMatch(in: line, range: range) {
                if let nameRange = Range(match.range(at: 1), in: line) {
                    let name = String(line[nameRange])
                    var description = ""
                    if match.numberOfRanges > 2,
                       let descRange = Range(match.range(at: 2), in: line) {
                        description = String(line[descRange])
                    }
                    inputs.append(TaskInput(name: name, description: description, isRequired: true))
                }
                continue
            }

            // Check for optional input
            if let match = optionalRegex?.firstMatch(in: line, range: range) {
                if let nameRange = Range(match.range(at: 1), in: line) {
                    let name = String(line[nameRange])
                    var description = ""
                    if match.numberOfRanges > 2,
                       let descRange = Range(match.range(at: 2), in: line) {
                        description = String(line[descRange])
                    }
                    inputs.append(TaskInput(name: name, description: description, isRequired: false))
                }
            }
        }

        return inputs
    }

    /// Returns true if this task has any required inputs.
    public var hasRequiredInputs: Bool {
        inputs.contains { $0.isRequired }
    }
}
