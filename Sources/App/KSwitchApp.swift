// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UserNotifications
import Domain
import Infrastructure
#if ENABLE_SPARKLE
import Sparkle
#endif

@main
struct KSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    #if ENABLE_SPARKLE
    @State private var sparkleUpdater = SparkleUpdater()
    #endif

    var body: some Scene {
        // Menu bar
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                #if ENABLE_SPARKLE
                .environment(\.sparkleUpdater, sparkleUpdater)
                #endif
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        } label: {
            MenuBarIcon(variant: menuBarIconVariant)
        }
        .menuBarExtraStyle(.window)

        // Main window (single instance)
        Window("KSwitch", id: "main") {
            MainWindow()
                .environment(appState)
                #if ENABLE_SPARKLE
                .environment(\.sparkleUpdater, sparkleUpdater)
                #endif
                .containerBackground(.background, for: .window)
                .onAppear {
                    // Show in Dock when window opens
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    // Hide from Dock when window closes
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    private var menuBarIconVariant: MenuBarIconVariant {
        #if ENABLE_SPARKLE
        if sparkleUpdater.isUpdateAvailable {
            return .info
        }
        #endif
        if let status = appState.currentClusterStatus,
           case .unreachable = status.reachability {
            return .info
        }
        return .normal
    }
}

// Notification name for opening main window from notification clicks
extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

// App delegate for startup configuration and notification handling
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as menu bar only (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Set self as the notification center delegate to handle user interactions
        UNUserNotificationCenter.current().delegate = self
    }

    // Called when user clicks on a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Post notification to trigger main window opening from SwiftUI context
        Task { @MainActor in
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        completionHandler()
    }

    // Show notifications even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
