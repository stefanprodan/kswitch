// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Kubernetes List Response

public struct FluxReportList: Codable, Sendable {
    public let items: [FluxReportResource]
}

// MARK: - Top-level Kubernetes Resource

public struct FluxReportResource: Codable, Sendable {
    public let apiVersion: String
    public let kind: String
    public let metadata: FluxReportMetadata
    public let spec: FluxReportSpec
}

public struct FluxReportMetadata: Codable, Sendable {
    public let name: String
    public let namespace: String
}

// MARK: - FluxReport Spec (actual data)

public struct FluxReportSpec: Codable, Sendable {
    public let cluster: FluxClusterInfo?
    public let distribution: FluxDistribution?
    public let components: [FluxComponent]?
    public let reconcilers: [FluxReconciler]?
    public let sync: FluxSync?
    public let `operator`: FluxOperatorInfo?
}

// MARK: - Cluster Info

public struct FluxClusterInfo: Codable, Sendable {
    public let platform: String?
    public let serverVersion: String?
    public let nodes: Int?
}

// MARK: - Distribution

public struct FluxDistribution: Codable, Sendable {
    public let version: String?
    public let status: String?
    public let entitlement: String?
    public let managedBy: String?
}

// MARK: - Components (Controllers)

public struct FluxComponent: Codable, Sendable {
    public let name: String
    public let image: String?
    public let ready: Bool
    public let status: String?
}

// MARK: - Reconcilers (Resource Stats)

public struct FluxReconciler: Codable, Sendable {
    public let apiVersion: String
    public let kind: String
    public let stats: FluxReconcilerStats
}

public struct FluxReconcilerStats: Codable, Sendable {
    public let running: Int
    public let failing: Int
    public let suspended: Int
    public let totalSize: String?
}

// MARK: - Sync Status

public struct FluxSync: Codable, Sendable {
    public let ready: Bool
    public let id: String?
    public let path: String?
    public let source: String?
    public let status: String?
}

// MARK: - Operator Info

public struct FluxOperatorInfo: Codable, Sendable {
    public let apiVersion: String?
    public let version: String?
    public let platform: String?
}

// MARK: - Computed Summary for UI

public struct FluxReportSummary: Sendable {
    public let distributionVersion: String
    public let operatorVersion: String
    public let isDistributionInstalled: Bool
    public let syncReady: Bool
    public let syncPath: String?
    public let totalRunning: Int
    public let totalFailing: Int
    public let totalSuspended: Int
    public let componentsReady: Int
    public let componentsTotal: Int

    public init(from spec: FluxReportSpec) {
        self.distributionVersion = spec.distribution?.version ?? "unknown"
        self.operatorVersion = spec.operator?.version ?? "unknown"
        self.isDistributionInstalled = spec.distribution?.status == "Installed"
        self.syncReady = spec.sync?.ready ?? false
        self.syncPath = spec.sync?.path

        self.totalRunning = spec.reconcilers?.reduce(0) { $0 + $1.stats.running } ?? 0
        self.totalFailing = spec.reconcilers?.reduce(0) { $0 + $1.stats.failing } ?? 0
        self.totalSuspended = spec.reconcilers?.reduce(0) { $0 + $1.stats.suspended } ?? 0

        self.componentsReady = spec.components?.filter { $0.ready }.count ?? 0
        self.componentsTotal = spec.components?.count ?? 0
    }

    public var isHealthy: Bool {
        totalFailing == 0 && componentsReady == componentsTotal
    }

    public var statusColor: StatusColor {
        if totalFailing > 0 || componentsReady < componentsTotal { return .red }
        // Suspended resources are intentionally paused, not a warning
        return .green
    }
}
