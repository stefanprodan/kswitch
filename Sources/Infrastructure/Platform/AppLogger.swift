// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

/// Log categories for filtering in Console.app or `log stream`.
public enum LogCategory: String, Sendable {
    case app = "App"
    case kubectl = "Kubectl"
    case flux = "Flux"
    case shell = "Shell"
    case notifications = "Notifications"
    case updates = "Updates"
}

/// Unified logging via Apple's `os.Logger` subsystem.
///
/// Logs are viewable in Console.app or via terminal:
/// ```
/// log stream --predicate 'subsystem == "com.stefanprodan.kswitch"' --level debug
/// ```
public struct AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.stefanprodan.kswitch"

    public static func debug(_ message: String, category: LogCategory = .app) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    public static func info(_ message: String, category: LogCategory = .app) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    public static func warning(_ message: String, category: LogCategory = .app) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    public static func error(_ message: String, category: LogCategory = .app) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    private static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
