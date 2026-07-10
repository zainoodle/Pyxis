import SwiftUI
import UIKit

struct LocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var revision = 0
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
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

    private var loadIdentity: String {
        guard let url else {
            return "no-image"
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = values?.fileSize ?? 0
        return "\(url.path)|\(size)|\(revision)"
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
            image = cached
            return
        }

        let loaded = await Task.detached(priority: .userInitiated) {
            SendableImage(UIImage(contentsOfFile: url.path))
        }.value

        guard !Task.isCancelled else {
            return
        }

        guard let loadedImage = loaded.value else {
            didFail = true
            return
        }

        LocalImageCache.shared.insert(loadedImage, forKey: loadIdentity)
        image = loadedImage
    }
}

private struct SendableImage: @unchecked Sendable {
    let value: UIImage?

    init(_ value: UIImage?) {
        self.value = value
    }
}

private final class LocalImageCache: @unchecked Sendable {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, forKey key: String) {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let cost = Int(pixelWidth * pixelHeight * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
