import XCTest
@testable import PyxisCore

final class ClothingSubtypeCompatibilityTests: XCTestCase {
    func testEverySpecificSubtypeDeclaresCompatibleCategory() {
        let cases: [(ClothingSubtype, ClothingCategory)] = [
            (.tShirt, .tops),
            (.longSleeve, .tops),
            (.shirt, .tops),
            (.hoodie, .tops),
            (.crewneck, .tops),
            (.sweater, .tops),
            (.cardigan, .tops),
            (.jacket, .outerwear),
            (.coat, .outerwear),
            (.vest, .outerwear),
            (.jeans, .bottoms),
            (.pants, .bottoms),
            (.leggings, .bottoms),
            (.joggers, .bottoms),
            (.shorts, .bottoms),
            (.skirt, .bottoms),
            (.dress, .onePiece),
            (.sneakers, .footwear),
            (.boots, .footwear),
            (.slides, .footwear),
            (.mules, .footwear),
            (.sandals, .footwear),
            (.hat, .accessories),
            (.bag, .accessories),
            (.belt, .accessories),
            (.jewelry, .accessories),
            (.scarf, .accessories),
            (.sunglasses, .accessories),
            (.watch, .accessories)
        ]

        for (subtype, category) in cases {
            XCTAssertEqual(subtype.compatibleCategory, category, subtype.rawValue)
            XCTAssertTrue(ClothingSubtype.compatibleSubtypes(for: category).contains(subtype), subtype.rawValue)
        }
    }

    func testCompatibleSubtypesForOtherOnlyContainsOther() {
        XCTAssertEqual(ClothingSubtype.compatibleSubtypes(for: .other), [.other])
    }

    func testDefaultSubtypeForCategoryIsCompatible() {
        for category in ClothingCategory.allCases {
            let defaultSubtype = ClothingSubtype.defaultSubtype(for: category)

            XCTAssertTrue(
                ClothingSubtype.compatibleSubtypes(for: category).contains(defaultSubtype),
                "\(defaultSubtype.rawValue) should be compatible with \(category.rawValue)"
            )
        }
    }
}
