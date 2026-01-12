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
        var paths = kubeconfigPaths

        // Respect KUBECONFIG environment variable
        if let envKubeconfig = ProcessInfo.processInfo.environment["KUBECONFIG"], !envKubeconfig.isEmpty {
            let envPaths = envKubeconfig.split(separator: ":").map(String.init)
            paths.append(contentsOf: envPaths)
        }

        // Add default kubeconfig if no paths specified
        if paths.isEmpty {
            let defaultPath = NSHomeDirectory() + "/.kube/config"
            if FileManager.default.fileExists(atPath: defaultPath) {
                paths.append(defaultPath)
            }
        }

        return paths
    }
}
