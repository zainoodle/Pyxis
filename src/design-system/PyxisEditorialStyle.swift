import SwiftUI

/// Decorative light stays behind controls so their labels remain crisp.
private struct EditorialGlow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let strength: Double

    func body(content: Content) -> some View {
        content.background {
            if colorScheme == .dark, contrast != .increased, !reduceTransparency {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.24 * strength), lineWidth: 2)
                    .blur(radius: 7)
                    .padding(-1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct EditorialCanvas: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            PyxisColors.background
                .overlay(alignment: .topLeading) {
                    if colorScheme == .dark, !reduceTransparency {
                        RadialGradient(
                            colors: [.white.opacity(0.055), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 260
                        )
                    }
                }
                .ignoresSafeArea()
        }
    }
}

extension View {
    func editorialGlow(cornerRadius: CGFloat = 10, strength: Double = 1) -> some View {
        modifier(EditorialGlow(cornerRadius: cornerRadius, strength: strength))
    }

    func editorialCanvas() -> some View {
        modifier(EditorialCanvas())
    }
}
