import XCTest
@testable import PyxisCore

final class FilteringTests: XCTestCase {
    func testSearchMatchesCodeDisplayNameBrandNotesTagsCategorySubtypeAndColor() {
        let item = ClosetItem(
            itemCode: "HD-001",
            displayName: "Heavy Fleece",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .gray,
            tags: ["winter"],
            notes: "washed cold",
            brand: "ARCH",
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )
        let service = ClosetFilteringService()

        for query in ["HD-001", "heavy", "arch", "washed", "winter", "tops", "hoodie", "gray"] {
            let result = service.filteredItems([item], state: ClosetFilterState(searchText: query))
            XCTAssertEqual(result.map(\.itemCode), ["HD-001"], "Expected query \(query) to match")
        }
    }

    func testFiltersByCategorySubtypeColorAndFavorite() {
        let favoriteHoodie = ClosetItem(
            itemCode: "HD-001",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .black,
            favorite: true,
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )
        let jeans = ClosetItem(
            itemCode: "JE-001",
            category: .bottoms,
            subtype: .jeans,
            primaryColor: .blue,
            imageOriginalPath: "Images/Originals/jeans.jpg"
        )
        let state = ClosetFilterState(
            category: .tops,
            subtype: .hoodie,
            color: .black,
            favoritesOnly: true
        )

        let result = ClosetFilteringService().filteredItems([favoriteHoodie, jeans], state: state)

        XCTAssertEqual(result.map(\.itemCode), ["HD-001"])
    }

    func testFiltersBySelectedCustomCloset() throws {
        let hoodie = ClosetItem(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000101")),
            itemCode: "HD-001",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )
        let jeans = ClosetItem(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000102")),
            itemCode: "JE-001",
            category: .bottoms,
            subtype: .jeans,
            primaryColor: .blue,
            imageOriginalPath: "Images/Originals/jeans.jpg"
        )
        let goingOut = Closet(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000201")),
            name: "Going Out",
            itemIDs: [hoodie.id]
        )

        let result = ClosetFilteringService().filteredItems(
            [hoodie, jeans],
            state: ClosetFilterState(closetID: goingOut.id),
            closets: [goingOut]
        )

        XCTAssertEqual(result.map(\.itemCode), ["HD-001"])
    }

    func testSortsByNewestCategoryColorAndMostWorn() {
        let oldMostWorn = ClosetItem(
            itemCode: "JE-001",
            category: .bottoms,
            subtype: .jeans,
            primaryColor: .blue,
            dateAdded: Date(timeIntervalSince1970: 10),
            wearCount: 8,
            imageOriginalPath: "Images/Originals/jeans.jpg"
        )
        let newLeastWorn = ClosetItem(
            itemCode: "HD-001",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .black,
            dateAdded: Date(timeIntervalSince1970: 20),
            wearCount: 1,
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )
        let items = [oldMostWorn, newLeastWorn]
        let service = ClosetFilteringService()

        XCTAssertEqual(service.filteredItems(items, state: ClosetFilterState(sort: .newest)).map(\.itemCode), ["HD-001", "JE-001"])
        XCTAssertEqual(service.filteredItems(items, state: ClosetFilterState(sort: .category)).map(\.itemCode), ["JE-001", "HD-001"])
        XCTAssertEqual(service.filteredItems(items, state: ClosetFilterState(sort: .color)).map(\.itemCode), ["HD-001", "JE-001"])
        XCTAssertEqual(service.filteredItems(items, state: ClosetFilterState(sort: .mostWorn)).map(\.itemCode), ["JE-001", "HD-001"])
    }
}
