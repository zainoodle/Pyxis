import XCTest
@testable import PyxisCore

final class OutfitBuilderServiceTests: XCTestCase {
    func testBuildsRowsForRequiredOutfitCategories() {
        let top = makeItem(code: "TS-001", category: .tops, subtype: .tShirt)
        let bottom = makeItem(code: "PA-001", category: .bottoms, subtype: .pants)
        let shoes = makeItem(code: "SN-001", category: .footwear, subtype: .sneakers)
        let accessory = makeItem(code: "BG-001", category: .accessories, subtype: .bag)

        let rows = OutfitBuilderService().requiredRows(from: [shoes, accessory, top, bottom])

        XCTAssertEqual(rows.map(\.slot), [.top, .bottom, .footwear])
        XCTAssertEqual(rows[0].items.map(\.itemCode), ["TS-001"])
        XCTAssertEqual(rows[1].items.map(\.itemCode), ["PA-001"])
        XCTAssertEqual(rows[2].items.map(\.itemCode), ["SN-001"])
    }

    func testEmptyRequiredCategoryProducesEmptyRow() {
        let top = makeItem(code: "TS-001", category: .tops, subtype: .tShirt)
        let shoes = makeItem(code: "SN-001", category: .footwear, subtype: .sneakers)

        let rows = OutfitBuilderService().requiredRows(from: [top, shoes])

        XCTAssertEqual(rows.map(\.slot), [.top, .bottom, .footwear])
        XCTAssertTrue(rows[1].items.isEmpty)
    }

    func testDefaultSelectionsPickFirstItemInEachNonEmptyRow() {
        let top = makeItem(code: "TS-001", category: .tops, subtype: .tShirt)
        let bottom = makeItem(code: "PA-001", category: .bottoms, subtype: .pants)
        let shoes = makeItem(code: "SN-001", category: .footwear, subtype: .sneakers)
        let rows = OutfitBuilderService().requiredRows(from: [top, bottom, shoes])

        let selections = OutfitBuilderService().defaultSelections(for: rows)

        XCTAssertEqual(selections[.top], 0)
        XCTAssertEqual(selections[.bottom], 0)
        XCTAssertEqual(selections[.footwear], 0)
    }

    func testAdvancingSelectionWrapsWithinRowBounds() {
        let service = OutfitBuilderService()

        XCTAssertEqual(service.advancedIndex(from: 0, offset: 1, itemCount: 3), 1)
        XCTAssertEqual(service.advancedIndex(from: 2, offset: 1, itemCount: 3), 0)
        XCTAssertEqual(service.advancedIndex(from: 0, offset: -1, itemCount: 3), 2)
        XCTAssertNil(service.advancedIndex(from: nil, offset: 1, itemCount: 0))
    }

    func testDraftUsesSelectedRequiredItemIDsAndRequiresCompleteFit() {
        let top = makeItem(code: "TS-001", category: .tops, subtype: .tShirt)
        let bottom = makeItem(code: "PA-001", category: .bottoms, subtype: .pants)
        let shoes = makeItem(code: "SN-001", category: .footwear, subtype: .sneakers)
        let service = OutfitBuilderService()
        let rows = service.requiredRows(from: [top, bottom, shoes])
        let selections: [OutfitSlot: Int] = [.top: 0, .bottom: 0, .footwear: 0]

        let draft = service.draft(from: rows, selections: selections)

        XCTAssertTrue(service.canSave(draft))
        XCTAssertEqual(draft.topItemID, top.id)
        XCTAssertEqual(draft.bottomItemID, bottom.id)
        XCTAssertEqual(draft.footwearItemID, shoes.id)
    }

    func testIncompleteDraftCannotBeSaved() {
        let top = makeItem(code: "TS-001", category: .tops, subtype: .tShirt)
        let rows = OutfitBuilderService().requiredRows(from: [top])

        let draft = OutfitBuilderService().draft(from: rows, selections: [.top: 0])

        XCTAssertFalse(OutfitBuilderService().canSave(draft))
    }

    func testOnePieceAndFootwearCanBeSavedWithoutSeparates() {
        let dress = makeItem(code: "DR-001", category: .onePiece, subtype: .dress)
        let shoes = makeItem(code: "SN-001", category: .footwear, subtype: .sneakers)
        let service = OutfitBuilderService()
        let rows = service.requiredRows(from: [shoes]) + service.optionalRows(from: [dress])
        let draft = service.draft(from: rows, selections: [.onePiece: 0, .footwear: 0])

        XCTAssertTrue(service.canSave(draft))
        XCTAssertEqual(draft.onePieceItemID, dress.id)
    }

    func testCountsOutfitUsageForItems() {
        let topID = UUID()
        let bottomID = UUID()
        let outfits = [
            Outfit(topItemID: topID, bottomItemID: bottomID, footwearItemID: UUID()),
            Outfit(topItemID: topID, bottomItemID: UUID(), footwearItemID: UUID())
        ]

        let usage = OutfitBuilderService().fitUsageCounts(from: outfits)

        XCTAssertEqual(usage[topID], 2)
        XCTAssertEqual(usage[bottomID], 1)
    }

    func testSlotForCategoryMapsBuildCategoriesOnly() {
        let service = OutfitBuilderService()

        XCTAssertEqual(service.slot(for: .tops), .top)
        XCTAssertEqual(service.slot(for: .bottoms), .bottom)
        XCTAssertEqual(service.slot(for: .footwear), .footwear)
        XCTAssertEqual(service.slot(for: .outerwear), .outerwear)
        XCTAssertEqual(service.slot(for: .accessories), .accessory)
        XCTAssertEqual(service.slot(for: .onePiece), .onePiece)
        XCTAssertNil(service.slot(for: .other))
    }

    func testDefaultSubtypeProvidesUsefulMissingCategoryStartingPoint() {
        let service = OutfitBuilderService()

        XCTAssertEqual(service.defaultSubtype(for: .top), .tShirt)
        XCTAssertEqual(service.defaultSubtype(for: .bottom), .pants)
        XCTAssertEqual(service.defaultSubtype(for: .onePiece), .dress)
        XCTAssertEqual(service.defaultSubtype(for: .footwear), .sneakers)
        XCTAssertEqual(service.defaultSubtype(for: .outerwear), .jacket)
        XCTAssertEqual(service.defaultSubtype(for: .accessory), .bag)
    }

    func testSelectionTargetFindsFocusedItemWithinItsBuildRow() {
        let firstTop = makeItem(code: "AA-001", category: .tops, subtype: .tShirt)
        let focusedTop = makeItem(code: "ZZ-001", category: .tops, subtype: .shirt)
        let bottom = makeItem(code: "PA-001", category: .bottoms, subtype: .pants)
        let service = OutfitBuilderService()
        let rows = service.requiredRows(from: [firstTop, focusedTop, bottom])

        let target = service.selectionTarget(for: focusedTop.id, in: rows)

        XCTAssertEqual(target?.slot, .top)
        XCTAssertEqual(target?.index, 1)
    }

    private func makeItem(code: String, category: ClothingCategory, subtype: ClothingSubtype) -> ClosetItem {
        ClosetItem(
            itemCode: code,
            category: category,
            subtype: subtype,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/\(code).jpg"
        )
    }
}
