// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Testing
import Foundation
@testable import Domain

@Suite struct FluxReportSummaryTests {

    // MARK: - Initialization from FluxReportSpec

    @Test func initExtractsDistributionVersion() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: FluxDistribution(version: "v2.3.0", status: "Installed", entitlement: nil, managedBy: nil),
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.distributionVersion == "v2.3.0")
    }

    @Test func initUsesUnknownForMissingDistributionVersion() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.distributionVersion == "unknown")
    }

    @Test func initExtractsOperatorVersion() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: FluxOperatorInfo(apiVersion: "v1", version: "v1.0.0", platform: "linux/amd64")
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.operatorVersion == "v1.0.0")
    }

    @Test func initUsesUnknownForMissingOperatorVersion() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.operatorVersion == "unknown")
    }

    @Test func initAggregatesReconcilerStats() {
        let reconcilers = [
            FluxReconciler(
                apiVersion: "source.toolkit.fluxcd.io/v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 1, suspended: 2, totalSize: nil)
            ),
            FluxReconciler(
                apiVersion: "kustomize.toolkit.fluxcd.io/v1",
                kind: "Kustomization",
                stats: FluxReconcilerStats(running: 10, failing: 2, suspended: 3, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.totalRunning == 15)
        #expect(summary.totalFailing == 3)
        #expect(summary.totalSuspended == 5)
    }

    @Test func initCountsComponentsReady() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: "Running"),
            FluxComponent(name: "kustomize-controller", image: nil, ready: true, status: "Running"),
            FluxComponent(name: "helm-controller", image: nil, ready: false, status: "Pending"),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.componentsReady == 2)
        #expect(summary.componentsTotal == 3)
    }

    @Test func initHandlesNilReconcilers() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.totalRunning == 0)
        #expect(summary.totalFailing == 0)
        #expect(summary.totalSuspended == 0)
    }

    @Test func initHandlesNilComponents() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.componentsReady == 0)
        #expect(summary.componentsTotal == 0)
    }

    @Test func initExtractsSyncStatus() {
        let sync = FluxSync(ready: true, id: "main@sha1:abc123", path: "./clusters/production", source: "git", status: "Applied")

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: sync,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.syncReady == true)
        #expect(summary.syncPath == "./clusters/production")
    }

    @Test func initHandlesNilSync() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.syncReady == false)
        #expect(summary.syncPath == nil)
    }

    @Test func initDetectsDistributionInstalled() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: FluxDistribution(version: "v2.3.0", status: "Installed", entitlement: nil, managedBy: nil),
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isDistributionInstalled == true)
    }

    @Test func initDetectsDistributionNotInstalled() {
        let spec = FluxReportSpec(
            cluster: nil,
            distribution: FluxDistribution(version: nil, status: "NotInstalled", entitlement: nil, managedBy: nil),
            components: nil,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isDistributionInstalled == false)
    }

    // MARK: - isHealthy property

    @Test func isHealthyTrueWhenNoFailuresAndAllReady() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
            FluxComponent(name: "kustomize-controller", image: nil, ready: true, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 0, suspended: 0, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isHealthy == true)
    }

    @Test func isHealthyFalseWhenReconcilersFailing() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 2, suspended: 0, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isHealthy == false)
    }

    @Test func isHealthyFalseWhenComponentsNotAllReady() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
            FluxComponent(name: "kustomize-controller", image: nil, ready: false, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 0, suspended: 0, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isHealthy == false)
    }

    @Test func isHealthyTrueWithSuspendedResources() {
        // Suspended resources are intentionally paused, not unhealthy
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 3, failing: 0, suspended: 2, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.isHealthy == true)
    }

    // MARK: - statusColor property

    @Test func statusColorGreenWhenHealthy() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 0, suspended: 0, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.statusColor == .green)
    }

    @Test func statusColorRedWhenFailing() {
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 5, failing: 1, suspended: 0, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: nil,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.statusColor == .red)
    }

    @Test func statusColorRedWhenComponentsNotReady() {
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
            FluxComponent(name: "kustomize-controller", image: nil, ready: false, status: nil),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: nil,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.statusColor == .red)
    }

    @Test func statusColorGreenWithSuspendedResources() {
        // Suspended resources don't cause yellow - they're intentionally paused
        let components = [
            FluxComponent(name: "source-controller", image: nil, ready: true, status: nil),
        ]
        let reconcilers = [
            FluxReconciler(
                apiVersion: "v1",
                kind: "GitRepository",
                stats: FluxReconcilerStats(running: 3, failing: 0, suspended: 5, totalSize: nil)
            ),
        ]

        let spec = FluxReportSpec(
            cluster: nil,
            distribution: nil,
            components: components,
            reconcilers: reconcilers,
            sync: nil,
            operator: nil
        )

        let summary = FluxReportSummary(from: spec)

        #expect(summary.statusColor == .green)
    }
}
