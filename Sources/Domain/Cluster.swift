// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public struct Cluster: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let contextName: String
    public var displayName: String?
    public var colorHex: String
    public var isHidden: Bool
    public var sortOrder: Int
    public var isFavorite: Bool
    public var isInKubeconfig: Bool

    public var effectiveName: String {
        displayName ?? contextName
    }

    public var truncatedName: String {
        let name = effectiveName
        if name.count > 30 {
            return String(name.prefix(27)) + "..."
        }
        return name
    }

    public init(contextName: String) {
        self.id = UUID()
        self.contextName = contextName
        self.displayName = nil
        self.colorHex = Self.defaultColors.randomElement()!
        self.isHidden = false
        self.sortOrder = 0
        self.isFavorite = false
        self.isInKubeconfig = true
    }

    public static let defaultColors = [
        "#3B82F6", // Blue
        "#10B981", // Green
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#8B5CF6", // Purple
        "#EC4899", // Pink
        "#06B6D4", // Cyan
        "#F97316", // Orange
    ]
}

extension [Cluster] {
    /// Sorts clusters: favorites first, then non-favorites, then hidden. Each group sorted alphabetically.
    public func sortedByFavorites() -> [Cluster] {
        let favorites = self
            .filter { $0.isFavorite && !$0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        let nonFavorites = self
            .filter { !$0.isFavorite && !$0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        let hidden = self
            .filter { $0.isHidden }
            .sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }

        return favorites + nonFavorites + hidden
    }

    /// Syncs clusters with context names from kubeconfig.
    /// - New contexts create new clusters
    /// - Existing contexts preserve customizations (displayName, color, favorite, hidden)
    /// - Removed contexts are marked as not in kubeconfig
    /// - Returns sorted by kubeconfig order, with removed clusters at the end
    public func synced(with contextNames: [String]) -> [Cluster] {
        let existingByContext = Dictionary(uniqueKeysWithValues: map { ($0.contextName, $0) })
        var seenContexts = Set<String>()
        var result: [Cluster] = []

        // Process contexts in kubeconfig order
        for (index, name) in contextNames.enumerated() {
            seenContexts.insert(name)
            if var existing = existingByContext[name] {
                existing.sortOrder = index
                existing.isInKubeconfig = true
                result.append(existing)
            } else {
                var new = Cluster(contextName: name)
                new.sortOrder = index
                result.append(new)
            }
        }

        // Keep clusters that were removed from kubeconfig
        for cluster in self where !seenContexts.contains(cluster.contextName) {
            var removed = cluster
            removed.isInKubeconfig = false
            result.append(removed)
        }

        return result.sorted { $0.sortOrder < $1.sortOrder }
    }
}
