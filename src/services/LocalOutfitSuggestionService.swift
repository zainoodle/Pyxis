import Foundation

public struct SuggestedLook: Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    public let tags: [String]
    public let draft: OutfitDraft
    public let items: [ClosetItem]

    public init(id: String, title: String, summary: String, tags: [String], draft: OutfitDraft, items: [ClosetItem]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.tags = tags
        self.draft = draft
        self.items = items
    }
}

public struct LocalOutfitSuggestionService {
    public init() {}

    public func suggestions(
        from items: [ClosetItem],
        excluding outfits: [Outfit],
        season: Season? = nil,
        limit: Int = 3
    ) -> [SuggestedLook] {
        guard limit > 0 else { return [] }
        let available = items.filter { !$0.isDeleted && $0.source == .owned }
        let tops = shortlist(available.filter { $0.category == .tops })
        let bottoms = shortlist(available.filter { $0.category == .bottoms })
        let onePieces = shortlist(available.filter { $0.category == .onePiece })
        let shoes = shortlist(available.filter { $0.category == .footwear })
        let layers = shortlist(available.filter { $0.category == .outerwear })
        let accessories = shortlist(available.filter { $0.category == .accessories })
        guard !shoes.isEmpty, (!tops.isEmpty && !bottoms.isEmpty) || !onePieces.isEmpty else { return [] }

        let savedCores = Set(outfits.filter { !$0.isDeleted }.map { outfit in
            coreKey([outfit.topItemID, outfit.bottomItemID, outfit.onePieceItemID, outfit.footwearItemID].compactMap { $0 })
        })
        var candidates: [Candidate] = []

        for top in tops {
            for bottom in bottoms {
                for shoe in shoes {
                    let core = [top, bottom, shoe]
                    let key = coreKey(core.map(\.id))
                    guard !savedCores.contains(key) else { continue }
                    let additions = optionalPieces(for: core, layers: layers, accessories: accessories, season: season)
                    candidates.append(Candidate(
                        key: key,
                        draft: OutfitDraft(topItemID: top.id, bottomItemID: bottom.id, footwearItemID: shoe.id,
                                           outerwearItemID: additions.layer?.id,
                                           accessoryItemIDs: additions.accessory.map { [$0.id] } ?? []),
                        pieces: core + [additions.layer, additions.accessory].compactMap { $0 },
                        score: score(core, season: season) + additions.score
                    ))
                }
            }
        }

        for onePiece in onePieces {
            for shoe in shoes {
                let core = [onePiece, shoe]
                let key = coreKey(core.map(\.id))
                guard !savedCores.contains(key) else { continue }
                let additions = optionalPieces(for: core, layers: layers, accessories: accessories, season: season)
                candidates.append(Candidate(
                    key: key,
                    draft: OutfitDraft(onePieceItemID: onePiece.id, footwearItemID: shoe.id,
                                       outerwearItemID: additions.layer?.id,
                                       accessoryItemIDs: additions.accessory.map { [$0.id] } ?? []),
                    pieces: core + [additions.layer, additions.accessory].compactMap { $0 },
                    score: score(core, season: season) + additions.score
                ))
            }
        }

        candidates.sort { lhs, rhs in
            lhs.score == rhs.score ? lhs.key < rhs.key : lhs.score > rhs.score
        }
        var usedLeadingPieces: Set<UUID> = []
        var selected: [Candidate] = []
        for candidate in candidates where selected.count < limit {
            let leadingID = candidate.pieces[0].id
            guard !usedLeadingPieces.contains(leadingID) else { continue }
            usedLeadingPieces.insert(leadingID)
            selected.append(candidate)
        }
        for candidate in candidates where selected.count < limit && !selected.contains(where: { $0.key == candidate.key }) {
            selected.append(candidate)
        }

        let titles = ["SOFT STRUCTURE", "CITY LAYERS", "WEEKEND MODE"]
        return selected.enumerated().map { index, candidate in
            let colors = Array(NSOrderedSet(array: candidate.pieces.map { $0.primaryColor.rawValue }))
                .compactMap { $0 as? String }
                .filter { $0 != ClosetColor.unknown.rawValue }
            let palette = colors.prefix(2).joined(separator: " AND ").uppercased()
            let summary = palette.isEmpty
                ? "A FRESH COMBINATION FROM PIECES YOU ALREADY OWN."
                : "A \(palette) PALETTE FROM PIECES YOU ALREADY OWN."
            return SuggestedLook(
                id: candidate.key,
                title: titles[index % titles.count],
                summary: summary,
                tags: ["FROM YOUR CLOSET", "\(candidate.pieces.count) PIECES"],
                draft: candidate.draft,
                items: candidate.pieces
            )
        }
    }

    private func shortlist(_ items: [ClosetItem]) -> [ClosetItem] {
        Array(items.sorted { lhs, rhs in
            if lhs.favorite != rhs.favorite { return lhs.favorite }
            if lhs.wearCount != rhs.wearCount { return lhs.wearCount < rhs.wearCount }
            return lhs.itemCode < rhs.itemCode
        }.prefix(10))
    }

    private func optionalPieces(
        for core: [ClosetItem], layers: [ClosetItem], accessories: [ClosetItem], season: Season?
    ) -> (layer: ClosetItem?, accessory: ClosetItem?, score: Double) {
        let layer = layers.max { match($0, to: core, season: season) < match($1, to: core, season: season) }
        let accessory = accessories.max { match($0, to: core, season: season) < match($1, to: core, season: season) }
        return (layer, accessory, [layer, accessory].compactMap { $0 }.reduce(0) { $0 + match($1, to: core, season: season) * 0.1 })
    }

    private func score(_ items: [ClosetItem], season: Season?) -> Double {
        let colors = items.map(\.primaryColor)
        let neutralCount = colors.filter { isNeutral($0) }.count
        let matchingCount = colors.filter { $0 == colors.first }.count
        return items.reduce(0) { score, item in
            score + (item.favorite ? 2 : 0) + (item.wearCount == 0 ? 1.5 : 0)
                - Double(min(item.wearCount, 20)) * 0.12
                + (season.map { item.season.isEmpty || item.season.contains(.allSeason) || item.season.contains($0) } == true ? 2 : 0)
        } + Double(neutralCount) * 0.6 + Double(matchingCount) * 0.5
    }

    private func match(_ item: ClosetItem, to core: [ClosetItem], season: Season?) -> Double {
        var value = score([item], season: season)
        if core.contains(where: { $0.primaryColor == item.primaryColor }) { value += 3 }
        if isNeutral(item.primaryColor) { value += 2 }
        return value
    }

    private func isNeutral(_ color: ClosetColor) -> Bool {
        [.black, .white, .gray, .cream, .brown, .tan, .navy].contains(color)
    }

    private func coreKey(_ ids: [UUID]) -> String { ids.map(\.uuidString).sorted().joined(separator: ":") }

    private struct Candidate {
        let key: String
        let draft: OutfitDraft
        let pieces: [ClosetItem]
        let score: Double
    }
}
