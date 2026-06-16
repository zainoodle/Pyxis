import Foundation

public enum Season: String, CaseIterable, Codable, Identifiable, Sendable {
    case spring
    case summer
    case fall
    case winter
    case allSeason

    public var id: String { rawValue }
}
