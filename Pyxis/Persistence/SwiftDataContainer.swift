import Foundation
import SwiftData

public enum SwiftDataContainer {
    public static func makeAppContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    public static func makeTestContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    public static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([
            ClosetItem.self,
            Outfit.self,
            Closet.self
        ])
        let configuration = ModelConfiguration(
            "Pyxis",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
