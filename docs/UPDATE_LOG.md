# Update Log

## 2026-06-18 - Deployment Readiness Pass

### On-Device Memory

- Added SwiftData-backed on-device memory records for item, outfit, preference, and purchase-candidate memory.
- Added a local memory store for upsert, fetch, delete, and in-process embedding similarity retrieval.
- Added stable local memory keys, optional scopes for global preference memory, sanitized summaries/tags, finite-vector validation, and rollback-safe upsert/delete support.
- Added local memory payload generation for closet items and saved fits, including deterministic on-device embeddings and metadata tags.
- Item add/edit and fit save/edit/wear paths now upsert local memory records in the same SwiftData transaction as the source object.
- Item deletion now removes associated on-device memory in the same SwiftData transaction.
- Verified that a store created before the memory model can open with the current schema and then persist memory records.

### Run And QA

- Updated the simulator run script to terminate an existing Pyxis process before install/launch.
- Strengthened `--verify` so it checks the launched app process is still alive after startup.
- Added Escape close shortcuts to modal/detail surfaces and made item-detail close explicitly save pending edits.
- Expanded manual QA with Escape, repeated launch, and process-replacement checks.
- Added app icon assets, an accent color asset, and a privacy manifest for distribution readiness.
- Aligned the Xcode target to iPhone-only deployment and opted out of unverified Mac/Vision compatibility surfaces.
- Added App Store Connect metadata notes and a publishable privacy-policy draft.
- Added a publishable support-page draft with a concrete support contact.
- Added an App Store Connect export options template using Xcode's current `app-store-connect` method.
- Added a deployment preflight script with static, local, and distribution modes.
- Flattened the 1024px App Store icon source to an opaque RGB PNG and added preflight validation for icon pixel size and alpha.
- Added static preflight scanning for required-reason API usage while the privacy manifest declares no accessed API categories.
- Added explicit privacy manifest validation and Release artifact scans to prevent debug-only sample import, closet seeding UI, messages, and sample item codes from shipping.
- Added preflight validation for user-visible app metadata, the photo-library purpose string, app category, and absence of iPad device-family metadata in built Release artifacts.
- Added preflight validation that the support-page and privacy-policy drafts use the same support contact.
- Verified connected-iPhone Debug build, install, and launch after automatic development provisioning.
- Verified signed Release archive creation; archive currently uses a development profile and still needs App Store distribution signing/export for TestFlight.
- Verified local App Store Connect export currently fails because Xcode has no authenticated App Store Connect provider/profile for `com.zainoodle.pyxis`.
- Reverified simulator, physical-device build/install, unsigned archive, signed archive, and App Store export gates after wiring on-device memory into save paths.
- Expanded the git ignore rule to keep generated `DerivedData*` build output out of source control.
- Verified unsigned Release archive creation and inspected archived app metadata.

### Verification

- Added tests for memory payload generation, memory persistence, local similarity ranking, deletion, rollback-safe upsert/deletion, scoped global memory, validation, idempotent upsert, and schema upgrade.

## 2026-06-16 - Premium White Closet UI

### Visual System

- Changed the app background token to true white for a brighter, more premium default surface.
- Locked the root app presentation to light mode so the closet UI stays visually consistent during device testing.
- Rebalanced shared text, inactive, hairline, field, and error colors for warmer contrast on white.
- Added a subtle shared card treatment with white fill, 8 pt radius, hairline border, and soft elevation.

### Closet Grid

- Applied the new premium card treatment to closet item tiles.
- Added extra item tile padding so cutout images, item codes, and labels feel less compressed.
- Preserved the existing minimalist item metadata hierarchy and tap behavior.

### Search And Filtering

- Replaced the cryptic `FAV` system toggle with an explicit heart `FAVORITES` filter button.
- Added active and inactive visual states for the favorites-only filter.
- Added a search icon, rounded field, and hairline border to make the search control feel intentional.
- Kept the same filter behavior: enabling favorites shows only favorited closet items.

### Build And Device Testing

- Verified the Swift package test suite with 54 XCTest cases passing.
- Verified the iOS app target builds and launches on the iPhone 17 simulator.
- Captured and inspected the simulator UI after the premium white update.
