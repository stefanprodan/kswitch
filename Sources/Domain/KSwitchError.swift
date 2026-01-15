// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public enum KSwitchError: LocalizedError, Sendable {
    case kubectlNotFound
    case kubectlFailed(String)
    case fluxReportNotFound
    case clusterUnreachable
    case timeout
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .kubectlNotFound:
            return "kubectl not found. Check Settings to configure the path."
        case .kubectlFailed(let msg):
            return "kubectl error: \(msg)"
        case .fluxReportNotFound:
            return "FluxReport not found in cluster"
        case .clusterUnreachable:
            return "Cluster is not reachable"
        case .timeout:
            return "Command timed out"
        case .invalidResponse(let msg):
            return "Invalid response: \(msg)"
        }
    }
}
