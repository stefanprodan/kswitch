import Foundation
import os

public enum LogCategory: String, Sendable {
    case app = "App"
    case kubectl = "Kubectl"
    case flux = "Flux"
    case shell = "Shell"
    case notifications = "Notifications"
    case updates = "Updates"
}

public struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "io.kswitch"

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
