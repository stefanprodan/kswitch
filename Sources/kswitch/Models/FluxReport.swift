import Foundation

// MARK: - Kubernetes List Response

struct FluxReportList: Codable {
    let items: [FluxReportResource]
}

// MARK: - Top-level Kubernetes Resource

struct FluxReportResource: Codable {
    let apiVersion: String
    let kind: String
    let metadata: FluxReportMetadata
    let spec: FluxReportSpec
}

struct FluxReportMetadata: Codable {
    let name: String
    let namespace: String
}

// MARK: - FluxReport Spec (actual data)

struct FluxReportSpec: Codable {
    let cluster: FluxClusterInfo?
    let distribution: FluxDistribution?
    let components: [FluxComponent]?
    let reconcilers: [FluxReconciler]?
    let sync: FluxSync?
    let `operator`: FluxOperatorInfo?
}

// MARK: - Cluster Info

struct FluxClusterInfo: Codable {
    let platform: String?
    let serverVersion: String?
    let nodes: Int?
}

// MARK: - Distribution

struct FluxDistribution: Codable {
    let version: String?
    let status: String?
    let entitlement: String?
    let managedBy: String?
}

// MARK: - Components (Controllers)

struct FluxComponent: Codable {
    let name: String
    let image: String?
    let ready: Bool
    let status: String?
}

// MARK: - Reconcilers (Resource Stats)

struct FluxReconciler: Codable {
    let apiVersion: String
    let kind: String
    let stats: FluxReconcilerStats
}

struct FluxReconcilerStats: Codable {
    let running: Int
    let failing: Int
    let suspended: Int
    let totalSize: String?
}

// MARK: - Sync Status

struct FluxSync: Codable {
    let ready: Bool
    let id: String?
    let path: String?
    let source: String?
    let status: String?
}

// MARK: - Operator Info

struct FluxOperatorInfo: Codable {
    let apiVersion: String?
    let version: String?
    let platform: String?
}

// MARK: - Computed Summary for UI

struct FluxReportSummary {
    let distributionVersion: String
    let operatorVersion: String
    let isInstalled: Bool
    let syncReady: Bool
    let syncPath: String?
    let totalRunning: Int
    let totalFailing: Int
    let totalSuspended: Int
    let componentsReady: Int
    let componentsTotal: Int

    init(from spec: FluxReportSpec) {
        self.distributionVersion = spec.distribution?.version ?? "unknown"
        self.operatorVersion = spec.operator?.version ?? "unknown"
        self.isInstalled = spec.distribution?.status == "Installed"
        self.syncReady = spec.sync?.ready ?? false
        self.syncPath = spec.sync?.path

        self.totalRunning = spec.reconcilers?.reduce(0) { $0 + $1.stats.running } ?? 0
        self.totalFailing = spec.reconcilers?.reduce(0) { $0 + $1.stats.failing } ?? 0
        self.totalSuspended = spec.reconcilers?.reduce(0) { $0 + $1.stats.suspended } ?? 0

        self.componentsReady = spec.components?.filter { $0.ready }.count ?? 0
        self.componentsTotal = spec.components?.count ?? 0
    }

    var isHealthy: Bool {
        totalFailing == 0 && componentsReady == componentsTotal
    }

    var statusColor: StatusColor {
        if totalFailing > 0 || componentsReady < componentsTotal { return .red }
        // Suspended resources are intentionally paused, not a warning
        return .green
    }
}
