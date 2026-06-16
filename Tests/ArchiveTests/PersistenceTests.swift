import SwiftData
import XCTest
@testable import ArchiveCore

@MainActor
final class PersistenceTests: XCTestCase {
    func testInsertsAndFetchesClosetItem() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let item = ClosetItem(
            itemCode: "TS-001",
            displayName: "White tee",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .white,
            imageOriginalPath: "Images/Originals/item.jpg"
        )

        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<ClosetItem>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.itemCode, "TS-001")
        XCTAssertEqual(fetched.first?.category, .tops)
        XCTAssertEqual(fetched.first?.subtype, .tShirt)
        XCTAssertEqual(fetched.first?.primaryColor, .white)
    }

    func testUpdatesAndRefetchesClosetItemMetadata() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let item = ClosetItem(
            itemCode: "HD-001",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .gray,
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )

        context.insert(item)
        try context.save()

        item.displayName = "Heavy hoodie"
        item.brand = "Local"
        item.tags = ["winter", "cotton"]
        item.notes = "Washed cold"
        item.size = "M"
        item.favorite = true
        item.wearCount = 3
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ClosetItem>())

        XCTAssertEqual(fetched.first?.displayName, "Heavy hoodie")
        XCTAssertEqual(fetched.first?.brand, "Local")
        XCTAssertEqual(fetched.first?.tags, ["winter", "cotton"])
        XCTAssertEqual(fetched.first?.notes, "Washed cold")
        XCTAssertEqual(fetched.first?.size, "M")
        XCTAssertEqual(fetched.first?.favorite, true)
        XCTAssertEqual(fetched.first?.wearCount, 3)
    }

    func testDeletesClosetItem() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let item = ClosetItem(
            itemCode: "JE-001",
            category: .bottoms,
            subtype: .jeans,
            primaryColor: .blue,
            imageOriginalPath: "Images/Originals/jeans.jpg"
        )

        context.insert(item)
        try context.save()
        context.delete(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ClosetItem>())

        XCTAssertTrue(fetched.isEmpty)
    }

    func testInsertsAndFetchesSavedOutfit() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let topID = UUID()
        let bottomID = UUID()
        let footwearID = UUID()
        let outfit = Outfit(
            name: "Friday",
            topItemID: topID,
            bottomItemID: bottomID,
            footwearItemID: footwearID,
            notes: "Simple daily fit"
        )

        context.insert(outfit)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Outfit>())

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Friday")
        XCTAssertEqual(fetched.first?.topItemID, topID)
        XCTAssertEqual(fetched.first?.bottomItemID, bottomID)
        XCTAssertEqual(fetched.first?.footwearItemID, footwearID)
        XCTAssertEqual(fetched.first?.notes, "Simple daily fit")
    }
}
