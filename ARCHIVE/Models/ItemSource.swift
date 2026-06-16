import Foundation

public enum ItemSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case owned
    case consideringPurchase

    public var id: String { rawValue }
}
