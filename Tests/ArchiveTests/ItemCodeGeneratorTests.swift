import XCTest
@testable import ArchiveCore

final class ItemCodeGeneratorTests: XCTestCase {
    func testGeneratesRequiredSubtypePrefixes() {
        let cases: [(ClothingSubtype, ClothingCategory, String)] = [
            (.tShirt, .tops, "TS-001"),
            (.longSleeve, .tops, "LS-001"),
            (.hoodie, .tops, "HD-001"),
            (.crewneck, .tops, "CN-001"),
            (.sweater, .tops, "SW-001"),
            (.pants, .bottoms, "PT-001"),
            (.jeans, .bottoms, "JE-001"),
            (.sneakers, .footwear, "SH-001"),
            (.boots, .footwear, "BT-001"),
            (.slides, .footwear, "SL-001"),
            (.jacket, .outerwear, "JK-001"),
            (.coat, .outerwear, "CT-001"),
            (.bag, .accessories, "BG-001"),
            (.belt, .accessories, "AC-001"),
            (.other, .other, "OT-001")
        ]

        for (subtype, category, expected) in cases {
            let code = ItemCodeGenerator.generate(
                for: subtype,
                category: category,
                existingCodes: []
            )
            XCTAssertEqual(code, expected, "Unexpected code for \(subtype.rawValue)")
        }
    }

    func testContinuesNumberingForExistingPrefix() {
        let code = ItemCodeGenerator.generate(
            for: .tShirt,
            category: .tops,
            existingCodes: ["TS-001", "TS-002"]
        )

        XCTAssertEqual(code, "TS-003")
    }

    func testAvoidsCollisionsByChoosingFirstAvailableCode() {
        let code = ItemCodeGenerator.generate(
            for: .tShirt,
            category: .tops,
            existingCodes: ["TS-001", "TS-003", "HD-001"]
        )

        XCTAssertEqual(code, "TS-002")
    }

    func testGeneratedCodeDoesNotChangeWhenMetadataChanges() {
        let item = ClosetItem(
            itemCode: "TS-001",
            displayName: "White tee",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .white,
            imageOriginalPath: "Images/Originals/item.jpg"
        )

        item.category = .outerwear
        item.subtype = .coat
        item.primaryColor = .black

        XCTAssertEqual(item.itemCode, "TS-001")
    }
}
