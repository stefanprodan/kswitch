// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct AppSettingsTests {

    // MARK: - Default Settings

    @Test func defaultSettingsHasExpectedValues() {
        let settings = AppSettings.default
        #expect(settings.kubeconfigPaths.isEmpty)
        #expect(settings.kubectlPath == nil)
        #expect(settings.refreshIntervalSeconds == 30)
        #expect(settings.launchAtLogin == false)
        #expect(settings.notificationsEnabled == true)
        #expect(settings.autoupdate == true)
    }

    // MARK: - Effective Kubeconfig Paths

    @Test func effectiveKubeconfigPathsReturnsConfiguredPaths() {
        let settings = AppSettings(
            kubeconfigPaths: ["/custom/path1", "/custom/path2"],
            kubectlPath: nil,
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: true,
            autoupdate: true
        )
        #expect(settings.effectiveKubeconfigPaths == ["/custom/path1", "/custom/path2"])
    }

    @Test func effectiveKubeconfigPathsReturnsDefaultWhenEmpty() {
        let settings = AppSettings(
            kubeconfigPaths: [],
            kubectlPath: nil,
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: true,
            autoupdate: true
        )
        let expected = NSHomeDirectory() + "/.kube/config"
        #expect(settings.effectiveKubeconfigPaths == [expected])
    }

    @Test func effectiveKubeconfigPathsDefaultContainsKubeConfig() {
        let settings = AppSettings.default
        let paths = settings.effectiveKubeconfigPaths
        #expect(paths.count == 1)
        #expect(paths[0].contains(".kube/config"))
    }

    // MARK: - Codable

    @Test func settingsIsEncodableAndDecodable() throws {
        let original = AppSettings(
            kubeconfigPaths: ["/path/one", "/path/two"],
            kubectlPath: "/usr/local/bin/kubectl",
            refreshIntervalSeconds: 60,
            launchAtLogin: true,
            notificationsEnabled: false,
            autoupdate: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded == original)
    }

    @Test func settingsDecodesFromJSON() throws {
        let json = """
        {
            "kubeconfigPaths": ["/home/user/.kube/config"],
            "kubectlPath": "/usr/bin/kubectl",
            "refreshIntervalSeconds": 15,
            "launchAtLogin": true,
            "notificationsEnabled": true,
            "autoupdate": false
        }
        """

        let decoder = JSONDecoder()
        let settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))

        #expect(settings.kubeconfigPaths == ["/home/user/.kube/config"])
        #expect(settings.kubectlPath == "/usr/bin/kubectl")
        #expect(settings.refreshIntervalSeconds == 15)
        #expect(settings.launchAtLogin == true)
        #expect(settings.notificationsEnabled == true)
        #expect(settings.autoupdate == false)
    }

    @Test func settingsEncodesToExpectedKeys() throws {
        // Use settings with all fields set to ensure they appear in JSON
        let settings = AppSettings(
            kubeconfigPaths: ["/path"],
            kubectlPath: "/kubectl",
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: true,
            autoupdate: true
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("kubeconfigPaths"))
        #expect(json.contains("kubectlPath"))
        #expect(json.contains("refreshIntervalSeconds"))
        #expect(json.contains("launchAtLogin"))
        #expect(json.contains("notificationsEnabled"))
        #expect(json.contains("autoupdate"))
    }

    // MARK: - Equatable

    @Test func settingsWithSameValuesAreEqual() {
        let a = AppSettings(
            kubeconfigPaths: ["/path"],
            kubectlPath: "/kubectl",
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: true,
            autoupdate: true
        )
        let b = AppSettings(
            kubeconfigPaths: ["/path"],
            kubectlPath: "/kubectl",
            refreshIntervalSeconds: 30,
            launchAtLogin: false,
            notificationsEnabled: true,
            autoupdate: true
        )
        #expect(a == b)
    }

    @Test func settingsWithDifferentValuesAreNotEqual() {
        let a = AppSettings.default
        var b = AppSettings.default
        b.refreshIntervalSeconds = 60
        #expect(a != b)
    }

    // MARK: - Refresh Interval Values

    @Test func refreshIntervalCanBeZeroForManualOnly() {
        var settings = AppSettings.default
        settings.refreshIntervalSeconds = 0
        #expect(settings.refreshIntervalSeconds == 0)
    }

    @Test func refreshIntervalAcceptsVariousValues() {
        let intervals = [0, 15, 30, 60, 300]
        for interval in intervals {
            var settings = AppSettings.default
            settings.refreshIntervalSeconds = interval
            #expect(settings.refreshIntervalSeconds == interval)
        }
    }
}
