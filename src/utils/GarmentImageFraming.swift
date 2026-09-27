import CoreGraphics
import CoreImage
import Foundation

struct GarmentImageFramingAnalysis {
    let visibleRect: CGRect
    let frameRect: CGRect
    let visibleFraction: Double
    let fillFraction: Double
    let touchingEdgeCount: Int
}

/// Frames the pixels that remain after background removal without changing the original photo.
enum GarmentImageFraming {
    private static let sampleLimit = 384
    private static let alphaThreshold: UInt8 = 12
    private static let paddingFraction: CGFloat = 0.08

    static func analyze(_ image: CIImage, using context: CIContext) -> GarmentImageFramingAnalysis? {
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return nil }

        let scale = min(1, CGFloat(sampleLimit) / max(extent.width, extent.height))
        let sampleWidth = max(1, Int((extent.width * scale).rounded(.up)))
        let sampleHeight = max(1, Int((extent.height * scale).rounded(.up)))
        let sampleBounds = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        let sampledImage = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        context.render(
            sampledImage,
            toBitmap: &pixels,
            rowBytes: sampleWidth * 4,
            bounds: sampleBounds,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var minX = sampleWidth
        var minY = sampleHeight
        var maxX = -1
        var maxY = -1
        var visibleCount = 0
        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let alpha = pixels[(y * sampleWidth + x) * 4 + 3]
                guard alpha > alphaThreshold else { continue }
                visibleCount += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard visibleCount > 0 else { return nil }

        let visibleRect = CGRect(
            x: extent.minX + CGFloat(minX) / scale,
            y: extent.minY + CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        ).intersection(extent)
        let frameRect = visibleRect.insetBy(
            dx: -visibleRect.width * paddingFraction,
            dy: -visibleRect.height * paddingFraction
        ).intersection(extent).integral
        let touchingEdgeCount = [
            minX == 0,
            maxX == sampleWidth - 1,
            minY == 0,
            maxY == sampleHeight - 1
        ].filter { $0 }.count

        return GarmentImageFramingAnalysis(
            visibleRect: visibleRect,
            frameRect: frameRect,
            visibleFraction: Double(visibleCount) / Double(sampleWidth * sampleHeight),
            fillFraction: Double(visibleCount) / Double((maxX - minX + 1) * (maxY - minY + 1)),
            touchingEdgeCount: touchingEdgeCount
        )
    }

    static func acceptsAutomaticCutout(_ analysis: GarmentImageFramingAnalysis) -> Bool {
        analysis.visibleFraction >= 0.005
            && analysis.visibleFraction <= 0.82
            && analysis.fillFraction >= 0.08
            && analysis.touchingEdgeCount < 3
    }

    static func framedDisplayImage(_ image: CGImage, using context: CIContext) -> CGImage {
        let source = CIImage(cgImage: image)
        guard let analysis = analyze(source, using: context),
              analysis.frameRect.width < source.extent.width
                || analysis.frameRect.height < source.extent.height else { return image }
        return context.createCGImage(source, from: analysis.frameRect) ?? image
    }
}
