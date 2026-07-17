import SwiftData
import XCTest
@testable import PyxisCore

@MainActor
final class PersistenceTests: XCTestCase {
    func testInsertsAndFetchesBodyProfile() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let profile = BodyProfile(
            measurementSystem: .metric,
            fitPreference: .relaxed,
            heightCentimeters: 180,
            weightKilograms: 78,
            chestCentimeters: 102,
            waistCentimeters: 84
        )

        context.insert(profile)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<BodyProfile>()).first)
        XCTAssertEqual(fetched.measurementSystem, .metric)
        XCTAssertEqual(fetched.fitPreference, .relaxed)
        XCTAssertEqual(fetched.heightCentimeters, 180)
        XCTAssertEqual(fetched.chestCentimeters, 102)
    }

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
        XCTAssertEqual(fetched.first?.effectiveDateUpdated, fetched.first?.dateAdded)
        XCTAssertNil(fetched.first?.dateDeleted)
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
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        item.touch(date: updatedAt)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ClosetItem>())

        XCTAssertEqual(fetched.first?.displayName, "Heavy hoodie")
        XCTAssertEqual(fetched.first?.brand, "Local")
        XCTAssertEqual(fetched.first?.tags, ["winter", "cotton"])
        XCTAssertEqual(fetched.first?.notes, "Washed cold")
        XCTAssertEqual(fetched.first?.size, "M")
        XCTAssertEqual(fetched.first?.favorite, true)
        XCTAssertEqual(fetched.first?.wearCount, 3)
        XCTAssertEqual(fetched.first?.effectiveDateUpdated, updatedAt)
    }

    func testMarksPersistedModelsDeletedWithoutRemovingThem() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let deletedAt = Date(timeIntervalSince1970: 2_000)
        let item = ClosetItem(
            itemCode: "BT-001",
            category: .footwear,
            subtype: .boots,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/boots.jpg"
        )
        let closet = Closet(name: "Archive")
        let outfit = Outfit(name: "Rain day", footwearItemID: item.id)

        context.insert(item)
        context.insert(closet)
        context.insert(outfit)
        item.markDeleted(date: deletedAt)
        closet.markDeleted(date: deletedAt)
        outfit.markDeleted(date: deletedAt)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<ClosetItem>()).first?.dateDeleted, deletedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Closet>()).first?.dateDeleted, deletedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Outfit>()).first?.dateDeleted, deletedAt)
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

    func testInsertsAndFetchesCustomCloset() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000301"))
        let closet = Closet(name: "Dinner Clothes", itemIDs: [itemID])

        context.insert(closet)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Closet>())

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Dinner Clothes")
        XCTAssertEqual(fetched.first?.itemIDs, [itemID])
    }

    func testCurrentSchemaOpensStoreCreatedBeforeOnDeviceMemoryModel() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            removeStoreFiles(at: storeURL)
        }

        let legacySchema = Schema([
            ClosetItem.self,
            Outfit.self,
            Closet.self
        ])
        let legacyConfiguration = ModelConfiguration(
            "Pyxis",
            schema: legacySchema,
            url: storeURL
        )
        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: [legacyConfiguration]
        )
        let legacyContext = ModelContext(legacyContainer)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000501"))
        legacyContext.insert(
            ClosetItem(
                id: itemID,
                itemCode: "HD-501",
                displayName: "Legacy hoodie",
                category: .tops,
                subtype: .hoodie,
                primaryColor: .black,
                imageOriginalPath: "Images/Originals/legacy-hoodie.jpg"
            )
        )
        try legacyContext.save()

        let currentContainer = try SwiftDataContainer.makeContainer(
            isStoredInMemoryOnly: false,
            storeURL: storeURL
        )
        let currentContext = ModelContext(currentContainer)
        let fetchedItems = try currentContext.fetch(FetchDescriptor<ClosetItem>())

        XCTAssertEqual(fetchedItems.map(\.itemCode), ["HD-501"])

        let store = OnDeviceMemoryStore(context: currentContext)
        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Legacy hoodie memory",
            embedding: [1, 0, 0],
            metadataTags: ["legacy"],
            updatedAt: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(try store.memories(kind: .closetItem, subjectID: itemID).count, 1)
    }

    private func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let paths = [
            storeURL.path,
            "\(storeURL.path)-shm",
            "\(storeURL.path)-wal"
        ]
        for path in paths {
            try? fileManager.removeItem(atPath: path)
        }
    }
}
