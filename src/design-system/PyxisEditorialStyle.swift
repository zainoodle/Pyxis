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
                    .stroke(Color.white.opacity(0.045 * strength), lineWidth: 1)
                    .blur(radius: 4)
                    .padding(-1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct EditorialCanvas: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            PyxisColors.background
                .overlay {
                    if contrast != .increased, !reduceTransparency {
                        RadialGradient(
                            colors: [PyxisColors.surface.opacity(colorScheme == .dark ? 0.8 : 0.95), .clear],
                            center: UnitPoint(x: 0.36, y: 0.22),
                            startRadius: 0,
                            endRadius: 370
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
