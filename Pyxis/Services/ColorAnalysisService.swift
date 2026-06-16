import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias PyxisColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PyxisColor = NSColor
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

    public func colorHint(filename: String?) -> ColorAnalysisResult? {
        let tokens = normalizedTokens(from: filename)

        let colorRules: [(tokens: [String], color: ClosetColor)] = [
            (["off white", "offwhite", "ivory", "cream", "ecru"], .cream),
            (["burgundy", "maroon", "wine"], .burgundy),
            (["multicolor", "multi color", "multi", "print", "pattern"], .multicolor),
            (["black"], .black),
            (["white"], .white),
            (["grey", "gray", "charcoal", "silver"], .gray),
            (["brown", "espresso", "chocolate"], .brown),
            (["tan", "khaki", "beige", "sand", "stone"], .tan),
            (["navy"], .navy),
            (["blue"], .blue),
            (["green"], .green),
            (["olive", "army"], .olive),
            (["red"], .red),
            (["pink"], .pink),
            (["purple", "violet"], .purple),
            (["yellow", "gold"], .yellow),
            (["orange"], .orange)
        ]

        for rule in colorRules {
            if rule.tokens.contains(where: { matches($0, in: tokens) }) {
                return ColorAnalysisResult(
                    primaryColor: rule.color,
                    confidence: 0.42
                )
            }
        }

        return nil
    }

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
              let dominant = sortedCounts(counts).first else {
            return ColorAnalysisResult(primaryColor: .unknown, confidence: 0)
        }

        let selected = selectedPrimaryColor(from: counts, dominant: dominant, visiblePixelCount: visiblePixelCount)
        let secondary = sortedCounts(counts)
            .filter { $0.key != selected.key }
            .filter { !isPlainBackgroundColor($0.key) || selected.key == dominant.key }
            .prefix(2)
            .map(\.key)

        return ColorAnalysisResult(
            primaryColor: selected.key,
            secondaryColors: Array(secondary),
            confidence: Double(selected.value) / Double(visiblePixelCount)
        )
    }

    public func mapToClosetColor(_ color: PyxisColor) -> ClosetColor {
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

    private func selectedPrimaryColor(
        from counts: [ClosetColor: Int],
        dominant: (key: ClosetColor, value: Int),
        visiblePixelCount: Int
    ) -> (key: ClosetColor, value: Int) {
        guard isPlainBackgroundColor(dominant.key),
              let strongestGarmentCandidate = sortedCounts(counts)
                .first(where: { !isPlainBackgroundColor($0.key) })
        else {
            return dominant
        }

        let garmentShare = Double(strongestGarmentCandidate.value) / Double(visiblePixelCount)
        return garmentShare >= 0.18 ? strongestGarmentCandidate : dominant
    }

    private func sortedCounts(_ counts: [ClosetColor: Int]) -> [(key: ClosetColor, value: Int)] {
        counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key.rawValue < rhs.key.rawValue
        }
    }

    private func isPlainBackgroundColor(_ color: ClosetColor) -> Bool {
        switch color {
        case .white, .cream, .gray:
            return true
        default:
            return false
        }
    }

    private func normalizedTokens(from filename: String?) -> [String] {
        let stem = URL(fileURLWithPath: filename ?? "").deletingPathExtension().lastPathComponent
        let normalized = stem
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : " "
            }

        return String(normalized)
            .split(separator: " ")
            .map(String.init)
    }

    private func matches(_ tokenPattern: String, in tokens: [String]) -> Bool {
        let patternTokens = normalizedTokens(from: tokenPattern)

        guard !patternTokens.isEmpty else {
            return false
        }

        if patternTokens.count == 1 {
            return tokens.contains(patternTokens[0])
        }

        guard tokens.count >= patternTokens.count else {
            return false
        }

        for startIndex in 0...(tokens.count - patternTokens.count) {
            let endIndex = startIndex + patternTokens.count
            if Array(tokens[startIndex..<endIndex]) == patternTokens {
                return true
            }
        }

        return false
    }
}

public enum ColorAnalysisError: LocalizedError {
    case couldNotLoadImage

    public var errorDescription: String? {
        "The image could not be loaded for color analysis."
    }
}
