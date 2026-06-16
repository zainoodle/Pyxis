import AppKit
import Foundation

public struct ColorAnalysisResult: Equatable, Sendable {
    public let primaryColor: ClosetColor
    public let secondaryColors: [ClosetColor]
    public let confidence: Double

    public init(
        primaryColor: ClosetColor,
        secondaryColors: [ClosetColor] = [],
        confidence: Double
    ) {
        self.primaryColor = primaryColor
        self.secondaryColors = secondaryColors
        self.confidence = confidence
    }
}

public struct ColorAnalysisService: Sendable {
    public init() {}

    public func analyze(imageURL: URL) throws -> ColorAnalysisResult {
        guard let image = NSImage(contentsOf: imageURL),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ColorAnalysisError.couldNotLoadImage
        }

        var counts: [ClosetColor: Int] = [:]
        var visiblePixelCount = 0
        let sampleStride = max(1, min(bitmap.pixelsWide, bitmap.pixelsHigh) / 96)

        for y in stride(from: 0, to: bitmap.pixelsHigh, by: sampleStride) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: sampleStride) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.08 else {
                    continue
                }

                visiblePixelCount += 1
                counts[mapToClosetColor(color), default: 0] += 1
            }
        }

        guard visiblePixelCount > 0,
              let dominant = counts.max(by: { $0.value < $1.value }) else {
            return ColorAnalysisResult(primaryColor: .unknown, confidence: 0)
        }

        let secondary = counts
            .filter { $0.key != dominant.key }
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map(\.key)

        return ColorAnalysisResult(
            primaryColor: dominant.key,
            secondaryColors: Array(secondary),
            confidence: Double(dominant.value) / Double(visiblePixelCount)
        )
    }

    public func mapToClosetColor(_ color: NSColor) -> ClosetColor {
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let brightness = maxChannel
        let saturation = brightness == 0 ? 0 : (maxChannel - minChannel) / brightness

        if brightness < 0.12 { return .black }
        if saturation < 0.12 {
            if brightness > 0.88 { return .white }
            if brightness > 0.68 { return .cream }
            return .gray
        }

        if red > 0.75 && green > 0.58 && blue < 0.35 { return .yellow }
        if red > 0.75 && green > 0.32 && green < 0.68 && blue < 0.35 { return .orange }
        if red > 0.55 && green < 0.22 && blue < 0.28 { return .red }
        if red > 0.35 && red < 0.62 && green < 0.2 && blue < 0.25 { return .burgundy }
        if red > 0.65 && blue > 0.45 && green < 0.45 { return .pink }
        if red > 0.35 && blue > 0.45 && green < 0.35 { return .purple }
        if blue > 0.35 && red < 0.2 && green < 0.24 { return .navy }
        if blue > red && blue > green { return .blue }
        if green > red && green > blue {
            return red > 0.22 && blue < 0.28 ? .olive : .green
        }
        if red > 0.30 && green > 0.18 && blue < 0.18 {
            return brightness > 0.55 ? .tan : .brown
        }

        return .multicolor
    }
}

public enum ColorAnalysisError: LocalizedError {
    case couldNotLoadImage

    public var errorDescription: String? {
        "The image could not be loaded for color analysis."
    }
}
