// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public enum KSwitchError: LocalizedError, Sendable, Equatable {
    case kubectlNotFound
    case kubectlFailed(String)
    case fluxReportNotFound
    case timeout(TimeInterval)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .kubectlNotFound:
            return "kubectl not found. Check Settings to configure the path."
        case .kubectlFailed(let msg):
            return "kubectl error: \(msg)"
        case .fluxReportNotFound:
            return "FluxReport not found in cluster"
        case .timeout(let seconds):
            return "Command timed out after \(Int(seconds))s"
        case .decodingFailed(let msg):
            return "Failed to parse response: \(msg)"
        }
    }
}
