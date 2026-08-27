# Pyxis Data Migration Rules

Pyxis preserves the local SwiftData store and managed image library when startup or migration fails. It must never silently delete either as a recovery strategy.

`PyxisSchemaV1` is the immutable baseline for the model layout shipped before the v1.1 quality pass. For every future persisted-model change:

1. Leave all prior `VersionedSchema` declarations unchanged.
2. Add a new schema version containing the new model layout.
3. Add an explicit lightweight or custom stage to `PyxisMigrationPlan`.
4. Add a fixture-backed test created with the historical declarations for the source version.
5. Validate representative closet items, custom closets, saved outfits, Fit Passport data, and on-device memory after migration.
6. Test failure behavior without deleting the source store or image library.

The initial v1.1 pass establishes versioned container wiring. A genuinely historical fixture spanning all persisted model families remains required before the schema itself changes; reusing today's mutable model types is not acceptable evidence for such a future migration.
