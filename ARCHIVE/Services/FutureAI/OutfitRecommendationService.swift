import Foundation

public struct OutfitRecommendationContext {
    public let items: [ClosetItem]
    public let season: Season?

    public init(items: [ClosetItem], season: Season? = nil) {
        self.items = items
        self.season = season
    }
}

public protocol OutfitRecommendationService {
    func recommendations(for context: OutfitRecommendationContext) async throws -> [UUID]
}
