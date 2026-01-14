import SwiftUI
import Domain
import Infrastructure

struct ClusterCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colorScheme == .dark
                        ? Color.white.opacity(0.2)
                        : Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func clusterCard(cornerRadius: CGFloat = 12, padding: CGFloat = 12) -> some View {
        modifier(ClusterCard(cornerRadius: cornerRadius, padding: padding))
    }
}
