// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UserNotifications

/// Sends macOS notifications for cluster state changes via `UNUserNotificationCenter`.
///
/// Notifies when clusters become unreachable/reachable or when Flux reconciliation
/// failures increase. Requires the app to run as a proper bundle and
/// user authorization for alerts and sounds.
public actor NotificationAlerter {
    public static let shared = NotificationAlerter()

    private var isAuthorized = false

    // Check if running as a proper app bundle (notifications require this)
    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    public init() {}

    public func requestAuthorization() async {
        guard canUseNotifications else {
            AppLog.warning("Notifications disabled: not running as app bundle", category: .notifications)
            return
        }

        do {
            let center = UNUserNotificationCenter.current()
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
            AppLog.info("Notification authorization: \(isAuthorized ? "granted" : "denied")", category: .notifications)
        } catch {
            AppLog.error("Failed to request notification authorization: \(error)", category: .notifications)
        }
    }

    public func notifyClusterUnreachable(clusterName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Cluster Unreachable"
        content.body = "\(clusterName) is not responding"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cluster-unreachable-\(clusterName)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    public func notifyClusterReachable(clusterName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Cluster Recovered"
        content.body = "\(clusterName) is now reachable"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cluster-reachable-\(clusterName)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    public func notifyFluxFailures(clusterName: String, failingCount: Int) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Flux Reconciliation Failures"
        content.body = "\(clusterName): \(failingCount) reconciler(s) failing"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flux-failures-\(clusterName)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
