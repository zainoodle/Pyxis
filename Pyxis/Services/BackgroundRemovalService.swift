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

private enum BackgroundRemovalCopy {
    static let importFailed = "Image import failed — try another image"
    static let removalFailed = "Background removal failed — retry"
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
                        errorMessage: BackgroundRemovalCopy.removalFailed
                    )
                }
            } catch {
                return BackgroundRemovalResult(
                    originalPath: "",
                    cutoutPath: nil,
                    thumbnailPath: nil,
                    status: .failed,
                    errorMessage: BackgroundRemovalCopy.importFailed
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

        let selectedInstances = try Self.selectedForegroundInstances(
            from: observation,
            handler: handler,
            ciContext: ciContext
        )
        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: selectedInstances,
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

    private static func selectedForegroundInstances(
        from observation: VNInstanceMaskObservation,
        handler: VNImageRequestHandler,
        ciContext: CIContext
    ) throws -> IndexSet {
        let allInstances = observation.allInstances
        guard allInstances.count > 1 else {
            return allInstances
        }

        let stats = try allInstances.compactMap { instance -> BackgroundMaskInstanceStats? in
            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: IndexSet(integer: instance),
                from: handler
            )
            return BackgroundMaskInstanceStats(
                instance: instance,
                maskImage: CIImage(cvPixelBuffer: maskBuffer),
                ciContext: ciContext
            )
        }

        let selected = BackgroundMaskInstanceSelector.selectedInstances(from: stats)
        return selected.isEmpty ? allInstances : selected
    }
}

struct BackgroundMaskInstanceStats: Equatable {
    let instance: Int
    let areaFraction: Double
    let centroidX: Double
    let centroidY: Double
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    init(
        instance: Int,
        areaFraction: Double,
        centroidX: Double,
        centroidY: Double,
        minX: Double,
        maxX: Double,
        minY: Double,
        maxY: Double
    ) {
        self.instance = instance
        self.areaFraction = areaFraction
        self.centroidX = centroidX
        self.centroidY = centroidY
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }

    init?(instance: Int, maskImage: CIImage, ciContext: CIContext) {
        let extent = maskImage.extent
        guard extent.width > 0, extent.height > 0 else {
            return nil
        }

        let sampleScale = min(1, 256 / max(extent.width, extent.height))
        let sampleWidth = max(1, Int((extent.width * sampleScale).rounded(.up)))
        let sampleHeight = max(1, Int((extent.height * sampleScale).rounded(.up)))
        let sampleBounds = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        let normalizedMask = maskImage
            .transformed(by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
            .transformed(by: CGAffineTransform(scaleX: sampleScale, y: sampleScale))

        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        ciContext.render(
            normalizedMask,
            toBitmap: &pixels,
            rowBytes: sampleWidth * 4,
            bounds: sampleBounds,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var count = 0
        var minPixelX = sampleWidth
        var maxPixelX = 0
        var minPixelY = sampleHeight
        var maxPixelY = 0
        var sumX = 0
        var sumY = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = (y * sampleWidth + x) * 4
                // Foreground masks render as grayscale with an opaque output alpha.
                // Reading alpha here would classify every pixel as foreground.
                let value = pixels[offset]
                guard value > 24 else {
                    continue
                }

                count += 1
                minPixelX = min(minPixelX, x)
                maxPixelX = max(maxPixelX, x)
                minPixelY = min(minPixelY, y)
                maxPixelY = max(maxPixelY, y)
                sumX += x
                sumY += y
            }
        }

        guard count > 0 else {
            return nil
        }

        let maxXDenominator = Double(max(sampleWidth - 1, 1))
        let maxYDenominator = Double(max(sampleHeight - 1, 1))
        self.instance = instance
        self.areaFraction = Double(count) / Double(sampleWidth * sampleHeight)
        self.centroidX = Double(sumX) / Double(count) / maxXDenominator
        self.centroidY = Double(sumY) / Double(count) / maxYDenominator
        self.minX = Double(minPixelX) / maxXDenominator
        self.maxX = Double(maxPixelX) / maxXDenominator
        self.minY = Double(minPixelY) / maxYDenominator
        self.maxY = Double(maxPixelY) / maxYDenominator
    }

    var width: Double {
        maxX - minX
    }

    var height: Double {
        maxY - minY
    }

    func normalizedOverlap(with other: BackgroundMaskInstanceStats) -> Double {
        let overlapX = max(0, min(maxX, other.maxX) - max(minX, other.minX))
        let overlapY = max(0, min(maxY, other.maxY) - max(minY, other.minY))
        let smallerArea = max(0.0001, min(width * height, other.width * other.height))
        return (overlapX * overlapY) / smallerArea
    }
}

enum BackgroundMaskInstanceSelector {
    static func selectedInstances(from stats: [BackgroundMaskInstanceStats]) -> IndexSet {
        let usableStats = stats.filter { $0.areaFraction > 0.001 }
        guard let primary = usableStats.max(by: { score($0) < score($1) }) else {
            return []
        }

        let largestArea = usableStats.map(\.areaFraction).max() ?? primary.areaFraction
        var selected = IndexSet(integer: primary.instance)

        for candidate in usableStats where candidate.instance != primary.instance {
            guard candidate.areaFraction >= max(0.004, primary.areaFraction * 0.22),
                  candidate.areaFraction >= largestArea * 0.18 else {
                continue
            }

            let similarPair = candidate.areaFraction >= primary.areaFraction * 0.45
                && abs(candidate.centroidY - primary.centroidY) < 0.35
                && abs(candidate.centroidX - primary.centroidX) < 0.65
            let overlapsPrimary = candidate.normalizedOverlap(with: primary) > 0.18
            let centralUsefulFragment = abs(candidate.centroidX - 0.5) < 0.38
                && candidate.areaFraction >= primary.areaFraction * 0.35

            if similarPair || overlapsPrimary || centralUsefulFragment {
                selected.insert(candidate.instance)
            }
        }

        return selected
    }

    private static func score(_ stats: BackgroundMaskInstanceStats) -> Double {
        let centerDistance = abs(stats.centroidX - 0.5)
        let centerWeight = max(0.55, 1 - centerDistance * 0.85)
        let usefulHeightWeight = min(1, max(0.45, stats.height * 1.8))
        return stats.areaFraction * centerWeight * usefulHeightWeight
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
                errorMessage: BackgroundRemovalCopy.importFailed
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
