import Foundation
import SwiftData

@Model
public final class Closet: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var itemIDs: [UUID]
    public var dateCreated: Date
    public var dateUpdated: Date
    public var dateDeleted: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        itemIDs: [UUID] = [],
        dateCreated: Date = .now,
        dateUpdated: Date = .now,
        dateDeleted: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(name) ?? "Untitled Closet"
        self.itemIDs = Self.deduplicated(itemIDs)
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.dateDeleted = dateDeleted
    }

    public var displayName: String {
        Self.cleanedName(name) ?? "Untitled Closet"
    }

    public var itemCount: Int {
        itemIDs.count
    }

    public var isDeleted: Bool {
        dateDeleted != nil
    }

    public func contains(_ item: ClosetItem) -> Bool {
        itemIDs.contains(item.id)
    }

    public func add(_ item: ClosetItem, date: Date = .now) {
        guard !contains(item) else {
            return
        }
        itemIDs.append(item.id)
        touch(date: date)
    }

    public func remove(_ item: ClosetItem, date: Date = .now) {
        let originalCount = itemIDs.count
        itemIDs.removeAll { $0 == item.id }
        if itemIDs.count != originalCount {
            touch(date: date)
        }
    }

    public func setContains(_ isIncluded: Bool, item: ClosetItem, date: Date = .now) {
        if isIncluded {
            add(item, date: date)
        } else {
            remove(item, date: date)
        }
    }

    public func rename(_ newName: String, date: Date = .now) {
        name = newName
        touch(date: date)
    }

    public func touch(date: Date = .now) {
        dateUpdated = date
    }

    public func markDeleted(date: Date = .now) {
        dateDeleted = date
        touch(date: date)
    }

    public static func cleanedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func deduplicated(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
