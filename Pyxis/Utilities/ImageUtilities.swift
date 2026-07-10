import CoreImage
import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias PyxisImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PyxisImage = NSImage
#endif

public enum ImageUtilities {
    public enum RotationDirection: Sendable {
        case counterclockwise
        case clockwise
    }

    public static func pngData(from image: PyxisImage) -> Data? {
        #if canImport(UIKit)
        image.pngData()
        #elseif canImport(AppKit)
        bitmapRepresentation(from: image)?.representation(using: .png, properties: [:])
        #endif
    }

    public static func jpegData(from image: PyxisImage, compression: CGFloat = 0.9) -> Data? {
        #if canImport(UIKit)
        image.jpegData(compressionQuality: compression)
        #elseif canImport(AppKit)
        bitmapRepresentation(from: image)?.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
        #endif
    }

    public static func rotatedImageData(
        from imageURL: URL,
        direction: RotationDirection
    ) throws -> Data {
        guard let image = PyxisImage(contentsOfFile: imageURL.path) else {
            throw ImageUtilityError.couldNotLoadImage
        }

        #if canImport(UIKit)
        let radians: CGFloat = direction == .clockwise ? .pi / 2 : -.pi / 2
        let originalSize = image.size
        let targetSize = CGSize(width: originalSize.height, height: originalSize.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let rotated = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            cgContext.rotate(by: radians)
            image.draw(
                in: CGRect(
                    x: -originalSize.width / 2,
                    y: -originalSize.height / 2,
                    width: originalSize.width,
                    height: originalSize.height
                )
            )
        }

        if imageURL.prefersJPEGEncoding, let data = jpegData(from: rotated) {
            return data
        }
        guard let data = pngData(from: rotated) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
        #elseif canImport(AppKit)
        let originalSize = image.size
        let targetSize = CGSize(width: originalSize.height, height: originalSize.width)
        let rotated = NSImage(size: targetSize)
        rotated.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            rotated.unlockFocus()
            throw ImageUtilityError.couldNotLoadImage
        }
        context.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
        context.rotate(by: direction == .clockwise ? .pi / 2 : -.pi / 2)
        image.draw(
            in: CGRect(
                x: -originalSize.width / 2,
                y: -originalSize.height / 2,
                width: originalSize.width,
                height: originalSize.height
            )
        )
        rotated.unlockFocus()

        if imageURL.prefersJPEGEncoding, let data = jpegData(from: rotated) {
            return data
        }
        guard let data = pngData(from: rotated) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
        #endif
    }

    public static func thumbnailPNGData(
        from imageURL: URL,
        maxPixelSize: CGFloat = 420
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCache: false,
                    kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
                ] as CFDictionary
              ) else {
            throw ImageUtilityError.couldNotLoadImage
        }

        #if canImport(UIKit)
        let thumbnail = PyxisImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        let thumbnail = PyxisImage(cgImage: cgImage, size: .zero)
        #endif

        guard let data = pngData(from: thumbnail) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
    }

    public static func thumbnail(from image: PyxisImage, maxPixelSize: CGFloat) -> PyxisImage {
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

private extension URL {
    var prefersJPEGEncoding: Bool {
        let jpegExtensions: Set<String> = ["jpg", "jpeg"]
        return jpegExtensions.contains(pathExtension.lowercased())
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
