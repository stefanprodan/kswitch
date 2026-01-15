// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct ClusterTests {

    // MARK: - Effective Name

    @Test func clusterUsesContextNameWhenNoDisplayName() {
        let cluster = Cluster(contextName: "my-context")
        #expect(cluster.effectiveName == "my-context")
    }

    @Test func clusterUsesDisplayNameWhenSet() {
        var cluster = Cluster(contextName: "my-context")
        cluster.displayName = "My Cluster"
        #expect(cluster.effectiveName == "My Cluster")
    }

    @Test func effectiveNameReturnsContextNameWhenDisplayNameIsNil() {
        var cluster = Cluster(contextName: "context-name")
        cluster.displayName = nil
        #expect(cluster.effectiveName == "context-name")
    }

    // MARK: - Truncated Name

    @Test func truncatedNameShortensLongNames() {
        var cluster = Cluster(contextName: "a")
        cluster.displayName = "This is a very long cluster name that exceeds thirty characters"
        #expect(cluster.truncatedName.count <= 30)
        #expect(cluster.truncatedName.hasSuffix("..."))
    }

    @Test func truncatedNamePreservesShortNames() {
        let cluster = Cluster(contextName: "short-name")
        #expect(cluster.truncatedName == "short-name")
    }

    @Test func truncatedNameExactly30Characters() {
        var cluster = Cluster(contextName: "a")
        cluster.displayName = "123456789012345678901234567890" // exactly 30 chars
        #expect(cluster.truncatedName == "123456789012345678901234567890")
        #expect(!cluster.truncatedName.hasSuffix("..."))
    }

    @Test func truncatedName31CharactersGetsTruncated() {
        var cluster = Cluster(contextName: "a")
        cluster.displayName = "1234567890123456789012345678901" // 31 chars
        #expect(cluster.truncatedName.count == 30)
        #expect(cluster.truncatedName.hasSuffix("..."))
    }

    // MARK: - Default Values

    @Test func newClusterHasDefaultValues() {
        let cluster = Cluster(contextName: "test")
        #expect(cluster.contextName == "test")
        #expect(cluster.displayName == nil)
        #expect(cluster.isHidden == false)
        #expect(cluster.sortOrder == 0)
        #expect(cluster.isFavorite == false)
        #expect(cluster.isInKubeconfig == true)
    }

    @Test func newClusterHasUniqueId() {
        let cluster1 = Cluster(contextName: "test")
        let cluster2 = Cluster(contextName: "test")
        #expect(cluster1.id != cluster2.id)
    }

    @Test func newClusterHasValidColorHex() {
        let cluster = Cluster(contextName: "test")
        #expect(Cluster.defaultColors.contains(cluster.colorHex))
    }

    // MARK: - Codable

    @Test func clusterIsEncodableAndDecodable() throws {
        var original = Cluster(contextName: "my-context")
        original.displayName = "My Cluster"
        original.isHidden = true
        original.isFavorite = true
        original.sortOrder = 5

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Cluster.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.contextName == original.contextName)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.isHidden == original.isHidden)
        #expect(decoded.isFavorite == original.isFavorite)
        #expect(decoded.sortOrder == original.sortOrder)
    }

    // MARK: - Hashable

    @Test func clustersWithSameValuesAreEqual() {
        let cluster1 = Cluster(contextName: "test")
        let cluster2 = cluster1 // Copy, same values
        #expect(cluster1 == cluster2)
    }

    @Test func clustersWithDifferentIdsAreNotEqual() {
        let cluster1 = Cluster(contextName: "test")
        let cluster2 = Cluster(contextName: "test")
        #expect(cluster1 != cluster2) // Different IDs (UUID generated in init)
    }

    @Test func clustersWithDifferentPropertiesAreNotEqual() {
        let cluster1 = Cluster(contextName: "test")
        var cluster2 = cluster1
        cluster2.displayName = "Different Name"
        #expect(cluster1 != cluster2) // Different displayName
    }

    // MARK: - Default Colors

    @Test func defaultColorsContainsExpectedCount() {
        #expect(Cluster.defaultColors.count == 8)
    }

    @Test func defaultColorsAreValidHexFormat() {
        for color in Cluster.defaultColors {
            #expect(color.hasPrefix("#"))
            #expect(color.count == 7) // #RRGGBB
        }
    }

    // MARK: - Sorted By Favorites

    @Test func sortedByFavoritesPutsFavoritesFirst() {
        var favorite = Cluster(contextName: "zeta-favorite")
        favorite.isFavorite = true

        let regular = Cluster(contextName: "alpha-regular")

        let clusters = [regular, favorite]
        let sorted = clusters.sortedByFavorites()

        #expect(sorted[0].contextName == "zeta-favorite")
        #expect(sorted[1].contextName == "alpha-regular")
    }

    @Test func sortedByFavoritesPutsHiddenLast() {
        var hidden = Cluster(contextName: "alpha-hidden")
        hidden.isHidden = true

        let regular = Cluster(contextName: "zeta-regular")

        let clusters = [hidden, regular]
        let sorted = clusters.sortedByFavorites()

        #expect(sorted[0].contextName == "zeta-regular")
        #expect(sorted[1].contextName == "alpha-hidden")
    }

    @Test func sortedByFavoritesOrdersFavoritesBeforeHidden() {
        var favorite = Cluster(contextName: "favorite")
        favorite.isFavorite = true

        var hidden = Cluster(contextName: "hidden")
        hidden.isHidden = true

        let regular = Cluster(contextName: "regular")

        let clusters = [hidden, regular, favorite]
        let sorted = clusters.sortedByFavorites()

        #expect(sorted[0].contextName == "favorite")
        #expect(sorted[1].contextName == "regular")
        #expect(sorted[2].contextName == "hidden")
    }

    @Test func sortedByFavoritesSortsAlphabeticallyWithinGroups() {
        var favA = Cluster(contextName: "alpha")
        favA.isFavorite = true
        var favZ = Cluster(contextName: "zeta")
        favZ.isFavorite = true

        let regB = Cluster(contextName: "bravo")
        let regC = Cluster(contextName: "charlie")

        var hidX = Cluster(contextName: "x-ray")
        hidX.isHidden = true
        var hidY = Cluster(contextName: "yankee")
        hidY.isHidden = true

        let clusters = [favZ, regC, hidY, favA, hidX, regB]
        let sorted = clusters.sortedByFavorites()

        // Favorites alphabetically
        #expect(sorted[0].contextName == "alpha")
        #expect(sorted[1].contextName == "zeta")
        // Regular alphabetically
        #expect(sorted[2].contextName == "bravo")
        #expect(sorted[3].contextName == "charlie")
        // Hidden alphabetically
        #expect(sorted[4].contextName == "x-ray")
        #expect(sorted[5].contextName == "yankee")
    }

    @Test func sortedByFavoritesHandlesEmptyArray() {
        let clusters: [Cluster] = []
        let sorted = clusters.sortedByFavorites()
        #expect(sorted.isEmpty)
    }

    @Test func sortedByFavoritesSortsCaseInsensitively() {
        let upper = Cluster(contextName: "ALPHA")
        let lower = Cluster(contextName: "beta")

        let clusters = [lower, upper]
        let sorted = clusters.sortedByFavorites()

        #expect(sorted[0].contextName == "ALPHA")
        #expect(sorted[1].contextName == "beta")
    }

    @Test func sortedByFavoritesUsesEffectiveName() {
        var clusterA = Cluster(contextName: "zeta-context")
        clusterA.displayName = "Alpha Display"

        var clusterB = Cluster(contextName: "alpha-context")
        clusterB.displayName = "Zeta Display"

        let clusters = [clusterB, clusterA]
        let sorted = clusters.sortedByFavorites()

        // Should sort by effectiveName (displayName), not contextName
        #expect(sorted[0].displayName == "Alpha Display")
        #expect(sorted[1].displayName == "Zeta Display")
    }
}
