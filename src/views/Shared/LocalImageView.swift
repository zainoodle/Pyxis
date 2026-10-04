import SwiftUI
import UIKit
import ImageIO
import CoreImage

struct LocalImageView: View {
    nonisolated private static let framingContext = CIContext(options: [.cacheIntermediates: false])

    let url: URL?
    var contentMode: ContentMode = .fit
    var revision = 0
    var balancedFraming = false
    var castsShadow = false
    var rackSupport: GarmentRackSupport?
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var visibleFraction = 1.0
    @State private var visibleBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                if let rackSupport, isCutout {
                    GeometryReader { geometry in
                        let available = CGSize(width: geometry.size.width, height: max(1, geometry.size.height - 64))
                        let size = GarmentImageFraming.balancedDisplaySize(
                            imageSize: image.size, visibleFraction: visibleFraction, in: available
                        )
                        let frame = GarmentRackGeometry.imageFrame(
                            displaySize: size, visibleBounds: visibleBounds, in: geometry.size,
                            drop: rackSupport == .clips ? GarmentRackGeometry.clipSupportDrop : GarmentRackGeometry.supportDrop
                        )
                        ZStack(alignment: .topLeading) {
                            GarmentRackHanger(support: rackSupport)
                                .frame(width: min(152, frame.width * visibleBounds.width * 0.64), height: 68)
                                .position(x: geometry.size.width / 2, y: GarmentRackGeometry.hookY + 34)
                                .accessibilityHidden(true)
                            displayed(image)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                } else if balancedFraming && isCutout {
                    GeometryReader { geometry in
                        let size = GarmentImageFraming.balancedDisplaySize(
                            imageSize: image.size, visibleFraction: visibleFraction, in: geometry.size
                        )
                        displayed(image)
                            .frame(width: size.width, height: size.height)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    displayed(image)
                }
            } else if url != nil && !didFail {
                Rectangle()
                    .fill(Color.clear)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .overlay {
                        Text("NO IMAGE")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.inactiveText)
                    }
            }
        }
        .accessibilityLabel("Clothing image")
        .task(id: loadIdentity) {
            await loadImage()
        }
    }

    private var isCutout: Bool {
        url?.deletingLastPathComponent().lastPathComponent == "Cutouts"
    }

    private func displayed(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .shadow(color: .black.opacity(castsShadow && isCutout ? (colorScheme == .dark ? 0.36 : 0.14) : 0),
                    radius: 12, x: 0, y: 10)
    }

    private var loadIdentity: String {
        guard let url else {
            return "no-image"
        }

        return "\(url.path)|\(revision)"
    }

    @MainActor
    private func loadImage() async {
        image = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        if let cached = LocalImageCache.shared.image(forKey: loadIdentity) {
            image = cached.value
            visibleFraction = cached.visibleFraction
            visibleBounds = cached.visibleBounds
            return
        }

        let loaded = await Task.detached(priority: .userInitiated) {
            Self.downsampledImage(at: url, maxPixelSize: 1_200)
        }.value

        guard !Task.isCancelled else {
            return
        }

        guard let loaded else {
            didFail = true
            return
        }

        LocalImageCache.shared.insert(loaded, forKey: loadIdentity)
        image = loaded.value
        visibleFraction = loaded.visibleFraction
        visibleBounds = loaded.visibleBounds
    }

    nonisolated private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> SendableImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        let cutout = url.deletingLastPathComponent().lastPathComponent == "Cutouts"
        let displayedImage = cutout
            ? GarmentImageFraming.framedDisplayImage(image, using: framingContext)
            : image
        let analysis = cutout ? GarmentImageFraming.analyze(CIImage(cgImage: displayedImage), using: framingContext) : nil
        let rect = analysis?.visibleRect ?? CGRect(x: 0, y: 0, width: displayedImage.width, height: displayedImage.height)
        let bounds = CGRect(x: rect.minX / CGFloat(displayedImage.width),
                            y: 1 - rect.maxY / CGFloat(displayedImage.height),
                            width: rect.width / CGFloat(displayedImage.width),
                            height: rect.height / CGFloat(displayedImage.height))
        return SendableImage(UIImage(cgImage: displayedImage), visibleFraction: analysis?.visibleFraction ?? 1, visibleBounds: bounds)
    }
}

private final class SendableImage: @unchecked Sendable {
    let value: UIImage
    let visibleFraction: Double
    let visibleBounds: CGRect

    init(_ value: UIImage, visibleFraction: Double, visibleBounds: CGRect) {
        self.value = value
        self.visibleFraction = visibleFraction
        self.visibleBounds = visibleBounds
    }
}

private final class LocalImageCache: @unchecked Sendable {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, SendableImage>()

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(forKey key: String) -> SendableImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: SendableImage, forKey key: String) {
        let pixelWidth = image.value.size.width * image.value.scale
        let pixelHeight = image.value.size.height * image.value.scale
        let cost = Int(pixelWidth * pixelHeight * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
