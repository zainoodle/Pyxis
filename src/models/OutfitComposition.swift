import Foundation

/// A resumable working fit. IDs remain stable when the closet is sorted or edited.
public struct OutfitComposition: Codable, Equatable, Sendable {
    public private(set) var selections: [OutfitSlot: UUID]
    public private(set) var keptSlots: Set<OutfitSlot>

    public init(selections: [OutfitSlot: UUID] = [:], keptSlots: Set<OutfitSlot> = []) {
        self.selections = selections
        self.keptSlots = keptSlots.intersection(selections.keys)
    }

    public var draft: OutfitDraft {
        OutfitDraft(
            topItemID: selections[.top], bottomItemID: selections[.bottom],
            onePieceItemID: selections[.onePiece], footwearItemID: selections[.footwear],
            outerwearItemID: selections[.outerwear],
            accessoryItemIDs: selections[.accessory].map { [$0] } ?? []
        )
    }

    /// An explicit Build with this request replaces and keeps its piece while preserving the rest.
    public mutating func begin(with itemID: UUID, for slot: OutfitSlot) {
        let conflicts: Set<OutfitSlot> = switch slot {
        case .onePiece: [.top, .bottom, .onePiece]
        case .top, .bottom: [slot, .onePiece]
        default: [slot]
        }
        keptSlots.subtract(conflicts)
        select(itemID, for: slot)
        keptSlots.insert(slot)
    }

    /// Replacing one piece leaves every other selection untouched.
    @discardableResult
    public mutating func select(_ itemID: UUID, for slot: OutfitSlot) -> Bool {
        guard !keptSlots.contains(slot) || selections[slot] == itemID else { return false }
        let conflicts: [OutfitSlot] = switch slot {
        case .onePiece: [.top, .bottom]
        case .top, .bottom: [.onePiece]
        default: []
        }
        guard conflicts.allSatisfy({ !keptSlots.contains($0) }) else { return false }
        for conflict in conflicts { selections[conflict] = nil }
        selections[slot] = itemID
        return true
    }

    @discardableResult
    public mutating func remove(_ slot: OutfitSlot) -> Bool {
        guard !keptSlots.contains(slot) else { return false }
        selections[slot] = nil
        return true
    }

    public mutating func toggleKeep(_ slot: OutfitSlot) {
        guard selections[slot] != nil else { return }
        if keptSlots.contains(slot) { keptSlots.remove(slot) }
        else { keptSlots.insert(slot) }
    }

    public mutating func reconcile(with items: [ClosetItem]) {
        let available = Dictionary(uniqueKeysWithValues: items.filter { !$0.isDeleted }.map { ($0.id, $0.category) })
        selections = selections.filter { slot, id in available[id] == slot.category }
        keptSlots.formIntersection(selections.keys)
    }
}
