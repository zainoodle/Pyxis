import SwiftUI

/// A shared, softly lit photographic surface for garment review in either appearance.
struct GarmentStageBackground: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        PyxisColors.imageCanvas
            .overlay {
                if contrast != .increased, !reduceTransparency {
                    GeometryReader { geometry in
                        RadialGradient(
                            colors: [PyxisColors.stageLight, PyxisColors.imageCanvas, PyxisColors.stageEdge],
                            center: UnitPoint(x: 0.42, y: 0.28),
                            startRadius: 0,
                            endRadius: max(geometry.size.width, geometry.size.height) * 0.82
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct GarmentStage: View {
    let url: URL?
    var revision = 0

    var body: some View {
        LocalImageView(url: url, revision: revision, balancedFraming: true, castsShadow: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .garmentSurface()
    }
}

/// One photographic treatment across closet pieces and composed outfits.
private struct GarmentSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { GarmentStageBackground() }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PyxisColors.hairline.opacity(0.45), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func garmentSurface() -> some View { modifier(GarmentSurface()) }
}
