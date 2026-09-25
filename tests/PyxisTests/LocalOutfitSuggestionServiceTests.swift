import XCTest
@testable import PyxisCore

final class LocalOutfitSuggestionServiceTests: XCTestCase {
    func testSuggestionsUseOwnedActiveClosetPiecesAndSkipSavedCombination() {
        let firstTop = item("T-1", .tops, .tShirt, .white)
        let secondTop = item("T-2", .tops, .shirt, .blue)
        let bottom = item("B-1", .bottoms, .jeans, .navy)
        let shoes = item("S-1", .footwear, .sneakers, .white)
        let purchase = item("P-1", .tops, .shirt, .cream, source: .consideringPurchase)
        let deleted = item("D-1", .tops, .shirt, .black, deleted: true)
        let saved = Outfit(topItemID: firstTop.id, bottomItemID: bottom.id, footwearItemID: shoes.id)

        let looks = LocalOutfitSuggestionService().suggestions(
            from: [firstTop, secondTop, bottom, shoes, purchase, deleted], excluding: [saved]
        )

        XCTAssertEqual(looks.count, 1)
        XCTAssertEqual(looks[0].draft.topItemID, secondTop.id)
        XCTAssertEqual(Set(looks[0].items.map(\.id)), Set([secondTop.id, bottom.id, shoes.id]))
        XCTAssertTrue(OutfitBuilderService().canSave(looks[0].draft))
    }

    func testOnePieceAndFootwearCanFormLookWithoutSeparates() {
        let dress = item("D-1", .onePiece, .dress, .red)
        let shoes = item("S-1", .footwear, .sneakers, .white)
        let looks = LocalOutfitSuggestionService().suggestions(from: [dress, shoes], excluding: [])

        XCTAssertEqual(looks.count, 1)
        XCTAssertEqual(looks[0].draft.onePieceItemID, dress.id)
        XCTAssertNil(looks[0].draft.topItemID)
        XCTAssertTrue(OutfitBuilderService().canSave(looks[0].draft))
    }

    private func item(
        _ code: String, _ category: ClothingCategory, _ subtype: ClothingSubtype,
        _ color: ClosetColor, source: ItemSource = .owned, deleted: Bool = false
    ) -> ClosetItem {
        ClosetItem(itemCode: code, category: category, subtype: subtype, primaryColor: color,
                   dateDeleted: deleted ? .now : nil, imageOriginalPath: "\(code).jpg", source: source)
    }
}
