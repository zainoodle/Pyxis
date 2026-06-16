import CoreImage
import Foundation
import UIKit

public enum ImageUtilities {
    public static func pngData(from image: UIImage) -> Data? {
        image.pngData()
    }

    public static func jpegData(from image: UIImage, compression: CGFloat = 0.9) -> Data? {
        image.jpegData(compressionQuality: compression)
    }

    public static func thumbnailPNGData(
        from imageURL: URL,
        maxPixelSize: CGFloat = 420
    ) throws -> Data {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw ImageUtilityError.couldNotLoadImage
        }

        let thumbnail = thumbnail(from: image, maxPixelSize: maxPixelSize)
        guard let data = pngData(from: thumbnail) else {
            throw ImageUtilityError.couldNotEncodePNG
        }
        return data
    }

    public static func thumbnail(from image: UIImage, maxPixelSize: CGFloat) -> UIImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = min(maxPixelSize / originalSize.width, maxPixelSize / originalSize.height, 1)
        let targetSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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
