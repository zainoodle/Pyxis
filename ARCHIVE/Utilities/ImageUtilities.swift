import AppKit
import CoreImage
import Foundation

public enum ImageUtilities {
    public static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    public static func jpegData(from image: NSImage, compression: CGFloat = 0.9) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
    }

    public static func thumbnailPNGData(
        from imageURL: URL,
        maxPixelSize: CGFloat = 420
    ) throws -> Data {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw ImageUtilityError.couldNotLoadImage
        }

        let thumbnail = thumbnail(from: image, maxPixelSize: maxPixelSize)
        guard let data = pngData(from: thumbnail) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
    }

    public static func thumbnail(from image: NSImage, maxPixelSize: CGFloat) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = min(maxPixelSize / originalSize.width, maxPixelSize / originalSize.height, 1)
        let targetSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1
        )
        thumbnail.unlockFocus()
        return thumbnail
    }
}

public enum ImageUtilityError: LocalizedError {
    case couldNotLoadImage
    case couldNotEncodePNG

    public var errorDescription: String? {
        switch self {
        case .couldNotLoadImage:
            return "The image could not be loaded."
        case .couldNotEncodePNG:
            return "The image could not be encoded as PNG."
        }
    }
}
