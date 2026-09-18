import Foundation
import SwiftData

public enum OnDeviceMemoryKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case closetItem
    case outfit
    case userPreference
    case purchaseCandidate

    public var id: String { rawValue }
}

@Model
public final class OnDeviceMemoryRecord: Identifiable {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var memoryKey: String
    public var kindRawValue: String
    public var subjectID: UUID?
    public var scope: String?
    public var summary: String
    public var embeddingValues: [Double]
    public var metadataTags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: OnDeviceMemoryKind,
        subjectID: UUID?,
        scope: String? = nil,
        summary: String,
        embedding: [Double] = [],
        metadataTags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        let normalizedScope = Self.normalizedScope(scope)
        self.id = id
        self.memoryKey = Self.memoryKey(kind: kind, subjectID: subjectID, scope: normalizedScope)
        self.kindRawValue = kind.rawValue
        self.subjectID = subjectID
        self.scope = normalizedScope
        self.summary = summary
        self.embeddingValues = embedding
        self.metadataTags = metadataTags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var kind: OnDeviceMemoryKind {
        get { OnDeviceMemoryKind(rawValue: kindRawValue) ?? .closetItem }
        set { kindRawValue = newValue.rawValue }
    }

    public var embedding: [Double] {
        get { embeddingValues }
        set { embeddingValues = newValue }
    }

    public static func memoryKey(
        kind: OnDeviceMemoryKind,
        subjectID: UUID?,
        scope: String? = nil
    ) -> String {
        let subjectComponent = subjectID?.uuidString.lowercased() ?? "global"
        guard let scope = normalizedScope(scope) else {
            return "\(kind.rawValue)|\(subjectComponent)"
        }

        return "\(kind.rawValue)|\(subjectComponent)|\(scope)"
    }

    public static func normalizedScope(_ scope: String?) -> String? {
        let trimmedScope = scope?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedScope?.isEmpty == false ? trimmedScope : nil
    }
}
