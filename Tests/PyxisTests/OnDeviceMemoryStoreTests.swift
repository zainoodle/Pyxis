import SwiftData
import XCTest
@testable import PyxisCore

@MainActor
final class OnDeviceMemoryStoreTests: XCTestCase {
    func testBuildsClosetItemMemoryPayloadFromItemMetadata() throws {
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000410"))
        let item = ClosetItem(
            id: itemID,
            itemCode: "HD-410",
            displayName: "Black travel hoodie",
            category: .tops,
            subtype: .hoodie,
            primaryColor: .black,
            tags: ["travel", "Layer"],
            notes: "Works with denim",
            brand: "Pyxis",
            size: "M",
            favorite: true,
            imageOriginalPath: "Images/Originals/hoodie.jpg"
        )

        let payload = OnDeviceMemoryPayloadBuilder.closetItemPayload(for: item)

        XCTAssertTrue(payload.summary.contains("Black travel hoodie"))
        XCTAssertTrue(payload.summary.contains("Brand: Pyxis"))
        XCTAssertTrue(payload.summary.contains("Works with denim"))
        XCTAssertEqual(payload.metadataTags, ["closet item", "tops", "hoodie", "black", "pyxis", "favorite", "travel", "layer"])
        XCTAssertEqual(payload.embedding.count, OnDeviceMemoryPayloadBuilder.embeddingDimensions)
        XCTAssertEqual(vectorMagnitude(payload.embedding), 1, accuracy: 0.0001)
        XCTAssertTrue(payload.embedding.allSatisfy(\.isFinite))
    }

    func testBuildsOutfitMemoryPayloadFromSelectedItems() throws {
        let topID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000411"))
        let bottomID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000412"))
        let top = ClosetItem(
            id: topID,
            itemCode: "TS-411",
            displayName: "White tee",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .white,
            tags: ["daily"],
            imageOriginalPath: "Images/Originals/tee.jpg"
        )
        let bottom = ClosetItem(
            id: bottomID,
            itemCode: "JE-412",
            displayName: "Blue jeans",
            category: .bottoms,
            subtype: .jeans,
            primaryColor: .blue,
            tags: ["denim"],
            imageOriginalPath: "Images/Originals/jeans.jpg"
        )
        let outfit = Outfit(
            name: "Friday fit",
            topItemID: topID,
            bottomItemID: bottomID,
            favorite: true,
            notes: "Casual office day",
            wearCount: 2
        )

        let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: [bottom, top])

        XCTAssertTrue(payload.summary.contains("Friday fit"))
        XCTAssertTrue(payload.summary.contains("White tee, Blue jeans"))
        XCTAssertTrue(payload.summary.contains("Casual office day"))
        XCTAssertTrue(payload.summary.contains("Worn 2 times"))
        XCTAssertEqual(payload.metadataTags, ["outfit", "favorite", "tops", "tshirt", "white", "daily", "bottoms", "jeans", "blue", "denim"])
        XCTAssertEqual(payload.embedding.count, OnDeviceMemoryPayloadBuilder.embeddingDimensions)
        XCTAssertEqual(vectorMagnitude(payload.embedding), 1, accuracy: 0.0001)
    }

    func testClosetItemPayloadPersistsAndRanksLocally() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000413"))
        let item = ClosetItem(
            id: itemID,
            itemCode: "BT-413",
            displayName: "Black boots",
            category: .footwear,
            subtype: .boots,
            primaryColor: .black,
            tags: ["winter"],
            imageOriginalPath: "Images/Originals/boots.jpg"
        )
        let payload = OnDeviceMemoryPayloadBuilder.closetItemPayload(for: item)

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: item.id,
            summary: payload.summary,
            embedding: payload.embedding,
            metadataTags: payload.metadataTags
        )

        let nearest = try store.nearestMemories(
            to: payload.embedding,
            kind: .closetItem,
            limit: 1
        )

        XCTAssertEqual(nearest.map(\.memory.subjectID), [itemID])
        XCTAssertGreaterThan(nearest.first?.score ?? 0, 0.999)
    }

    func testPersistsAndFetchesItemMemoryOnDevice() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Black hoodie, warm, works with denim",
            embedding: [0.25, 0.5, 0.75],
            metadataTags: ["tops", "hoodie", "black"],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let fetched = try store.memories(kind: .closetItem, subjectID: itemID)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.kind, .closetItem)
        XCTAssertEqual(fetched.first?.subjectID, itemID)
        XCTAssertEqual(fetched.first?.summary, "Black hoodie, warm, works with denim")
        XCTAssertEqual(fetched.first?.embedding, [0.25, 0.5, 0.75])
        XCTAssertEqual(fetched.first?.metadataTags, ["tops", "hoodie", "black"])
        XCTAssertEqual(fetched.first?.updatedAt, Date(timeIntervalSince1970: 100))
    }

    func testSanitizesMemoryBeforeSaving() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000407"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "  Black hoodie memory  ",
            embedding: [0.25, 0.5],
            metadataTags: [" hoodie ", "Hoodie", "", "black"],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let fetched = try XCTUnwrap(store.memory(kind: .closetItem, subjectID: itemID))
        XCTAssertEqual(fetched.summary, "Black hoodie memory")
        XCTAssertEqual(fetched.metadataTags, ["hoodie", "black"])
    }

    func testUpsertReusesMemoryForSameKindAndSubject() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000402"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Initial memory",
            embedding: [1, 0],
            metadataTags: ["initial"],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Updated memory",
            embedding: [0, 1],
            metadataTags: ["updated"],
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let fetched = try store.memories(kind: .closetItem, subjectID: itemID)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.summary, "Updated memory")
        XCTAssertEqual(fetched.first?.embedding, [0, 1])
        XCTAssertEqual(fetched.first?.metadataTags, ["updated"])
        XCTAssertEqual(fetched.first?.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(fetched.first?.updatedAt, Date(timeIntervalSince1970: 200))
    }

    func testScopedGlobalMemoriesStaySeparate() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)

        try store.upsertMemory(
            kind: .userPreference,
            subjectID: nil,
            scope: "colors",
            summary: "Prefers black and cream",
            embedding: [1, 0],
            metadataTags: ["palette"],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try store.upsertMemory(
            kind: .userPreference,
            subjectID: nil,
            scope: "fit",
            summary: "Prefers relaxed silhouettes",
            embedding: [0, 1],
            metadataTags: ["silhouette"],
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let memories = try store.memories(kind: .userPreference, subjectID: nil)
        XCTAssertEqual(memories.map(\.scope), ["fit", "colors"])
        XCTAssertEqual(
            try store.memory(kind: .userPreference, subjectID: nil, scope: "colors")?.summary,
            "Prefers black and cream"
        )
    }

    func testRejectsEmptySummaryAndNonFiniteEmbeddings() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)

        XCTAssertThrowsError(
            try store.upsertMemory(
                kind: .userPreference,
                subjectID: nil,
                summary: "   ",
                embedding: [1],
                metadataTags: []
            )
        ) { error in
            XCTAssertEqual(error as? OnDeviceMemoryStoreError, .emptySummary)
        }

        XCTAssertThrowsError(
            try store.upsertMemory(
                kind: .userPreference,
                subjectID: nil,
                summary: "Bad vector",
                embedding: [.nan],
                metadataTags: []
            )
        ) { error in
            XCTAssertEqual(error as? OnDeviceMemoryStoreError, .nonFiniteEmbedding)
        }

        XCTAssertTrue(try store.memories(kind: .userPreference).isEmpty)
    }

    func testNearestMemoriesAreRankedByLocalEmbeddingSimilarity() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let closeID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000403"))
        let farID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000404"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: closeID,
            summary: "Mostly black hoodie",
            embedding: [0.95, 0.05],
            metadataTags: [],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try store.upsertMemory(
            kind: .closetItem,
            subjectID: farID,
            summary: "Bright white sneakers",
            embedding: [0.05, 0.95],
            metadataTags: [],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let nearest = try store.nearestMemories(
            to: [1, 0],
            kind: .closetItem,
            limit: 1
        )

        XCTAssertEqual(nearest.map(\.memory.subjectID), [closeID])
        XCTAssertGreaterThan(nearest.first?.score ?? 0, 0.99)
    }

    func testDeletesMemoriesForSubject() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let deletedID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000405"))
        let keptID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000406"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: deletedID,
            summary: "Delete this",
            embedding: [1],
            metadataTags: [],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try store.upsertMemory(
            kind: .closetItem,
            subjectID: keptID,
            summary: "Keep this",
            embedding: [1],
            metadataTags: [],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try store.deleteMemories(subjectID: deletedID)

        XCTAssertTrue(try store.memories(kind: .closetItem, subjectID: deletedID).isEmpty)
        XCTAssertEqual(try store.memories(kind: .closetItem, subjectID: keptID).count, 1)
    }

    func testDeferredDeleteCanRollbackWithSurroundingTransaction() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000408"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Transactional memory",
            embedding: [1],
            metadataTags: [],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try store.deleteMemories(subjectID: itemID, saveImmediately: false)
        context.rollback()

        XCTAssertEqual(try store.memories(kind: .closetItem, subjectID: itemID).count, 1)
    }

    func testDeferredUpsertCanRollbackWithSurroundingTransaction() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000409"))

        try store.upsertMemory(
            kind: .closetItem,
            subjectID: itemID,
            summary: "Draft transaction memory",
            embedding: [1],
            metadataTags: [],
            saveImmediately: false
        )
        context.rollback()

        XCTAssertTrue(try store.memories(kind: .closetItem, subjectID: itemID).isEmpty)
    }

    func testDeletesAllMemories() throws {
        let container = try SwiftDataContainer.makeTestContainer()
        let context = ModelContext(container)
        let store = OnDeviceMemoryStore(context: context)

        try store.upsertMemory(
            kind: .userPreference,
            subjectID: nil,
            scope: "colors",
            summary: "Prefers black",
            embedding: [1],
            metadataTags: []
        )
        try store.upsertMemory(
            kind: .purchaseCandidate,
            subjectID: UUID(),
            summary: "Possible boot purchase",
            embedding: [1],
            metadataTags: []
        )

        try store.deleteAllMemories()

        XCTAssertTrue(try store.memories(kind: .userPreference).isEmpty)
        XCTAssertTrue(try store.memories(kind: .purchaseCandidate).isEmpty)
    }

    private func vectorMagnitude(_ vector: [Double]) -> Double {
        sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
    }
}
