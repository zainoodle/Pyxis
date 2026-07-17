import Foundation

public struct OutfitBuilderService {
    public init() {}

    public func slot(for category: ClothingCategory) -> OutfitSlot? {
        switch category {
        case .tops:
            return .top
        case .bottoms:
            return .bottom
        case .onePiece:
            return .onePiece
        case .footwear:
            return .footwear
        case .outerwear:
            return .outerwear
        case .accessories:
            return .accessory
        case .other:
            return nil
        }
    }

    public func defaultSubtype(for slot: OutfitSlot) -> ClothingSubtype {
        switch slot {
        case .top:
            return .tShirt
        case .bottom:
            return .pants
        case .onePiece:
            return .dress
        case .footwear:
            return .sneakers
        case .outerwear:
            return .jacket
        case .accessory:
            return .bag
        }
    }

    public func requiredRows(from items: [ClosetItem]) -> [OutfitRow] {
        [.top, .bottom, .footwear].map { slot in
            OutfitRow(
                slot: slot,
                items: items
                    .filter { $0.category == slot.category }
                    .sorted { lhs, rhs in
                        if lhs.favorite != rhs.favorite {
                            return lhs.favorite && !rhs.favorite
                        }
                        return lhs.itemCode < rhs.itemCode
                    }
            )
        }
    }

    public func optionalRows(from items: [ClosetItem]) -> [OutfitRow] {
        [.onePiece, .outerwear, .accessory].map { slot in
            OutfitRow(
                slot: slot,
                items: items
                    .filter { $0.category == slot.category }
                    .sorted { $0.itemCode < $1.itemCode }
            )
        }
    }

    public func defaultSelections(for rows: [OutfitRow]) -> [OutfitSlot: Int] {
        var selections = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            row.items.isEmpty ? nil : (row.slot, 0)
        })
        let hasSeparates = selections[.top] != nil && selections[.bottom] != nil
        if hasSeparates {
            selections[.onePiece] = nil
        } else if selections[.onePiece] != nil {
            selections[.top] = nil
            selections[.bottom] = nil
        }
        return selections
    }

    public func selectionTarget(for itemID: UUID, in rows: [OutfitRow]) -> (slot: OutfitSlot, index: Int)? {
        for row in rows {
            if let index = row.items.firstIndex(where: { $0.id == itemID }) {
                return (row.slot, index)
            }
        }

        return nil
    }

    public func advancedIndex(from index: Int?, offset: Int, itemCount: Int) -> Int? {
        guard itemCount > 0 else {
            return nil
        }

        let current = index ?? 0
        return (current + offset + itemCount) % itemCount
    }

    public func draft(from rows: [OutfitRow], selections: [OutfitSlot: Int]) -> OutfitDraft {
        var draft = OutfitDraft()

        for row in rows {
            guard let selectedIndex = selections[row.slot],
                  row.items.indices.contains(selectedIndex)
            else {
                continue
            }

            let itemID = row.items[selectedIndex].id
            switch row.slot {
            case .top:
                draft.topItemID = itemID
            case .bottom:
                draft.bottomItemID = itemID
            case .onePiece:
                draft.onePieceItemID = itemID
            case .footwear:
                draft.footwearItemID = itemID
            case .outerwear:
                draft.outerwearItemID = itemID
            case .accessory:
                draft.accessoryItemIDs = [itemID]
            }
        }

        return draft
    }

    public func canSave(_ draft: OutfitDraft) -> Bool {
        let hasBody = draft.onePieceItemID != nil || (draft.topItemID != nil && draft.bottomItemID != nil)
        return hasBody && draft.footwearItemID != nil
    }

    public func outfit(from draft: OutfitDraft, name: String? = nil, notes: String? = nil) -> Outfit {
        Outfit(
            name: name,
            topItemID: draft.topItemID,
            bottomItemID: draft.bottomItemID,
            onePieceItemID: draft.onePieceItemID,
            footwearItemID: draft.footwearItemID,
            outerwearItemID: draft.outerwearItemID,
            accessoryItemIDs: draft.accessoryItemIDs,
            notes: notes
        )
    }

    public func fitUsageCounts(from outfits: [Outfit]) -> [UUID: Int] {
        outfits.reduce(into: [:]) { counts, outfit in
            for itemID in outfit.itemIDs {
                counts[itemID, default: 0] += 1
            }
        }
    }
}
