import Foundation

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var showOriginal = false
    @Published var isRetryingBackgroundRemoval = false
    @Published var retryMessage: String?

    private let imageStorage: ImageStorageService?

    init() {
        imageStorage = try? ImageStorageService()
    }

    func displayURL(for item: ClosetItem) -> URL? {
        guard let imageStorage else {
            return nil
        }

        if showOriginal {
            return imageStorage.url(for: item.imageOriginalPath)
        }
        if let cutoutPath = item.imageCutoutPath {
            return imageStorage.url(for: cutoutPath)
        }
        return imageStorage.url(for: item.imageOriginalPath)
    }

    func retryBackgroundRemoval(for item: ClosetItem) async {
        guard let imageStorage else {
            return
        }

        isRetryingBackgroundRemoval = true
        defer { isRetryingBackgroundRemoval = false }

        let service = LocalBackgroundRemovalService(imageStorage: imageStorage)
        let result = await service.processImage(
            at: imageStorage.url(for: item.imageOriginalPath),
            itemID: item.id
        )

        item.imageCutoutPath = result.cutoutPath
        item.thumbnailPath = result.thumbnailPath ?? item.thumbnailPath
        retryMessage = result.status == .succeeded
            ? "Background removed"
            : (result.errorMessage ?? "Background removal failed — retry")
    }

    func deleteImages(for item: ClosetItem) {
        imageStorage?.deleteImages(for: item)
    }
}
