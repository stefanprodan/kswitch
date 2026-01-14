import Foundation
import UserNotifications

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
            Log.warning("Notifications disabled: not running as app bundle", category: .notifications)
            return
        }

        do {
            let center = UNUserNotificationCenter.current()
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
            Log.info("Notification authorization: \(isAuthorized ? "granted" : "denied")", category: .notifications)
        } catch {
            Log.error("Failed to request notification authorization: \(error)", category: .notifications)
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
