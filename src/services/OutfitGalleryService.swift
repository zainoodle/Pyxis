import Foundation

public enum OutfitGallerySort: String, CaseIterable, Identifiable, Sendable {
    case recent
    case mostWorn

    public var id: String { rawValue }
}

public struct OutfitGalleryQuery: Sendable {
    public var searchText: String
    public var favoritesOnly: Bool
    public var color: ClosetColor?
    public var season: Season?
    public var sort: OutfitGallerySort

    public init(
        searchText: String = "",
        favoritesOnly: Bool = false,
        color: ClosetColor? = nil,
        season: Season? = nil,
        sort: OutfitGallerySort = .recent
    ) {
        self.searchText = searchText
        self.favoritesOnly = favoritesOnly
        self.color = color
        self.season = season
        self.sort = sort
    }
}

public struct OutfitGalleryService {
    public init() {}

    public func filteredOutfits(
        _ outfits: [Outfit],
        items: [ClosetItem],
        query: OutfitGalleryQuery
    ) -> [Outfit] {
        let itemByID = Dictionary(uniqueKeysWithValues: items.filter { !$0.isDeleted }.map { ($0.id, $0) })
        let search = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return outfits.filter { outfit in
            guard !outfit.isDeleted else { return false }
            if query.favoritesOnly && !outfit.favorite { return false }
            let pieces = outfit.itemIDs.compactMap { itemByID[$0] }
            if let color = query.color,
               !pieces.contains(where: { $0.primaryColor == color || $0.secondaryColors.contains(color) }) {
                return false
            }
            if let season = query.season,
               !pieces.contains(where: { $0.season.contains(season) || $0.season.contains(.allSeason) }) {
                return false
            }
            if !search.isEmpty {
                let terms = [outfit.name, outfit.notes].compactMap { $0 } + pieces.flatMap { piece in
                    [piece.itemCode, piece.displayName ?? "", piece.brand ?? "", piece.primaryColor.rawValue]
                        + piece.tags
                }
                if !terms.contains(where: { $0.localizedStandardContains(search) }) { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            if query.sort == .mostWorn && lhs.wearCount != rhs.wearCount {
                return lhs.wearCount > rhs.wearCount
            }
            return lhs.dateCreated > rhs.dateCreated
        }
    }
}
