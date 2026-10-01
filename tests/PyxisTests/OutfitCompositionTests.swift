import XCTest
@testable import PyxisCore

final class OutfitCompositionTests: XCTestCase {
    func testExplicitBuildRequestReplacesOnlyItsKeptPieceAndPreservesOtherLocks() {
        let top = UUID(), bottom = UUID(), shoes = UUID(), replacement = UUID()
        var composition = OutfitComposition(
            selections: [.top: top, .bottom: bottom, .footwear: shoes],
            keptSlots: [.top, .footwear]
        )
        composition.begin(with: replacement, for: .top)
        XCTAssertEqual(composition.selections, [.top: replacement, .bottom: bottom, .footwear: shoes])
        XCTAssertEqual(composition.keptSlots, [.top, .footwear])
    }

    func testSwappingOnePiecePreservesTheRestOfTheFit() {
        let top = UUID(), bottom = UUID(), shoes = UUID(), replacement = UUID()
        var composition = OutfitComposition(selections: [.top: top, .bottom: bottom, .footwear: shoes])
        XCTAssertTrue(composition.select(replacement, for: .bottom))
        XCTAssertEqual(composition.draft.topItemID, top)
        XCTAssertEqual(composition.draft.bottomItemID, replacement)
        XCTAssertEqual(composition.draft.footwearItemID, shoes)
    }

    func testKeptPieceMustBeUnlockedBeforeReplacementOrRemoval() {
        let jacket = UUID()
        var composition = OutfitComposition(selections: [.outerwear: jacket], keptSlots: [.outerwear])
        XCTAssertFalse(composition.select(UUID(), for: .outerwear))
        XCTAssertFalse(composition.remove(.outerwear))
        XCTAssertEqual(composition.selections[.outerwear], jacket)
        composition.toggleKeep(.outerwear)
        XCTAssertTrue(composition.remove(.outerwear))
    }

    func testOnePieceCannotSilentlyRemoveKeptSeparates() {
        let top = UUID(), bottom = UUID(), dress = UUID()
        var composition = OutfitComposition(selections: [.top: top, .bottom: bottom], keptSlots: [.top])
        XCTAssertFalse(composition.select(dress, for: .onePiece))
        XCTAssertEqual(composition.selections[.bottom], bottom)
        composition.toggleKeep(.top)
        XCTAssertTrue(composition.select(dress, for: .onePiece))
        XCTAssertNil(composition.selections[.top])
        XCTAssertNil(composition.selections[.bottom])
    }

    func testClosetChangesPruneMissingDeletedAndRecategorizedPiecesWithoutReplacingThem() {
        let top = item("TP-001", .tops), bottom = item("BT-001", .bottoms), shoe = item("FW-001", .footwear)
        var composition = OutfitComposition(selections: [.top: top.id, .bottom: bottom.id, .footwear: shoe.id], keptSlots: [.top])
        top.markDeleted()
        bottom.category = .other
        composition.reconcile(with: [shoe, bottom, top])
        XCTAssertEqual(composition.selections, [.footwear: shoe.id])
        XCTAssertTrue(composition.keptSlots.isEmpty)
    }

    func testLocalDraftRoundTripPreservesSelectionsAndLocks() throws {
        let suite = "PyxisDraftTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OutfitDraftStore(defaults: defaults)
        let draft = OutfitComposition(selections: [.top: UUID(), .footwear: UUID()], keptSlots: [.top])
        try store.save(draft)
        XCTAssertEqual(try store.load(), draft)
        store.clear()
        XCTAssertNil(try store.load())
    }

    private func item(_ code: String, _ category: ClothingCategory) -> ClosetItem {
        ClosetItem(itemCode: code, category: category, subtype: .other, primaryColor: .black, imageOriginalPath: "\(code).jpg")
    }
}
