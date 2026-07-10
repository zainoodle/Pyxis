import XCTest
@testable import PyxisCore

@MainActor
final class ItemDetailViewModelTests: XCTestCase {
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
