import Foundation

/// One local working draft, separate from the versioned SwiftData wardrobe store.
public struct OutfitDraftStore {
    private let defaults: UserDefaults
    private let key = "pyxis.outfitComposition.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() throws -> OutfitComposition? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(OutfitComposition.self, from: data)
    }

    public func save(_ composition: OutfitComposition) throws {
        defaults.set(try JSONEncoder().encode(composition), forKey: key)
    }

    public func clear() { defaults.removeObject(forKey: key) }
}
