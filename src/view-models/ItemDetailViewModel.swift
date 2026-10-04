import Foundation

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var showOriginal = false
    @Published var isRetryingBackgroundRemoval = false
    @Published var retryMessage: String?
    @Published var imageRevision = 0

    private let imageStorage: ImageStorageService?
    private let backgroundRemovalService: (any BackgroundRemovalServiceProtocol)?

    init(imageStorage: ImageStorageService? = try? ImageStorageService(),
         backgroundRemovalService: (any BackgroundRemovalServiceProtocol)? = nil) {
        self.imageStorage = imageStorage
        self.backgroundRemovalService = backgroundRemovalService
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
        guard let imageStorage, !isRetryingBackgroundRemoval,
              ItemImageProcessingState.shared.begin(item.id) else {
            return
        }

        retryMessage = nil
        isRetryingBackgroundRemoval = true
        defer {
            isRetryingBackgroundRemoval = false
            ItemImageProcessingState.shared.end(item.id)
        }

        let service = backgroundRemovalService ?? LocalBackgroundRemovalService(imageStorage: imageStorage)
        let result = await service.processImage(
            at: imageStorage.url(for: item.imageOriginalPath),
            itemID: Self.backgroundRemovalItemID(for: item)
        )

        if result.status == .succeeded {
            Self.applySuccessfulBackgroundRemovalResult(result, to: item)
            imageRevision += 1
        }
        retryMessage = result.status == .succeeded
            ? "Cutout reviewed and framed"
            : "Couldn’t improve this cutout. Kept your current image."
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
        item.id
    }

    func storedImageSet(for item: ClosetItem) -> StoredImageSet {
        StoredImageSet(
            itemID: item.id,
            originalPath: item.imageOriginalPath,
            cutoutPath: item.imageCutoutPath,
            thumbnailPath: item.thumbnailPath
        )
    }

    func deleteImages(_ imageSet: StoredImageSet) {
        imageStorage?.deleteImages(imageSet)
    }
}

/// Shared across detail instances: navigating away cannot make an in-flight piece deletable.
@MainActor
final class ItemImageProcessingState: ObservableObject {
    static let shared = ItemImageProcessingState()
    @Published private(set) var itemIDs: Set<UUID> = []

    func begin(_ id: UUID) -> Bool { itemIDs.insert(id).inserted }
    func end(_ id: UUID) { itemIDs.remove(id) }
    func contains(_ id: UUID) -> Bool { itemIDs.contains(id) }
}
