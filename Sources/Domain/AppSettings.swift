import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var kubeconfigPaths: [String]
    public var kubectlPath: String?
    public var refreshIntervalSeconds: Int
    public var launchAtLogin: Bool
    public var notificationsEnabled: Bool
    public var checkForUpdatesAutomatically: Bool

    public static let `default` = AppSettings(
        kubeconfigPaths: [],
        kubectlPath: nil,
        refreshIntervalSeconds: 30,
        launchAtLogin: false,
        notificationsEnabled: true,
        checkForUpdatesAutomatically: true
    )

    public init(
        kubeconfigPaths: [String],
        kubectlPath: String?,
        refreshIntervalSeconds: Int,
        launchAtLogin: Bool,
        notificationsEnabled: Bool,
        checkForUpdatesAutomatically: Bool
    ) {
        self.kubeconfigPaths = kubeconfigPaths
        self.kubectlPath = kubectlPath
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.launchAtLogin = launchAtLogin
        self.notificationsEnabled = notificationsEnabled
        self.checkForUpdatesAutomatically = checkForUpdatesAutomatically
    }

    public var effectiveKubeconfigPaths: [String] {
        if !kubeconfigPaths.isEmpty {
            return kubeconfigPaths
        }
        // Default to ~/.kube/config
        return [NSHomeDirectory() + "/.kube/config"]
    }
}
