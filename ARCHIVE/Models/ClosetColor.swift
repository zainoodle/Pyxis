import Foundation

public enum ClosetColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case black
    case white
    case gray
    case cream
    case brown
    case tan
    case navy
    case blue
    case green
    case olive
    case red
    case burgundy
    case pink
    case purple
    case yellow
    case orange
    case multicolor
    case unknown

    public var id: String { rawValue }
}
