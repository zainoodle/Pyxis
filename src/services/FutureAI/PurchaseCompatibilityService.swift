import Foundation

public struct PurchaseCompatibilityContext {
    public let candidateItem: ClosetItem
    public let ownedItems: [ClosetItem]

    public init(candidateItem: ClosetItem, ownedItems: [ClosetItem]) {
        self.candidateItem = candidateItem
        self.ownedItems = ownedItems
    }
}

public protocol PurchaseCompatibilityService {
    func compatibleOwnedItemIDs(for context: PurchaseCompatibilityContext) async throws -> [UUID]
}
