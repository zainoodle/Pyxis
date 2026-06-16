import CoreImage
import Foundation

#if canImport(UIKit)
import UIKit
public typealias ArchiveImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias ArchiveImage = NSImage
#endif

public enum ImageUtilities {
    public static func pngData(from image: ArchiveImage) -> Data? {
        #if canImport(UIKit)
        image.pngData()
        #elseif canImport(AppKit)
        bitmapRepresentation(from: image)?.representation(using: .png, properties: [:])
        #endif
    }

    public static func jpegData(from image: ArchiveImage, compression: CGFloat = 0.9) -> Data? {
        #if canImport(UIKit)
        image.jpegData(compressionQuality: compression)
        #elseif canImport(AppKit)
        bitmapRepresentation(from: image)?.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
        #endif
    }

    public static func thumbnailPNGData(
        from imageURL: URL,
        maxPixelSize: CGFloat = 420
    ) throws -> Data {
        guard let image = ArchiveImage(contentsOfFile: imageURL.path) else {
            throw ImageUtilityError.couldNotLoadImage
        }

        let thumbnail = thumbnail(from: image, maxPixelSize: maxPixelSize)
        guard let data = pngData(from: thumbnail) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
    }

    public static func thumbnail(from image: ArchiveImage, maxPixelSize: CGFloat) -> ArchiveImage {
        #if canImport(UIKit)
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = min(maxPixelSize / originalSize.width, maxPixelSize / originalSize.height, 1)
        let targetSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        #elseif canImport(AppKit)
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = min(maxPixelSize / originalSize.width, maxPixelSize / originalSize.height, 1)
        let targetSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        thumbnail.unlockFocus()
        return thumbnail
        #endif
    }

    #if canImport(AppKit) && !canImport(UIKit)
    private static func bitmapRepresentation(from image: NSImage) -> NSBitmapImageRep? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap
    }
    #endif
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
