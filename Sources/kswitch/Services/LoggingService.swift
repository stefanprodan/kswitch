import Foundation
import os

enum LogCategory: String {
    case app = "App"
    case kubectl = "Kubectl"
    case flux = "Flux"
    case shell = "Shell"
    case notifications = "Notifications"
    case updates = "Updates"
}

struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "io.kswitch"

    static func debug(_ message: String, category: LogCategory = .app) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: LogCategory = .app) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func warning(_ message: String, category: LogCategory = .app) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: LogCategory = .app) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    private static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
