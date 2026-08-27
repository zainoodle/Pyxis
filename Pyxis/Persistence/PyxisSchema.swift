import SwiftData

/// The immutable baseline for the model layout shipped before the v1.1 quality pass.
/// Every persisted-model change must add a new `VersionedSchema`, a migration stage,
/// and a fixture-backed migration test. Never delete a store to recover migration.
public enum PyxisSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ClosetItem.self,
            Outfit.self,
            Closet.self,
            OnDeviceMemoryRecord.self,
            BodyProfile.self
        ]
    }
}

public enum PyxisMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [PyxisSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
