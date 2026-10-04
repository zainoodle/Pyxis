import XCTest
@testable import PyxisCore

@MainActor
final class ItemDetailViewModelTests: XCTestCase {
    func testProcessingLeasePreventsSecondDetailInstanceFromStartingOrDeleting() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try ImageStorageService(rootURL: root)
        let service = SuspendedCutoutService()
        let first = ItemDetailViewModel(imageStorage: storage, backgroundRemovalService: service)
        let second = ItemDetailViewModel(imageStorage: storage, backgroundRemovalService: service)
        let item = makeItem()
        let task = Task { await first.retryBackgroundRemoval(for: item) }
        await service.waitUntilStarted()
        XCTAssertTrue(ItemImageProcessingState.shared.contains(item.id))
        await second.retryBackgroundRemoval(for: item)
        let calls = await service.calls
        XCTAssertEqual(calls, 1)
        await service.finish(original: item.imageOriginalPath)
        await task.value
        XCTAssertFalse(ItemImageProcessingState.shared.contains(item.id))
        XCTAssertEqual(item.imageCutoutPath, "Images/Cutouts/existing.png")
    }

    func testFailedRetryPreservesExistingCutoutAndThumbnail() {
        let item = makeItem()
        let result = BackgroundRemovalResult(
            originalPath: item.imageOriginalPath,
            cutoutPath: nil,
            thumbnailPath: "Images/Thumbnails/retry.png",
            status: .failed,
            errorMessage: "Background removal failed — retry"
        )

        ItemDetailViewModel.applySuccessfulBackgroundRemovalResult(result, to: item)

        XCTAssertEqual(item.imageCutoutPath, "Images/Cutouts/existing.png")
        XCTAssertEqual(item.thumbnailPath, "Images/Thumbnails/existing.png")
    }

    func testSuccessfulRetryReplacesCutoutAndThumbnail() {
        let item = makeItem()
        let result = BackgroundRemovalResult(
            originalPath: item.imageOriginalPath,
            cutoutPath: "Images/Cutouts/retry.png",
            thumbnailPath: "Images/Thumbnails/retry.png",
            status: .succeeded
        )

        ItemDetailViewModel.applySuccessfulBackgroundRemovalResult(result, to: item)

        XCTAssertEqual(item.imageCutoutPath, "Images/Cutouts/retry.png")
        XCTAssertEqual(item.thumbnailPath, "Images/Thumbnails/retry.png")
    }

    func testRetryUsesAuthoritativeModelIDInsteadOfParsingFilename() {
        let imageID = UUID()
        let modelID = UUID()
        let item = ClosetItem(
            id: modelID,
            itemCode: "OT-001",
            category: .other,
            subtype: .other,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/\(imageID.uuidString).jpg"
        )

        XCTAssertEqual(ItemDetailViewModel.backgroundRemovalItemID(for: item), modelID)
        XCTAssertNotEqual(ItemDetailViewModel.backgroundRemovalItemID(for: item), imageID)
    }

    private func makeItem() -> ClosetItem {
        ClosetItem(
            itemCode: "TS-001",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .white,
            imageOriginalPath: "Images/Originals/item.jpg",
            imageCutoutPath: "Images/Cutouts/existing.png",
            thumbnailPath: "Images/Thumbnails/existing.png"
        )
    }
}

private actor SuspendedCutoutService: BackgroundRemovalServiceProtocol {
    var calls = 0
    private var pending: CheckedContinuation<BackgroundRemovalResult, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func processImage(at originalURL: URL, itemID: UUID) async -> BackgroundRemovalResult {
        calls += 1
        return await withCheckedContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(original: String) {
        pending?.resume(returning: BackgroundRemovalResult(originalPath: original, cutoutPath: nil,
                                                            thumbnailPath: nil, status: .failed))
        pending = nil
    }
}
