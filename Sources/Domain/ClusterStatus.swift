// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public struct ClusterStatus: Sendable {
    public enum Reachability: Equatable, Sendable {
        case unknown
        case checking
        case reachable
        case unreachable(String)

        public static func == (lhs: Reachability, rhs: Reachability) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown), (.checking, .checking), (.reachable, .reachable):
                return true
            case (.unreachable(let lhsMsg), .unreachable(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }

    public enum FluxOperatorState: Equatable, Sendable {
        case unknown
        case checking
        case notInstalled
        case operatorOnly(version: String)
        case installed(version: String, healthy: Bool)
        case degraded(version: String, failing: Int)
    }

    public var reachability: Reachability = .unknown
    public var kubernetesVersion: String?
    public var nodes: [ClusterNode] = []
    public var nodeError: String?
    public var fluxOperator: FluxOperatorState = .unknown
    public var fluxReport: FluxReportSpec?
    public var fluxSummary: FluxReportSummary?
    public var fluxError: String?
    public var lastChecked: Date?

    public init() {}

    // MARK: - Node Computed Properties

    public var nodeCount: Int {
        nodes.count
    }

    public var notReadyCount: Int {
        nodes.filter { !$0.isReady }.count
    }

    public var totalCPU: Int {
        nodes.reduce(0) { $0 + $1.cpu }
    }

    public var totalMemory: Int64 {
        nodes.reduce(0) { $0 + $1.memory }
    }

    public var totalPods: Int {
        nodes.reduce(0) { $0 + $1.pods }
    }

    /// Returns true if any nodes are not ready
    public var hasNotReadyNodes: Bool {
        notReadyCount > 0
    }

    /// Returns true if cluster is degraded (Flux failures, not-ready nodes, or fetch errors)
    public var isDegraded: Bool {
        if let summary = fluxSummary, summary.totalFailing > 0 {
            return true
        }
        if nodeError != nil || fluxError != nil {
            return true
        }
        return hasNotReadyNodes
    }

    public var statusColor: StatusColor {
        switch reachability {
        case .unknown, .checking:
            // Show previous status color if we have data
            if kubernetesVersion != nil {
                return isDegraded ? .yellow : .green
            }
            return .gray
        case .unreachable:
            return .red
        case .reachable:
            return isDegraded ? .yellow : .green
        }
    }

    /// Status label for display: "Healthy", "Degraded", "Offline", "Checking", "Unknown"
    public var statusLabel: String {
        switch reachability {
        case .reachable:
            return isDegraded ? "Degraded" : "Healthy"
        case .unreachable:
            return "Offline"
        case .checking:
            // Show previous status if we have data
            if kubernetesVersion != nil {
                return isDegraded ? "Degraded" : "Healthy"
            }
            return "Checking"
        case .unknown:
            return "Unknown"
        }
    }

    /// Kubernetes info for display, e.g., "Kubernetes v1.30.1"
    public var kubernetesInfo: String {
        switch reachability {
        case .checking:
            if let version = kubernetesVersion {
                return "Kubernetes \(version)"
            }
            return "Checking Kubernetes..."
        case .reachable:
            if let version = kubernetesVersion {
                return "Kubernetes \(version)"
            }
            return "Kubernetes connected"
        case .unreachable:
            return "Kubernetes unreachable"
        case .unknown:
            return "Kubernetes status unknown"
        }
    }

    /// Flux info for display, e.g., "Flux v2.4.0 · Operator v0.14.0"
    public var fluxInfo: String {
        if case .unreachable = reachability {
            return "Flux Operator unreachable"
        }

        switch fluxOperator {
        case .checking:
            if let summary = fluxSummary {
                return formatFluxVersions(summary)
            }
            return "Checking Flux Operator..."
        case .installed, .degraded:
            if let summary = fluxSummary {
                return formatFluxVersions(summary)
            }
            return "Flux Operator installed"
        case .operatorOnly(let version):
            return "Flux N/A · Operator \(version)"
        case .notInstalled:
            return "Flux Operator not installed"
        case .unknown:
            return "Flux Operator status unknown"
        }
    }

    private func formatFluxVersions(_ summary: FluxReportSummary) -> String {
        let flux = summary.distributionVersion
        let op = summary.operatorVersion

        if flux != "unknown" && op != "unknown" {
            return "Flux \(flux) · Operator \(op)"
        } else if op != "unknown" {
            return "Flux Operator \(op)"
        } else if flux != "unknown" {
            return "Flux \(flux)"
        }
        return "Flux Operator installed"
    }
}

public enum StatusColor: Sendable {
    case green, yellow, red, gray
}
