// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

#if ENABLE_SPARKLE
import Sparkle
import SwiftUI

/// Delegate to receive update notifications from Sparkle.
private class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate, @unchecked Sendable {
    weak var wrapper: SparkleUpdater?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let wrapper = self.wrapper
        Task { @MainActor in
            wrapper?.setUpdateAvailable(version: version)
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let wrapper = self.wrapper
        Task { @MainActor in
            wrapper?.clearUpdateAvailable()
        }
    }
}

/// User driver delegate for background/menu bar apps.
private class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}

/// SwiftUI wrapper for Sparkle updater.
///
/// Manages the Sparkle update lifecycle and provides observable properties for UI binding.
/// Only initializes when running from a proper .app bundle with required Info.plist keys.
@MainActor
@Observable
final class SparkleUpdater {
    private var controller: SPUStandardUpdaterController?
    private var updaterDelegate: SparkleUpdaterDelegate?
    private var userDriverDelegate: SparkleUserDriverDelegate?

    private(set) var isUpdateAvailable = false
    private(set) var availableVersion: String?

    var isAvailable: Bool { controller != nil }
    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }
    var lastUpdateCheckDate: Date? { controller?.updater.lastUpdateCheckDate }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    init() {
        if Self.isProperAppBundle() {
            let delegate = SparkleUpdaterDelegate()
            self.updaterDelegate = delegate
            let userDriver = SparkleUserDriverDelegate()
            self.userDriverDelegate = userDriver

            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: delegate,
                userDriverDelegate: userDriver
            )
            delegate.wrapper = self
        }
    }

    func checkForUpdates() {
        guard let controller = controller, controller.updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        controller?.updater.checkForUpdatesInBackground()
    }

    fileprivate func setUpdateAvailable(version: String) {
        isUpdateAvailable = true
        availableVersion = version
    }

    fileprivate func clearUpdateAvailable() {
        isUpdateAvailable = false
        availableVersion = nil
    }

    private static func isProperAppBundle() -> Bool {
        let bundle = Bundle.main
        guard bundle.bundlePath.hasSuffix(".app") else { return false }
        guard let info = bundle.infoDictionary,
              info["CFBundleIdentifier"] != nil,
              info["CFBundleVersion"] != nil,
              let feedURL = info["SUFeedURL"] as? String,
              !feedURL.isEmpty else { return false }
        return true
    }
}

// MARK: - SwiftUI Environment

private struct SparkleUpdaterKey: EnvironmentKey {
    static let defaultValue: SparkleUpdater? = nil
}

extension EnvironmentValues {
    @MainActor
    var sparkleUpdater: SparkleUpdater? {
        get { self[SparkleUpdaterKey.self] }
        set { self[SparkleUpdaterKey.self] = newValue }
    }
}
#endif
