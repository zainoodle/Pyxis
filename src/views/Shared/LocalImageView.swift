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
    var rackAvailability: ((Bool) -> Void)?
    @State private var shoulderAttachment: GarmentRackAttachment?
    @State private var clipAttachment: GarmentRackAttachment?
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var visibleFraction = 1.0
    @State private var visibleBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var didFail = false
    @State private var reloadGeneration = 0

    var body: some View {
        Group {
            if let image {
                if let attachment, isCutout {
                    GeometryReader { geometry in
                        let available = CGSize(width: geometry.size.width, height: max(1, geometry.size.height - 64))
                        let size = GarmentImageFraming.balancedDisplaySize(
                            imageSize: image.size, visibleFraction: visibleFraction, in: available
                        )
                        let frame = GarmentRackGeometry.imageFrame(
                            displaySize: size, attachment: attachment.anchor, in: geometry.size,
                            drop: attachment.support == .clips ? GarmentRackGeometry.clipSupportDrop : GarmentRackGeometry.supportDrop
                        )
                        ZStack(alignment: .topLeading) {
                            GarmentRackHanger(support: attachment.support)
                                .frame(width: frame.width * attachment.span + (attachment.support == .clips ? 27 : 8), height: 68)
                                .position(x: geometry.size.width / 2, y: GarmentRackGeometry.hookY + 25)
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
        .onChange(of: rackSupport) { _, _ in rackAvailability?(attachment != nil) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("pyxis.imageDidChange"))
            .receive(on: RunLoop.main)) { notification in
            guard let changedURL = notification.userInfo?["url"] as? URL, changedURL == url else { return }
            reloadGeneration += 1
        }
        .task(id: "\(loadIdentity)|\(reloadGeneration)") {
            await loadImage()
        }
    }

    private var attachment: GarmentRackAttachment? {
        switch rackSupport {
        case .shoulder: shoulderAttachment
        case .clips: clipAttachment
        case nil: nil
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
        shoulderAttachment = nil
        clipAttachment = nil
        rackAvailability?(false)

        guard let url else {
            didFail = true
            return
        }

        if let cached = LocalImageCache.shared.image(forKey: loadIdentity) {
            image = cached.value
            visibleFraction = cached.visibleFraction
            visibleBounds = cached.visibleBounds
            shoulderAttachment = cached.shoulderAttachment
            clipAttachment = cached.clipAttachment
            rackAvailability?(attachment != nil)
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
        shoulderAttachment = loaded.shoulderAttachment
        clipAttachment = loaded.clipAttachment
        rackAvailability?(attachment != nil)
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
        return SendableImage(UIImage(cgImage: displayedImage), visibleFraction: analysis?.visibleFraction ?? 1, visibleBounds: bounds,
                             shoulderAttachment: cutout ? GarmentRackAttachment.analyze(displayedImage, support: .shoulder, context: framingContext) : nil,
                             clipAttachment: cutout ? GarmentRackAttachment.analyze(displayedImage, support: .clips, context: framingContext) : nil)
    }
}

private final class SendableImage: @unchecked Sendable {
    let value: UIImage
    let visibleFraction: Double
    let visibleBounds: CGRect
    let shoulderAttachment: GarmentRackAttachment?
    let clipAttachment: GarmentRackAttachment?

    init(_ value: UIImage, visibleFraction: Double, visibleBounds: CGRect, shoulderAttachment: GarmentRackAttachment?, clipAttachment: GarmentRackAttachment?) {
        self.value = value
        self.visibleFraction = visibleFraction
        self.visibleBounds = visibleBounds
        self.shoulderAttachment = shoulderAttachment
        self.clipAttachment = clipAttachment
    }
}

private final class LocalImageCache: @unchecked Sendable {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, SendableImage>()
    private var observer: NSObjectProtocol?

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 96 * 1_024 * 1_024
        observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("pyxis.imageDidChange"), object: nil, queue: nil
        ) { [weak self] _ in self?.invalidate() }
    }

    func image(forKey key: String) -> SendableImage? {
        cache.object(forKey: key as NSString)
    }

    // Writes are rare. Purging this small cache avoids retaining stale path/revision variants.
    func invalidate() { cache.removeAllObjects() }

    func insert(_ image: SendableImage, forKey key: String) {
        let pixelWidth = image.value.size.width * image.value.scale
        let pixelHeight = image.value.size.height * image.value.scale
        let cost = Int(pixelWidth * pixelHeight * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
