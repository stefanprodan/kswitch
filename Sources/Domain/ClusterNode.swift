import Foundation

public struct ClusterNode: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let isReady: Bool
    public let cpu: Int        // millicores
    public let memory: Int64   // bytes
    public let pods: Int

    public init(id: String, name: String, isReady: Bool, cpu: Int, memory: Int64, pods: Int) {
        self.id = id
        self.name = name
        self.isReady = isReady
        self.cpu = cpu
        self.memory = memory
        self.pods = pods
    }
}

// MARK: - Resource Parsing

extension ClusterNode {
    /// Parses CPU value to millicores (e.g., "4" -> 4000, "250m" -> 250)
    public static func parseCPU(_ value: String) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("m") {
            let numStr = String(trimmed.dropLast())
            return Int(numStr) ?? 0
        }
        // Whole cores - convert to millicores
        if let cores = Int(trimmed) {
            return cores * 1000
        }
        // Handle decimal cores (e.g., "0.5" -> 500m)
        if let cores = Double(trimmed) {
            return Int(cores * 1000)
        }
        return 0
    }

    /// Parses memory value to bytes (e.g., "2Gi" -> 2147483648, "8192Mi" -> 8589934592)
    public static func parseMemory(_ value: String) -> Int64 {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Binary units (Ki, Mi, Gi, Ti)
        if trimmed.hasSuffix("Ki") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Int64(numStr) {
                return num * 1024
            }
        } else if trimmed.hasSuffix("Mi") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Int64(numStr) {
                return num * 1024 * 1024
            }
        } else if trimmed.hasSuffix("Gi") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Int64(numStr) {
                return num * 1024 * 1024 * 1024
            }
        } else if trimmed.hasSuffix("Ti") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Int64(numStr) {
                return num * 1024 * 1024 * 1024 * 1024
            }
        }

        // Decimal units (K, M, G, T) - SI units
        if trimmed.hasSuffix("K") {
            let numStr = String(trimmed.dropLast())
            if let num = Int64(numStr) {
                return num * 1000
            }
        } else if trimmed.hasSuffix("M") {
            let numStr = String(trimmed.dropLast())
            if let num = Int64(numStr) {
                return num * 1000 * 1000
            }
        } else if trimmed.hasSuffix("G") {
            let numStr = String(trimmed.dropLast())
            if let num = Int64(numStr) {
                return num * 1000 * 1000 * 1000
            }
        } else if trimmed.hasSuffix("T") {
            let numStr = String(trimmed.dropLast())
            if let num = Int64(numStr) {
                return num * 1000 * 1000 * 1000 * 1000
            }
        }

        // Plain bytes
        if let bytes = Int64(trimmed) {
            return bytes
        }

        return 0
    }
}

// MARK: - Formatting

extension ClusterNode {
    /// Formats CPU millicores for display (e.g., 4000 -> "4 cores", 250 -> "250m")
    public static func formatCPU(_ millicores: Int) -> String {
        if millicores >= 1000 && millicores % 1000 == 0 {
            let cores = millicores / 1000
            return "\(cores) \(cores == 1 ? "core" : "cores")"
        }
        return "\(millicores)m"
    }

    /// Formats memory bytes for display (e.g., 2Gi, 512Mi)
    public static func formatMemory(_ bytes: Int64) -> String {
        let gi = Int64(1024 * 1024 * 1024)
        let mi = Int64(1024 * 1024)

        if bytes >= gi {
            let value = bytes / gi
            return "\(value)Gi"
        } else if bytes >= mi {
            let value = bytes / mi
            return "\(value)Mi"
        } else {
            return "\(bytes)B"
        }
    }
}
