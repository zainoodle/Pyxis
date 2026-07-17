import Foundation

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var showOriginal = false
    @Published var isRetryingBackgroundRemoval = false
    @Published var retryMessage: String?
    @Published var imageRevision = 0

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
            itemID: Self.backgroundRemovalItemID(for: item)
        )

        if result.status == .succeeded {
            Self.applySuccessfulBackgroundRemovalResult(result, to: item)
            imageRevision += 1
        }
        retryMessage = result.status == .succeeded
            ? "Background removed"
            : (result.errorMessage ?? "Background removal failed — retry")
    }

    static func applySuccessfulBackgroundRemovalResult(
        _ result: BackgroundRemovalResult,
        to item: ClosetItem
    ) {
        guard result.status == .succeeded, let cutoutPath = result.cutoutPath else {
            return
        }

        item.imageCutoutPath = cutoutPath
        item.thumbnailPath = result.thumbnailPath ?? item.thumbnailPath
        item.touch()
    }

    static func backgroundRemovalItemID(for item: ClosetItem) -> UUID {
        StoredImageSet(
            originalPath: item.imageOriginalPath,
            cutoutPath: item.imageCutoutPath,
            thumbnailPath: item.thumbnailPath
        ).stableItemID
    }

    func storedImageSet(for item: ClosetItem) -> StoredImageSet {
        StoredImageSet(
            originalPath: item.imageOriginalPath,
            cutoutPath: item.imageCutoutPath,
            thumbnailPath: item.thumbnailPath
        )
    }

    func deleteImages(_ imageSet: StoredImageSet) {
        imageStorage?.deleteImages(imageSet)
    }
}
