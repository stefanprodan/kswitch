// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure
#if ENABLE_SPARKLE
import Sparkle
#endif

@main
struct KSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

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
        } label: {
            MenuBarIcon()
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
}

// App delegate for startup configuration
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as menu bar only (no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}
