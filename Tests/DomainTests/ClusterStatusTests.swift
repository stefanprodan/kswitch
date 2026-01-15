import Testing
@testable import Domain

@Suite struct ClusterStatusTests {

    // MARK: - Reachability Equality

    @Test func reachabilityUnknownEqualsUnknown() {
        let a = ClusterStatus.Reachability.unknown
        let b = ClusterStatus.Reachability.unknown
        #expect(a == b)
    }

    @Test func reachabilityCheckingEqualsChecking() {
        let a = ClusterStatus.Reachability.checking
        let b = ClusterStatus.Reachability.checking
        #expect(a == b)
    }

    @Test func reachabilityReachableEqualsReachable() {
        let a = ClusterStatus.Reachability.reachable
        let b = ClusterStatus.Reachability.reachable
        #expect(a == b)
    }

    @Test func reachabilityUnreachableEqualsSameMessage() {
        let a = ClusterStatus.Reachability.unreachable("timeout")
        let b = ClusterStatus.Reachability.unreachable("timeout")
        #expect(a == b)
    }

    @Test func reachabilityUnreachableNotEqualsDifferentMessage() {
        let a = ClusterStatus.Reachability.unreachable("timeout")
        let b = ClusterStatus.Reachability.unreachable("connection refused")
        #expect(a != b)
    }

    @Test func reachabilityDifferentStatesNotEqual() {
        #expect(ClusterStatus.Reachability.unknown != ClusterStatus.Reachability.checking)
        #expect(ClusterStatus.Reachability.checking != ClusterStatus.Reachability.reachable)
        #expect(ClusterStatus.Reachability.reachable != ClusterStatus.Reachability.unreachable("error"))
    }

    // MARK: - FluxOperatorState Equality

    @Test func fluxStateUnknownEqualsUnknown() {
        let a = ClusterStatus.FluxOperatorState.unknown
        let b = ClusterStatus.FluxOperatorState.unknown
        #expect(a == b)
    }

    @Test func fluxStateCheckingEqualsChecking() {
        let a = ClusterStatus.FluxOperatorState.checking
        let b = ClusterStatus.FluxOperatorState.checking
        #expect(a == b)
    }

    @Test func fluxStateNotInstalledEqualsNotInstalled() {
        let a = ClusterStatus.FluxOperatorState.notInstalled
        let b = ClusterStatus.FluxOperatorState.notInstalled
        #expect(a == b)
    }

    @Test func fluxStateInstalledEqualsSameVersionAndHealth() {
        let a = ClusterStatus.FluxOperatorState.installed(version: "v2.0.0", healthy: true)
        let b = ClusterStatus.FluxOperatorState.installed(version: "v2.0.0", healthy: true)
        #expect(a == b)
    }

    @Test func fluxStateInstalledNotEqualsDifferentVersion() {
        let a = ClusterStatus.FluxOperatorState.installed(version: "v2.0.0", healthy: true)
        let b = ClusterStatus.FluxOperatorState.installed(version: "v2.1.0", healthy: true)
        #expect(a != b)
    }

    @Test func fluxStateInstalledNotEqualsDifferentHealth() {
        let a = ClusterStatus.FluxOperatorState.installed(version: "v2.0.0", healthy: true)
        let b = ClusterStatus.FluxOperatorState.installed(version: "v2.0.0", healthy: false)
        #expect(a != b)
    }

    @Test func fluxStateDegradedEqualsSameValues() {
        let a = ClusterStatus.FluxOperatorState.degraded(version: "v2.0.0", failing: 3)
        let b = ClusterStatus.FluxOperatorState.degraded(version: "v2.0.0", failing: 3)
        #expect(a == b)
    }

    @Test func fluxStateDegradedNotEqualsDifferentFailing() {
        let a = ClusterStatus.FluxOperatorState.degraded(version: "v2.0.0", failing: 3)
        let b = ClusterStatus.FluxOperatorState.degraded(version: "v2.0.0", failing: 5)
        #expect(a != b)
    }

    // MARK: - Default Values

    @Test func newClusterStatusHasDefaultValues() {
        let status = ClusterStatus()
        #expect(status.reachability == .unknown)
        #expect(status.kubernetesVersion == nil)
        #expect(status.nodeCount == 0)
        #expect(status.nodeError == nil)
        #expect(status.fluxOperator == .unknown)
        #expect(status.fluxReport == nil)
        #expect(status.fluxSummary == nil)
        #expect(status.lastChecked == nil)
    }

    // MARK: - Status Color

    @Test func statusColorGrayForUnknown() {
        var status = ClusterStatus()
        status.reachability = .unknown
        #expect(status.statusColor == .gray)
    }

    @Test func statusColorGrayForChecking() {
        var status = ClusterStatus()
        status.reachability = .checking
        #expect(status.statusColor == .gray)
    }

    @Test func statusColorRedForUnreachable() {
        var status = ClusterStatus()
        status.reachability = .unreachable("connection refused")
        #expect(status.statusColor == .red)
    }

    @Test func statusColorGreenForReachableWithNoFlux() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxSummary = nil
        #expect(status.statusColor == .green)
    }

    @Test func statusColorYellowForReachableWithFailingFlux() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxSummary = makeFluxSummary(failing: 2)
        #expect(status.statusColor == .yellow)
    }

    @Test func statusColorGreenForCheckingWithPreviousData() {
        var status = ClusterStatus()
        status.reachability = .checking
        status.kubernetesVersion = "v1.30.0"
        status.fluxSummary = makeFluxSummary(failing: 0)
        #expect(status.statusColor == .green)
    }

    @Test func statusColorYellowForCheckingWithPreviousFailingFlux() {
        var status = ClusterStatus()
        status.reachability = .checking
        status.kubernetesVersion = "v1.30.0"
        status.fluxSummary = makeFluxSummary(failing: 1)
        #expect(status.statusColor == .yellow)
    }

    // MARK: - Status Label

    @Test func statusLabelHealthyForReachable() {
        var status = ClusterStatus()
        status.reachability = .reachable
        #expect(status.statusLabel == "Healthy")
    }

    @Test func statusLabelDegradedForReachableWithFailingFlux() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxSummary = makeFluxSummary(failing: 3)
        #expect(status.statusLabel == "Degraded")
    }

    @Test func statusLabelOfflineForUnreachable() {
        var status = ClusterStatus()
        status.reachability = .unreachable("connection refused")
        #expect(status.statusLabel == "Offline")
    }

    @Test func statusLabelCheckingForCheckingWithNoData() {
        var status = ClusterStatus()
        status.reachability = .checking
        #expect(status.statusLabel == "Checking")
    }

    @Test func statusLabelHealthyForCheckingWithPreviousData() {
        var status = ClusterStatus()
        status.reachability = .checking
        status.kubernetesVersion = "v1.30.0"
        #expect(status.statusLabel == "Healthy")
    }

    @Test func statusLabelDegradedForCheckingWithPreviousFailingFlux() {
        var status = ClusterStatus()
        status.reachability = .checking
        status.kubernetesVersion = "v1.30.0"
        status.fluxSummary = makeFluxSummary(failing: 2)
        #expect(status.statusLabel == "Degraded")
    }

    @Test func statusLabelUnknownForUnknown() {
        var status = ClusterStatus()
        status.reachability = .unknown
        #expect(status.statusLabel == "Unknown")
    }

    // MARK: - Kubernetes Info

    @Test func kubernetesInfoShowsVersionForReachable() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.kubernetesVersion = "v1.30.1"
        #expect(status.kubernetesInfo == "Kubernetes v1.30.1")
    }

    @Test func kubernetesInfoShowsConnectedWhenNoVersion() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.kubernetesVersion = nil
        #expect(status.kubernetesInfo == "Kubernetes connected")
    }

    @Test func kubernetesInfoShowsUnreachable() {
        var status = ClusterStatus()
        status.reachability = .unreachable("timeout")
        #expect(status.kubernetesInfo == "Kubernetes unreachable")
    }

    @Test func kubernetesInfoShowsCheckingWithNoData() {
        var status = ClusterStatus()
        status.reachability = .checking
        #expect(status.kubernetesInfo == "Checking Kubernetes...")
    }

    @Test func kubernetesInfoShowsVersionWhileChecking() {
        var status = ClusterStatus()
        status.reachability = .checking
        status.kubernetesVersion = "v1.29.0"
        #expect(status.kubernetesInfo == "Kubernetes v1.29.0")
    }

    @Test func kubernetesInfoShowsUnknown() {
        var status = ClusterStatus()
        status.reachability = .unknown
        #expect(status.kubernetesInfo == "Kubernetes status unknown")
    }

    // MARK: - Flux Info

    @Test func fluxInfoShowsUnreachableWhenClusterUnreachable() {
        var status = ClusterStatus()
        status.reachability = .unreachable("timeout")
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        #expect(status.fluxInfo == "Flux Operator unreachable")
    }

    @Test func fluxInfoShowsNotInstalled() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .notInstalled
        #expect(status.fluxInfo == "Flux Operator not installed")
    }

    @Test func fluxInfoShowsCheckingWithNoData() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .checking
        #expect(status.fluxInfo == "Checking Flux Operator...")
    }

    @Test func fluxInfoShowsInstalledWhenNoSummary() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        status.fluxSummary = nil
        #expect(status.fluxInfo == "Flux Operator installed")
    }

    @Test func fluxInfoShowsBothVersions() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        status.fluxSummary = makeFluxSummary(distributionVersion: "v2.4.0", operatorVersion: "v0.14.0")
        #expect(status.fluxInfo == "Flux v2.4.0 · Operator v0.14.0")
    }

    @Test func fluxInfoShowsOnlyOperatorVersion() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        status.fluxSummary = makeFluxSummary(distributionVersion: "unknown", operatorVersion: "v0.14.0")
        #expect(status.fluxInfo == "Flux Operator v0.14.0")
    }

    @Test func fluxInfoShowsOnlyDistributionVersion() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        status.fluxSummary = makeFluxSummary(distributionVersion: "v2.4.0", operatorVersion: "unknown")
        #expect(status.fluxInfo == "Flux v2.4.0")
    }

    @Test func fluxInfoShowsInstalledWhenBothVersionsUnknown() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .installed(version: "v0.14.0", healthy: true)
        status.fluxSummary = makeFluxSummary(distributionVersion: "unknown", operatorVersion: "unknown")
        #expect(status.fluxInfo == "Flux Operator installed")
    }

    @Test func fluxInfoShowsVersionsWhileChecking() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .checking
        status.fluxSummary = makeFluxSummary(distributionVersion: "v2.4.0", operatorVersion: "v0.14.0")
        #expect(status.fluxInfo == "Flux v2.4.0 · Operator v0.14.0")
    }

    @Test func fluxInfoShowsUnknown() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxOperator = .unknown
        #expect(status.fluxInfo == "Flux Operator status unknown")
    }

    // MARK: - Node Properties

    @Test func nodeCountReturnsZeroForEmptyNodes() {
        let status = ClusterStatus()
        #expect(status.nodeCount == 0)
    }

    @Test func nodeCountReturnsCorrectCount() {
        var status = ClusterStatus()
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: true, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
            ClusterNode(id: "3", name: "node-3", isReady: false, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
        ]
        #expect(status.nodeCount == 3)
    }

    @Test func notReadyCountReturnsZeroWhenAllReady() {
        var status = ClusterStatus()
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: true, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
        ]
        #expect(status.notReadyCount == 0)
    }

    @Test func notReadyCountReturnsCorrectCount() {
        var status = ClusterStatus()
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: false, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
            ClusterNode(id: "3", name: "node-3", isReady: false, cpu: 4000, memory: 8 * 1024 * 1024 * 1024, pods: 110),
        ]
        #expect(status.notReadyCount == 2)
    }

    @Test func totalCPUSumsAllNodes() {
        var status = ClusterStatus()
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 1024, pods: 10),
            ClusterNode(id: "2", name: "node-2", isReady: true, cpu: 8000, memory: 1024, pods: 10),
        ]
        #expect(status.totalCPU == 12000)
    }

    @Test func totalMemorySumsAllNodes() {
        var status = ClusterStatus()
        let gi = Int64(1024 * 1024 * 1024)
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 8 * gi, pods: 10),
            ClusterNode(id: "2", name: "node-2", isReady: true, cpu: 4000, memory: 16 * gi, pods: 10),
        ]
        #expect(status.totalMemory == 24 * gi)
    }

    @Test func totalPodsSumsAllNodes() {
        var status = ClusterStatus()
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: true, cpu: 4000, memory: 1024, pods: 250),
        ]
        #expect(status.totalPods == 360)
    }

    // MARK: - Degraded Status with Not Ready Nodes

    @Test func statusLabelDegradedForNotReadyNodes() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: false, cpu: 4000, memory: 1024, pods: 110),
        ]
        #expect(status.statusLabel == "Degraded")
    }

    @Test func statusColorYellowForNotReadyNodes() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 1024, pods: 110),
            ClusterNode(id: "2", name: "node-2", isReady: false, cpu: 4000, memory: 1024, pods: 110),
        ]
        #expect(status.statusColor == .yellow)
    }

    @Test func isDegradedTrueForNotReadyNodes() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: false, cpu: 4000, memory: 1024, pods: 110),
        ]
        #expect(status.isDegraded == true)
    }

    @Test func isDegradedTrueForFluxFailures() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.fluxSummary = makeFluxSummary(failing: 2)
        #expect(status.isDegraded == true)
    }

    @Test func isDegradedFalseWhenHealthy() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodes = [
            ClusterNode(id: "1", name: "node-1", isReady: true, cpu: 4000, memory: 1024, pods: 110),
        ]
        status.fluxSummary = makeFluxSummary(failing: 0)
        #expect(status.isDegraded == false)
    }

    @Test func isDegradedFalseForZeroNodes() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodes = []
        #expect(status.isDegraded == false)
        #expect(status.statusLabel == "Healthy")
        #expect(status.statusColor == .green)
    }

    @Test func isDegradedTrueForNodeError() {
        var status = ClusterStatus()
        status.reachability = .reachable
        status.nodeError = "Failed to list nodes"
        #expect(status.isDegraded == true)
        #expect(status.statusLabel == "Degraded")
        #expect(status.statusColor == .yellow)
    }

    @Test func nodeErrorIsNilByDefault() {
        let status = ClusterStatus()
        #expect(status.nodeError == nil)
    }

    // MARK: - Test Helpers

    private func makeFluxSummary(
        distributionVersion: String = "v2.4.0",
        operatorVersion: String = "v0.14.0",
        failing: Int = 0
    ) -> FluxReportSummary {
        // Create a minimal FluxReportSpec to generate a summary
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: FluxDistribution(version: distributionVersion, status: "Installed", entitlement: nil, managedBy: nil),
            components: [],
            reconcilers: failing > 0 ? [
                FluxReconciler(
                    apiVersion: "kustomize.toolkit.fluxcd.io/v1",
                    kind: "Kustomization",
                    stats: FluxReconcilerStats(running: 5, failing: failing, suspended: 0, totalSize: nil)
                )
            ] : [],
            sync: nil,
            operator: FluxOperatorInfo(apiVersion: nil, version: operatorVersion, platform: nil)
        )
        return FluxReportSummary(from: spec)
    }
}
