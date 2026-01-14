import Foundation

public struct Cluster: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let contextName: String
    public var displayName: String?
    public var colorHex: String
    public var isHidden: Bool
    public var sortOrder: Int
    public var isFavorite: Bool
    public var isInKubeconfig: Bool

    public var effectiveName: String {
        displayName ?? contextName
    }

    public var truncatedName: String {
        let name = effectiveName
        if name.count > 30 {
            return String(name.prefix(27)) + "..."
        }
        return name
    }

    public init(contextName: String) {
        self.id = UUID()
        self.contextName = contextName
        self.displayName = nil
        self.colorHex = Self.defaultColors.randomElement()!
        self.isHidden = false
        self.sortOrder = 0
        self.isFavorite = false
        self.isInKubeconfig = true
    }

    public static let defaultColors = [
        "#3B82F6", // Blue
        "#10B981", // Green
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#8B5CF6", // Purple
        "#EC4899", // Pink
        "#06B6D4", // Cyan
        "#F97316", // Orange
    ]
}
