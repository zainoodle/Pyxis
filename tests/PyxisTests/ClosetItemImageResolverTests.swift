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

    func testFullSizeGalleryPrefersCutoutAndSkipsThumbnailFallback() {
        let item = ClosetItem(
            itemCode: "JA-001",
            category: .outerwear,
            subtype: .jacket,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/jacket.png",
            imageCutoutPath: "Images/Cutouts/jacket.png",
            thumbnailPath: "Images/Thumbnails/jacket.jpg"
        )

        XCTAssertEqual(ClosetItemImageResolver.preferredFullSizePath(for: item), "Images/Cutouts/jacket.png")
        item.imageCutoutPath = nil
        XCTAssertEqual(ClosetItemImageResolver.preferredFullSizePath(for: item), "Images/Originals/jacket.png")
        XCTAssertEqual(ClosetItemImageResolver.preferredDisplayPath(for: item), "Images/Thumbnails/jacket.jpg")
    }

}
