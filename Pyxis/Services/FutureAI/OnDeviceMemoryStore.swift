import Foundation
import SwiftData

public struct OnDeviceMemoryMatch {
    public let memory: OnDeviceMemoryRecord
    public let score: Double
}

public enum OnDeviceMemoryStoreError: Error, Equatable {
    case emptySummary
    case nonFiniteEmbedding
}

@MainActor
public final class OnDeviceMemoryStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func upsertMemory(
        kind: OnDeviceMemoryKind,
        subjectID: UUID?,
        scope: String? = nil,
        summary: String,
        embedding: [Double] = [],
        metadataTags: [String] = [],
        updatedAt: Date = .now,
        saveImmediately: Bool = true
    ) throws -> OnDeviceMemoryRecord {
        let sanitizedSummary = try sanitizedSummary(summary)
        let sanitizedEmbedding = try sanitizedEmbedding(embedding)
        let sanitizedTags = sanitizedMetadataTags(metadataTags)
        let normalizedScope = OnDeviceMemoryRecord.normalizedScope(scope)
        let memoryKey = OnDeviceMemoryRecord.memoryKey(
            kind: kind,
            subjectID: subjectID,
            scope: normalizedScope
        )

        if let existing = try memory(withKey: memoryKey) {
            existing.kind = kind
            existing.subjectID = subjectID
            existing.scope = normalizedScope
            existing.summary = sanitizedSummary
            existing.embedding = sanitizedEmbedding
            existing.metadataTags = sanitizedTags
            existing.updatedAt = updatedAt
            if saveImmediately {
                try context.save()
            }
            return existing
        }

        let memory = OnDeviceMemoryRecord(
            kind: kind,
            subjectID: subjectID,
            scope: normalizedScope,
            summary: sanitizedSummary,
            embedding: sanitizedEmbedding,
            metadataTags: sanitizedTags,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
        context.insert(memory)
        if saveImmediately {
            try context.save()
        }
        return memory
    }

    public func memories(
        kind: OnDeviceMemoryKind,
        subjectID: UUID?
    ) throws -> [OnDeviceMemoryRecord] {
        try memories(kind: kind)
            .filter { $0.subjectID == subjectID }
    }

    public func memory(
        kind: OnDeviceMemoryKind,
        subjectID: UUID?,
        scope: String? = nil
    ) throws -> OnDeviceMemoryRecord? {
        let memoryKey = OnDeviceMemoryRecord.memoryKey(
            kind: kind,
            subjectID: subjectID,
            scope: scope
        )
        return try memory(withKey: memoryKey)
    }

    public func memories(kind: OnDeviceMemoryKind) throws -> [OnDeviceMemoryRecord] {
        let descriptor = FetchDescriptor<OnDeviceMemoryRecord>()
        return try context.fetch(descriptor)
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    public func nearestMemories(
        to embedding: [Double],
        kind: OnDeviceMemoryKind,
        limit: Int
    ) throws -> [OnDeviceMemoryMatch] {
        guard limit > 0, !embedding.isEmpty else {
            return []
        }

        return try memories(kind: kind)
            .compactMap { memory in
                let score = cosineSimilarity(embedding, memory.embedding)
                guard score.isFinite else {
                    return nil
                }
                return OnDeviceMemoryMatch(memory: memory, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.memory.updatedAt > rhs.memory.updatedAt
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    public func deleteMemories(subjectID: UUID, saveImmediately: Bool = true) throws {
        let descriptor = FetchDescriptor<OnDeviceMemoryRecord>()
        let memories = try context.fetch(descriptor)
            .filter { $0.subjectID == subjectID }

        memories.forEach(context.delete)
        if saveImmediately {
            try context.save()
        }
    }

    public func deleteAllMemories(saveImmediately: Bool = true) throws {
        let descriptor = FetchDescriptor<OnDeviceMemoryRecord>()
        let memories = try context.fetch(descriptor)

        memories.forEach(context.delete)
        if saveImmediately {
            try context.save()
        }
    }

    private func memory(withKey memoryKey: String) throws -> OnDeviceMemoryRecord? {
        let descriptor = FetchDescriptor<OnDeviceMemoryRecord>()
        return try context.fetch(descriptor)
            .first { $0.memoryKey == memoryKey }
    }

    private func sanitizedSummary(_ summary: String) throws -> String {
        let sanitizedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedSummary.isEmpty else {
            throw OnDeviceMemoryStoreError.emptySummary
        }

        return sanitizedSummary
    }

    private func sanitizedEmbedding(_ embedding: [Double]) throws -> [Double] {
        guard embedding.allSatisfy(\.isFinite) else {
            throw OnDeviceMemoryStoreError.nonFiniteEmbedding
        }

        return embedding
    }

    private func sanitizedMetadataTags(_ metadataTags: [String]) -> [String] {
        var seenTags = Set<String>()
        var sanitizedTags: [String] = []

        for tag in metadataTags {
            let sanitizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedTag = sanitizedTag.lowercased()
            guard !sanitizedTag.isEmpty, !seenTags.contains(normalizedTag) else {
                continue
            }

            sanitizedTags.append(sanitizedTag)
            seenTags.insert(normalizedTag)
        }

        return sanitizedTags
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return .nan
        }

        var dotProduct = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0

        for index in lhs.indices {
            dotProduct += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }

        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            return .nan
        }

        return dotProduct / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }
}
