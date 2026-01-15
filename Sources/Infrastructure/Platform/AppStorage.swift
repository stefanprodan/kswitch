// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Domain

/// Handles persistence of app data to disk.
///
/// By default, stores JSON files in `~/Library/Application Support/KSwitch/`:
/// - `clusters.json` - saved cluster configurations and customizations
/// - `settings.json` - app preferences (refresh interval, kubectl path, etc.)
public final class AppStorage: Sendable {
    public static let shared = AppStorage()

    private let storageURL: URL
    private let clustersFileURL: URL
    private let settingsFileURL: URL

    public init(storageURL: URL? = nil) {
        let base = storageURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("KSwitch", isDirectory: true)

        self.storageURL = base
        self.clustersFileURL = base.appendingPathComponent("clusters.json")
        self.settingsFileURL = base.appendingPathComponent("settings.json")
    }

    public func loadClusters() -> [Cluster] {
        guard FileManager.default.fileExists(atPath: clustersFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: clustersFileURL)
            return try JSONDecoder().decode([Cluster].self, from: data)
        } catch {
            AppLog.error("Failed to load clusters: \(error)")
            return []
        }
    }

    public func loadSettings() -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsFileURL.path) else {
            return .default
        }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            AppLog.error("Failed to load settings: \(error)")
            return .default
        }
    }

    public func save(clusters: [Cluster], settings: AppSettings) {
        do {
            try FileManager.default.createDirectory(
                at: storageURL,
                withIntermediateDirectories: true
            )

            let clustersData = try JSONEncoder().encode(clusters)
            try clustersData.write(to: clustersFileURL)

            let settingsData = try JSONEncoder().encode(settings)
            try settingsData.write(to: settingsFileURL)
        } catch {
            AppLog.error("Failed to save: \(error)")
        }
    }
}
