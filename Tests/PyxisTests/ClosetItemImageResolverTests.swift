import XCTest
@testable import PyxisCore

final class ClosetItemImageResolverTests: XCTestCase {
    func testBuilderImagePathPrefersCutoutThenThumbnailThenOriginal() {
        let item = ClosetItem(
            itemCode: "TS-001",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .white,
            imageOriginalPath: "Images/Originals/item.jpg",
            imageCutoutPath: "Images/Cutouts/item.png",
            thumbnailPath: "Images/Thumbnails/item.jpg"
        )

        XCTAssertEqual(ClosetItemImageResolver.preferredDisplayPath(for: item), "Images/Cutouts/item.png")

        item.imageCutoutPath = nil
        XCTAssertEqual(ClosetItemImageResolver.preferredDisplayPath(for: item), "Images/Thumbnails/item.jpg")

        item.thumbnailPath = nil
        XCTAssertEqual(ClosetItemImageResolver.preferredDisplayPath(for: item), "Images/Originals/item.jpg")
    }
}
