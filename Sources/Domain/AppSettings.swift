// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var kubeconfigPaths: [String]
    public var kubectlPath: String?
    public var refreshIntervalSeconds: Int
    public var launchAtLogin: Bool
    public var notificationsEnabled: Bool
    public var autoupdate: Bool

    // Task Runner settings
    public var taskShellPath: String?
    public var tasksDirectory: String?
    public var taskTimeoutMinutes: Int

    public static let `default` = AppSettings(
        kubeconfigPaths: [],
        kubectlPath: nil,
        refreshIntervalSeconds: 30,
        launchAtLogin: false,
        notificationsEnabled: true,
        autoupdate: true,
        taskShellPath: nil,
        tasksDirectory: "~/.kswitch/tasks",
        taskTimeoutMinutes: 5
    )

    public init(
        kubeconfigPaths: [String],
        kubectlPath: String?,
        refreshIntervalSeconds: Int,
        launchAtLogin: Bool,
        notificationsEnabled: Bool,
        autoupdate: Bool,
        taskShellPath: String? = nil,
        tasksDirectory: String? = nil,
        taskTimeoutMinutes: Int = 5
    ) {
        self.kubeconfigPaths = kubeconfigPaths
        self.kubectlPath = kubectlPath
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.launchAtLogin = launchAtLogin
        self.notificationsEnabled = notificationsEnabled
        self.autoupdate = autoupdate
        self.taskShellPath = taskShellPath
        self.tasksDirectory = tasksDirectory
        self.taskTimeoutMinutes = taskTimeoutMinutes
    }

    public var effectiveKubeconfigPaths: [String] {
        if !kubeconfigPaths.isEmpty {
            return kubeconfigPaths
        }
        // Default to ~/.kube/config
        return [NSHomeDirectory() + "/.kube/config"]
    }

    /// Returns the tasks directory path, expanding ~ to home directory.
    /// Returns nil if no tasks directory is configured.
    public var effectiveTasksDirectory: String? {
        guard let dir = tasksDirectory, !dir.isEmpty else {
            return nil
        }
        if dir.hasPrefix("~") {
            return NSHomeDirectory() + dir.dropFirst()
        }
        return dir
    }
}
