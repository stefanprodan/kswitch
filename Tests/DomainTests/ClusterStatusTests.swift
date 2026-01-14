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
        #expect(status.nodeCount == nil)
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
}
