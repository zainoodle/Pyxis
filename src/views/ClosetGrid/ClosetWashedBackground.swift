import SwiftUI

/// Washed charcoal backdrop with cloudy tonal variation and matte grain,
/// rendered from a baked texture so it costs nothing per frame.
struct ClosetWashedBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        PyxisColors.background.overlay {
            if colorScheme == .dark, contrast != .increased {
                GeometryReader { geometry in
                    Image("ClosetWash")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.65)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
