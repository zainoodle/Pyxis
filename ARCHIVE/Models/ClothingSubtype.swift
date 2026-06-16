import Foundation

public enum ClothingSubtype: String, CaseIterable, Codable, Identifiable, Sendable {
    case tShirt
    case longSleeve
    case shirt
    case hoodie
    case crewneck
    case sweater
    case jacket
    case coat
    case jeans
    case pants
    case shorts
    case skirt
    case dress
    case sneakers
    case boots
    case slides
    case sandals
    case hat
    case bag
    case belt
    case jewelry
    case other

    public var id: String { rawValue }
}
