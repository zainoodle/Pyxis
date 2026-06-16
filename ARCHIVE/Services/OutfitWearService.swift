import Foundation

public struct OutfitWearService {
    public init() {}

    public func markWorn(outfit: Outfit, items: [ClosetItem], on date: Date = .now) {
        outfit.markWorn(on: date)
        let itemIDs = Set(outfit.itemIDs)

        for item in items where itemIDs.contains(item.id) {
            item.wearCount += 1
            item.lastWornDate = date
        }
    }
}
