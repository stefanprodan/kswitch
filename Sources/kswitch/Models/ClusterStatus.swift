import Foundation

struct ClusterStatus {
    enum Reachability: Equatable {
        case unknown
        case checking
        case reachable
        case unreachable(String)

        static func == (lhs: Reachability, rhs: Reachability) -> Bool {
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

    enum FluxOperatorState: Equatable {
        case unknown
        case checking
        case notInstalled
        case installed(version: String, healthy: Bool)
        case degraded(version: String, failing: Int)
    }

    var reachability: Reachability = .unknown
    var kubernetesVersion: String?
    var nodeCount: Int?
    var fluxOperator: FluxOperatorState = .unknown
    var fluxReport: FluxReportSpec?
    var fluxSummary: FluxReportSummary?
    var lastChecked: Date?

    var statusColor: StatusColor {
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

enum StatusColor {
    case green, yellow, red, gray
}
