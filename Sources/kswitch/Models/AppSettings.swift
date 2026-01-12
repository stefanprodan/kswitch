import Foundation

struct AppSettings: Codable, Equatable {
    var kubeconfigPaths: [String]
    var kubectlPath: String?
    var refreshIntervalSeconds: Int
    var launchAtLogin: Bool
    var notificationsEnabled: Bool
    var checkForUpdatesAutomatically: Bool

    static let `default` = AppSettings(
        kubeconfigPaths: [],
        kubectlPath: nil,
        refreshIntervalSeconds: 30,
        launchAtLogin: false,
        notificationsEnabled: true,
        checkForUpdatesAutomatically: true
    )

    var effectiveKubeconfigPaths: [String] {
        if !kubeconfigPaths.isEmpty {
            return kubeconfigPaths
        }
        // Default to ~/.kube/config
        return [NSHomeDirectory() + "/.kube/config"]
    }
}
