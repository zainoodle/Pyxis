import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

public enum BackgroundRemovalStatus: Equatable, Sendable {
    case succeeded
    case failed
}

public struct BackgroundRemovalResult: Equatable, Sendable {
    public let originalPath: String
    public let cutoutPath: String?
    public let thumbnailPath: String?
    public let status: BackgroundRemovalStatus
    public let errorMessage: String?

    public init(
        originalPath: String,
        cutoutPath: String?,
        thumbnailPath: String?,
        status: BackgroundRemovalStatus,
        errorMessage: String? = nil
    ) {
        self.originalPath = originalPath
        self.cutoutPath = cutoutPath
        self.thumbnailPath = thumbnailPath
        self.status = status
        self.errorMessage = errorMessage
    }
}

public protocol BackgroundRemovalServiceProtocol {
    func processImage(at originalURL: URL, itemID: UUID) async -> BackgroundRemovalResult
}

public final class LocalBackgroundRemovalService: BackgroundRemovalServiceProtocol {
    private let imageStorage: ImageStorageService
    private let ciContext: CIContext

    public init(
        imageStorage: ImageStorageService,
        ciContext: CIContext = CIContext()
    ) {
        self.imageStorage = imageStorage
        self.ciContext = ciContext
    }

    public func processImage(at originalURL: URL, itemID: UUID) async -> BackgroundRemovalResult {
        await Task.detached(priority: .userInitiated) { [imageStorage, ciContext] in
            do {
                let originalPath = try imageStorage.saveOriginal(from: originalURL, itemID: itemID)
                let originalStoredURL = imageStorage.url(for: originalPath)
                let thumbnailPath = try? imageStorage.makeThumbnail(from: originalStoredURL, itemID: itemID)

                do {
                    let cutoutData = try Self.makeTransparentCutoutPNG(
                        from: originalStoredURL,
                        ciContext: ciContext
                    )
                    let cutoutPath = try imageStorage.saveCutoutPNG(cutoutData, itemID: itemID)
                    let thumbnailFromCutout = try? imageStorage.makeThumbnail(
                        from: imageStorage.url(for: cutoutPath),
                        itemID: itemID
                    )

                    return BackgroundRemovalResult(
                        originalPath: originalPath,
                        cutoutPath: cutoutPath,
                        thumbnailPath: thumbnailFromCutout ?? thumbnailPath,
                        status: .succeeded
                    )
                } catch {
                    return BackgroundRemovalResult(
                        originalPath: originalPath,
                        cutoutPath: nil,
                        thumbnailPath: thumbnailPath,
                        status: .failed,
                        errorMessage: "Background removal failed — retry"
                    )
                }
            } catch {
                return BackgroundRemovalResult(
                    originalPath: "",
                    cutoutPath: nil,
                    thumbnailPath: nil,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
            }
        }.value
    }

    private static func makeTransparentCutoutPNG(
        from imageURL: URL,
        ciContext: CIContext
    ) throws -> Data {
        guard let inputImage = CIImage(contentsOf: imageURL) else {
            throw BackgroundRemovalError.couldNotLoadImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw BackgroundRemovalError.noForegroundMask
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let transparentBackground = CIImage(color: .clear).cropped(to: inputImage.extent)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = inputImage
        filter.backgroundImage = transparentBackground
        filter.maskImage = maskImage

        guard let output = filter.outputImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let data = ciContext.pngRepresentation(
                of: output,
                format: .RGBA8,
                colorSpace: colorSpace
              ) else {
            throw BackgroundRemovalError.couldNotEncodeCutout
        }

        return data
    }
}

public final class FailingBackgroundRemovalService: BackgroundRemovalServiceProtocol {
    private let imageStorage: ImageStorageService
    private let message: String

    public init(
        imageStorage: ImageStorageService,
        message: String = "Background removal failed — retry"
    ) {
        self.imageStorage = imageStorage
        self.message = message
    }

    public func processImage(at originalURL: URL, itemID: UUID) async -> BackgroundRemovalResult {
        do {
            let originalPath = try imageStorage.saveOriginal(from: originalURL, itemID: itemID)
            let thumbnailPath = try? imageStorage.makeThumbnail(
                from: imageStorage.url(for: originalPath),
                itemID: itemID
            )
            return BackgroundRemovalResult(
                originalPath: originalPath,
                cutoutPath: nil,
                thumbnailPath: thumbnailPath,
                status: .failed,
                errorMessage: message
            )
        } catch {
            return BackgroundRemovalResult(
                originalPath: "",
                cutoutPath: nil,
                thumbnailPath: nil,
                status: .failed,
                errorMessage: error.localizedDescription
            )
        }
    }
}

public enum BackgroundRemovalError: LocalizedError {
    case couldNotLoadImage
    case noForegroundMask
    case couldNotEncodeCutout

    public var errorDescription: String? {
        switch self {
        case .couldNotLoadImage:
            return "The image could not be loaded."
        case .noForegroundMask:
            return "No foreground subject was found."
        case .couldNotEncodeCutout:
            return "The cutout image could not be encoded."
        }
    }
}
