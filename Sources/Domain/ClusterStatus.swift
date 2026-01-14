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
        case installed(version: String, healthy: Bool)
        case degraded(version: String, failing: Int)
    }

    public var reachability: Reachability = .unknown
    public var kubernetesVersion: String?
    public var nodeCount: Int?
    public var fluxOperator: FluxOperatorState = .unknown
    public var fluxReport: FluxReportSpec?
    public var fluxSummary: FluxReportSummary?
    public var lastChecked: Date?

    public init() {}

    public var statusColor: StatusColor {
        switch reachability {
        case .unknown, .checking:
            return .gray
        case .unreachable:
            return .red
        case .reachable:
            if let summary = fluxSummary {
                return summary.statusColor
            }
            return .green
        }
    }
}

public enum StatusColor: Sendable {
    case green, yellow, red, gray
}
