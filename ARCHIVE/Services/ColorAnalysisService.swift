import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias ArchiveColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias ArchiveColor = NSColor
#endif

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
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ColorAnalysisError.couldNotLoadImage
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ColorAnalysisError.couldNotLoadImage
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var counts: [ClosetColor: Int] = [:]
        var visiblePixelCount = 0
        let sampleStride = max(1, min(width, height) / 96)

        for y in stride(from: 0, to: height, by: sampleStride) {
            for x in stride(from: 0, to: width, by: sampleStride) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard bytesPerPixel >= 4 else {
                    continue
                }

                let red = CGFloat(pixels[offset]) / 255
                let green = CGFloat(pixels[offset + 1]) / 255
                let blue = CGFloat(pixels[offset + 2]) / 255
                let alpha = CGFloat(pixels[offset + 3]) / 255
                guard alpha > 0.08 else { continue }

                visiblePixelCount += 1
                counts[mapToClosetColor(red: red, green: green, blue: blue), default: 0] += 1
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

    public func mapToClosetColor(_ color: ArchiveColor) -> ClosetColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return .unknown
        }
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        return mapToClosetColor(red: red, green: green, blue: blue)
    }

    public func mapToClosetColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> ClosetColor {
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
        if blue > red && blue > green && brightness < 0.32 { return .navy }
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
