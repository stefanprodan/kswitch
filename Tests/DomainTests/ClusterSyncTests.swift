// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
@testable import Domain

@Suite struct ClusterSyncTests {

    // MARK: - New Contexts

    @Test func syncCreatesNewClusterForNewContext() {
        let existing: [Cluster] = []
        let result = existing.synced(with: ["ctx-1"])

        #expect(result.count == 1)
        #expect(result[0].contextName == "ctx-1")
        #expect(result[0].isInKubeconfig == true)
        #expect(result[0].sortOrder == 0)
    }

    @Test func syncCreatesMultipleNewClusters() {
        let existing: [Cluster] = []
        let result = existing.synced(with: ["ctx-1", "ctx-2", "ctx-3"])

        #expect(result.count == 3)
        #expect(result[0].contextName == "ctx-1")
        #expect(result[0].sortOrder == 0)
        #expect(result[1].contextName == "ctx-2")
        #expect(result[1].sortOrder == 1)
        #expect(result[2].contextName == "ctx-3")
        #expect(result[2].sortOrder == 2)
    }

    // MARK: - Existing Contexts

    @Test func syncPreservesDisplayName() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.displayName = "My Cluster"

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].displayName == "My Cluster")
    }

    @Test func syncPreservesColorHex() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.colorHex = "#FF0000"

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].colorHex == "#FF0000")
    }

    @Test func syncPreservesFavorite() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.isFavorite = true

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].isFavorite == true)
    }

    @Test func syncPreservesHidden() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.isHidden = true

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].isHidden == true)
    }

    @Test func syncPreservesId() {
        let cluster = Cluster(contextName: "ctx-1")
        let originalId = cluster.id

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].id == originalId)
    }

    @Test func syncUpdatesSortOrder() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.sortOrder = 5

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].sortOrder == 0)
    }

    @Test func syncMarksAsInKubeconfig() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.isInKubeconfig = false

        let result = [cluster].synced(with: ["ctx-1"])

        #expect(result[0].isInKubeconfig == true)
    }

    // MARK: - Removed Contexts

    @Test func syncMarksRemovedContextAsNotInKubeconfig() {
        let cluster = Cluster(contextName: "ctx-1")

        let result = [cluster].synced(with: [])

        #expect(result.count == 1)
        #expect(result[0].contextName == "ctx-1")
        #expect(result[0].isInKubeconfig == false)
    }

    @Test func syncPreservesRemovedClusterCustomizations() {
        var cluster = Cluster(contextName: "ctx-1")
        cluster.displayName = "My Cluster"
        cluster.colorHex = "#FF0000"
        cluster.isFavorite = true

        let result = [cluster].synced(with: [])

        #expect(result[0].displayName == "My Cluster")
        #expect(result[0].colorHex == "#FF0000")
        #expect(result[0].isFavorite == true)
        #expect(result[0].isInKubeconfig == false)
    }

    // MARK: - Mixed Scenarios

    @Test func syncHandlesMixedScenario() {
        var existing1 = Cluster(contextName: "existing-1")
        existing1.displayName = "Existing Cluster"
        existing1.sortOrder = 0

        var existing2 = Cluster(contextName: "existing-2")
        existing2.sortOrder = 1

        var removed = Cluster(contextName: "removed")
        removed.displayName = "Removed Cluster"
        removed.sortOrder = 2

        let clusters = [existing1, existing2, removed]
        let result = clusters.synced(with: ["new-1", "existing-1", "existing-2"])

        #expect(result.count == 4)

        // New cluster at position 0
        #expect(result[0].contextName == "new-1")
        #expect(result[0].sortOrder == 0)
        #expect(result[0].isInKubeconfig == true)

        // Existing cluster 1 at position 1
        #expect(result[1].contextName == "existing-1")
        #expect(result[1].displayName == "Existing Cluster")
        #expect(result[1].sortOrder == 1)
        #expect(result[1].isInKubeconfig == true)

        // Existing cluster 2 at position 2
        #expect(result[2].contextName == "existing-2")
        #expect(result[2].sortOrder == 2)
        #expect(result[2].isInKubeconfig == true)

        // Removed cluster preserves sortOrder, marked as not in kubeconfig
        #expect(result[3].contextName == "removed")
        #expect(result[3].displayName == "Removed Cluster")
        #expect(result[3].isInKubeconfig == false)
    }

    @Test func syncReordersBasedOnKubeconfigOrder() {
        var cluster1 = Cluster(contextName: "ctx-a")
        cluster1.sortOrder = 0

        var cluster2 = Cluster(contextName: "ctx-b")
        cluster2.sortOrder = 1

        var cluster3 = Cluster(contextName: "ctx-c")
        cluster3.sortOrder = 2

        let clusters = [cluster1, cluster2, cluster3]
        // Reverse the order in kubeconfig
        let result = clusters.synced(with: ["ctx-c", "ctx-b", "ctx-a"])

        #expect(result[0].contextName == "ctx-c")
        #expect(result[0].sortOrder == 0)
        #expect(result[1].contextName == "ctx-b")
        #expect(result[1].sortOrder == 1)
        #expect(result[2].contextName == "ctx-a")
        #expect(result[2].sortOrder == 2)
    }

    // MARK: - Empty Cases

    @Test func syncWithEmptyContextsAndNoClusters() {
        let result = [Cluster]().synced(with: [])
        #expect(result.isEmpty)
    }

    @Test func syncWithEmptyContextsPreservesRemovedClusters() {
        let cluster = Cluster(contextName: "ctx-1")
        let result = [cluster].synced(with: [])

        #expect(result.count == 1)
        #expect(result[0].isInKubeconfig == false)
    }
}
