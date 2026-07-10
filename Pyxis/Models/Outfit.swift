import Foundation
import SwiftData

public enum OutfitSlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case top
    case bottom
    case footwear
    case outerwear
    case accessory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .top:
            return "SHIRT"
        case .bottom:
            return "PANTS"
        case .footwear:
            return "SHOES"
        case .outerwear:
            return "OUTERWEAR"
        case .accessory:
            return "ACCESSORY"
        }
    }

    public var category: ClothingCategory {
        switch self {
        case .top:
            return .tops
        case .bottom:
            return .bottoms
        case .footwear:
            return .footwear
        case .outerwear:
            return .outerwear
        case .accessory:
            return .accessories
        }
    }
}

public struct OutfitDraft: Equatable, Sendable {
    public var topItemID: UUID?
    public var bottomItemID: UUID?
    public var footwearItemID: UUID?
    public var outerwearItemID: UUID?
    public var accessoryItemIDs: [UUID]

    public init(
        topItemID: UUID? = nil,
        bottomItemID: UUID? = nil,
        footwearItemID: UUID? = nil,
        outerwearItemID: UUID? = nil,
        accessoryItemIDs: [UUID] = []
    ) {
        self.topItemID = topItemID
        self.bottomItemID = bottomItemID
        self.footwearItemID = footwearItemID
        self.outerwearItemID = outerwearItemID
        self.accessoryItemIDs = accessoryItemIDs
    }
}

public struct OutfitRow: Identifiable {
    public var id: OutfitSlot { slot }
    public let slot: OutfitSlot
    public let items: [ClosetItem]

    public init(slot: OutfitSlot, items: [ClosetItem]) {
        self.slot = slot
        self.items = items
    }
}

@Model
public final class Outfit: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var name: String?
    public var topItemID: UUID?
    public var bottomItemID: UUID?
    public var footwearItemID: UUID?
    public var outerwearItemID: UUID?
    public var accessoryItemIDs: [UUID]
    public var dateCreated: Date
    public var dateUpdated: Date
    public var dateDeleted: Date?
    public var favorite: Bool
    public var notes: String?
    public var lastWornDate: Date?
    public var wearCount: Int

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        topItemID: UUID? = nil,
        bottomItemID: UUID? = nil,
        footwearItemID: UUID? = nil,
        outerwearItemID: UUID? = nil,
        accessoryItemIDs: [UUID] = [],
        dateCreated: Date = .now,
        dateUpdated: Date = .now,
        dateDeleted: Date? = nil,
        favorite: Bool = false,
        notes: String? = nil,
        lastWornDate: Date? = nil,
        wearCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.topItemID = topItemID
        self.bottomItemID = bottomItemID
        self.footwearItemID = footwearItemID
        self.outerwearItemID = outerwearItemID
        self.accessoryItemIDs = accessoryItemIDs
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.dateDeleted = dateDeleted
        self.favorite = favorite
        self.notes = notes
        self.lastWornDate = lastWornDate
        self.wearCount = wearCount
    }

    public var itemIDs: [UUID] {
        [topItemID, bottomItemID, footwearItemID, outerwearItemID].compactMap { $0 } + accessoryItemIDs
    }

    public var isDeleted: Bool {
        dateDeleted != nil
    }

    public func markWorn(on date: Date = .now) {
        wearCount += 1
        lastWornDate = date
        touch(date: date)
    }

    public func touch(date: Date = .now) {
        dateUpdated = date
    }

    public func markDeleted(date: Date = .now) {
        dateDeleted = date
        touch(date: date)
    }
}
