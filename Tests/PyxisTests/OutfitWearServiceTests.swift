import XCTest
@testable import PyxisCore

final class OutfitWearServiceTests: XCTestCase {
    func testMarkWornIncrementsOutfitAndSelectedItemsOnly() {
        let top = makeItem(id: UUID(), code: "TS-001")
        let bottom = makeItem(id: UUID(), code: "PA-001")
        let unused = makeItem(id: UUID(), code: "SN-999")
        let wornDate = Date(timeIntervalSince1970: 100)
        let outfit = Outfit(topItemID: top.id, bottomItemID: bottom.id, footwearItemID: nil)

        OutfitWearService().markWorn(outfit: outfit, items: [top, bottom, unused], on: wornDate)

        XCTAssertEqual(outfit.wearCount, 1)
        XCTAssertEqual(outfit.lastWornDate, wornDate)
        XCTAssertEqual(top.wearCount, 1)
        XCTAssertEqual(bottom.wearCount, 1)
        XCTAssertEqual(unused.wearCount, 0)
        XCTAssertEqual(top.lastWornDate, wornDate)
        XCTAssertEqual(bottom.lastWornDate, wornDate)
        XCTAssertNil(unused.lastWornDate)
    }

    private func makeItem(id: UUID, code: String) -> ClosetItem {
        ClosetItem(
            id: id,
            itemCode: code,
            category: .tops,
            subtype: .tShirt,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/\(code).png"
        )
    }
}
