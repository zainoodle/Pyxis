import XCTest
@testable import PyxisCore

final class OutfitGalleryServiceTests: XCTestCase {
    func testSearchAndMetadataFiltersUseOnlyItemsInEachFit() {
        let oliveTop = ClosetItem(
            itemCode: "TOP-1", displayName: "Oxford shirt", category: .tops,
            subtype: .shirt, primaryColor: .olive, season: [.fall],
            imageOriginalPath: "olive.jpg"
        )
        let blueTop = ClosetItem(
            itemCode: "TOP-2", category: .tops, subtype: .shirt,
            primaryColor: .blue, season: [.summer], imageOriginalPath: "blue.jpg"
        )
        let fallFit = Outfit(name: "CITY LAYERS", topItemID: oliveTop.id)
        let summerFit = Outfit(name: "BEACH", topItemID: blueTop.id)
        let service = OutfitGalleryService()

        XCTAssertEqual(
            service.filteredOutfits([summerFit, fallFit], items: [oliveTop, blueTop],
                                    query: OutfitGalleryQuery(searchText: "oxford", color: .olive, season: .fall))
                .map(\.id),
            [fallFit.id]
        )
    }

    func testFavoritesMostWornAndDeletedFits() {
        let recent = Outfit(dateCreated: Date(timeIntervalSince1970: 200), favorite: true, wearCount: 1)
        let worn = Outfit(dateCreated: Date(timeIntervalSince1970: 100), favorite: true, wearCount: 8)
        let deleted = Outfit(dateCreated: Date(timeIntervalSince1970: 300), dateDeleted: .now,
                             favorite: true, wearCount: 20)
        let result = OutfitGalleryService().filteredOutfits(
            [recent, worn, deleted], items: [],
            query: OutfitGalleryQuery(favoritesOnly: true, sort: .mostWorn)
        )

        XCTAssertEqual(result.map(\.id), [worn.id, recent.id])
    }
}
