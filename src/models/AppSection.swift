import Foundation

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case closet
    case build
    case fits
    case profile

    public var id: String { rawValue }

    public var title: String { rawValue.uppercased() }

    public var systemImage: String {
        switch self {
        case .closet: "square.grid.2x2"
        case .build: "square.stack.3d.up"
        case .fits: "photo.on.rectangle.angled"
        case .profile: "person.crop.circle"
        }
    }
}
