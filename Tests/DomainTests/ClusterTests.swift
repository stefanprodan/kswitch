import Testing
@testable import Domain

@Suite struct ClusterTests {
    @Test func clusterUsesContextNameWhenNoDisplayName() {
        let cluster = Cluster(contextName: "my-context")
        #expect(cluster.effectiveName == "my-context")
    }

    @Test func clusterUsesDisplayNameWhenSet() {
        var cluster = Cluster(contextName: "my-context")
        cluster.displayName = "My Cluster"
        #expect(cluster.effectiveName == "My Cluster")
    }

    @Test func truncatedNameShortensLongNames() {
        var cluster = Cluster(contextName: "a")
        cluster.displayName = "This is a very long cluster name that exceeds thirty characters"
        #expect(cluster.truncatedName.count <= 30)
        #expect(cluster.truncatedName.hasSuffix("..."))
    }
}
