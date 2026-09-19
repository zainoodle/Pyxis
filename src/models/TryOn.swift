import Foundation

public struct TryOnGarment: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var imageURL: URL
    public var category: ClothingCategory
    public var name: String
    public init(id: UUID = UUID(), imageURL: URL, category: ClothingCategory, name: String) {
        self.id = id; self.imageURL = imageURL; self.category = category; self.name = name
    }
}

public struct TryOnConfiguration: Codable, Equatable, Sendable {
    public var available: Bool
    public var limit: Int
    public var consentVersion: String
    public var provider: String
    public var retention: String
    public var productID: String?
    public var supportsPrivacyContract: Bool {
        consentVersion == TryOnPrivacy.version && provider == "xAI" && retention == "zero"
    }
}

public struct TryOnAllowance: Codable, Equatable, Sendable {
    public var limit: Int
    public var remaining: Int
    public var renewsAt: Double
    public var renewalDate: Date { Date(timeIntervalSince1970: renewsAt / 1000) }
}

public struct TryOnResult: Sendable {
    public var imageData: Data
    public var allowance: TryOnAllowance
}

public struct SavedTryOn: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let garmentNames: [String]
    public var filename: String { "\(id.uuidString).jpg" }
}

public enum TryOnPrivacy {
    public static let version = "try-on-xai-zdr-v1"
    public static let title = "Your photos, used for your try-on"
    public static let disclosure = "Your reference photo and selected clothing images are sent through Pyxis to xAI to create your preview. Pyxis requires zero-retention processing: photo inputs and outputs are not persistently stored by xAI, and we do not authorize their use for model training. Pyxis keeps purchase and usage records to manage your allowance. Saved photos and previews stay on this device."
    public static let fitDisclaimer = "A visual preview, not a size or fit guarantee."
}

public enum TryOnError: LocalizedError, Equatable {
    case unavailable, invalidResponse, consentRequired, purchaseRequired, invalidImage, limitReached, storageVersion, alreadyGenerated
    case server(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Try-on is not available yet. You can still choose clothing and view saved previews."
        case .invalidResponse: return "The preview could not be opened. Check your allowance before generating another."
        case .consentRequired: return "Please review how your photos are processed before generating."
        case .purchaseRequired: return "A try-on subscription is required."
        case .invalidImage: return "This photo could not be opened. Choose another image."
        case .limitReached: return "You have used this month’s try-ons. Your saved previews are still available."
        case .alreadyGenerated: return "Your previous preview finished but could not be recovered. Starting another uses one more try-on."
        case .storageVersion: return "These previews were saved by a newer version of Pyxis. Update the app to open them."
        case .server(let message): return message
        }
    }
}
