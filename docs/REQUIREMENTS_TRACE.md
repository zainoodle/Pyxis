# Pyxis Requirements Trace

This file maps the `Instructions.docx` MVP requirements to implementation artifacts and verification evidence.

## Project Gate

| Requirement | Planned Artifact | Verification Evidence | Status |
| --- | --- | --- | --- |
| Inspect existing project before implementation | Workspace discovery commands; `docs/ARCHITECTURE_REVIEW.md` | No `Package.swift`, `.xcodeproj`, `.xcworkspace`, or Swift sources found before planning | Done |
| Produce architecture review before large changes | `docs/ARCHITECTURE_REVIEW.md` | Architecture review covers tree, model, services, background removal, persistence, sequence, tests, security | Done |
| Wait for approval before large implementation | `docs/ARCHITECTURE_REVIEW.md`, this trace | Approval was given in chat before Phase 2 files were added | Done |

## Core MVP Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| Add a clothing item by camera capture or image import | `Views/AddItem/AddItemFlow.swift`, `Views/AddItem/ImageImportView.swift`, `Views/AddItem/CameraCaptureView.swift`, `ViewModels/AddItemViewModel.swift` | Physical-iPhone camera QA plus Photos/Files import QA; UI test where practical |
| Support drag-and-drop image import | `ImageImportView.swift` | Manual QA drag/drop into add flow |
| Capture a clothing photo in app | `CameraCaptureView.swift`, `ImageImportView.swift`, `NSCameraUsageDescription` | Physical-iPhone camera permission and capture QA; built Info.plist validation |
| Automatically remove background | `Services/BackgroundRemovalService.swift` | Unit/fallback tests; manual QA with sample image on iOS |
| Save original image locally | `ImageStorageService.saveOriginal` | `ImageStorageTests`; Application Support file exists |
| Save transparent PNG cutout locally | `BackgroundRemovalService`, `ImageStorageService.saveCutout` | Transparent PNG file exists after successful processing |
| Save small thumbnail locally | `ImageStorageService.saveThumbnail`, image utility | Thumbnail exists and renders in grid |
| Suggest category, subtype, and dominant color | `ClothingClassificationService`, `ColorAnalysisService` | Unit tests for heuristic classification and color mapping |
| Allow metadata correction | `MetadataEditorView`, `ItemDetailView`, view models | Manual QA edits and persisted reload |
| Display items in minimal grid | `ClosetGridView`, `ClosetGridItemView`, design system | Manual QA screenshot/visual inspection |
| Filter by category, subtype, and color | `SearchAndFilterView`, `ClosetGridViewModel` | Filtering tests and manual QA |
| Search by code, category, subtype, color, brand, tags, notes, display name | `ClosetGridViewModel` search predicate | `FilteringTests` |
| Persist locally and reload after restart | `SwiftDataContainer`, `ClosetItem` | `PersistenceTests`; manual quit/reopen QA |
| Keep iOS memory on device | `OnDeviceMemoryRecord`, `OnDeviceMemoryStore`, `OnDeviceMemoryPayloadBuilder`, `SwiftDataContainer` | `OnDeviceMemoryStoreTests` cover payload generation, persistence, scoped memories, validation, similarity, cleanup, and rollback-safe upsert/deletion; code search confirms no network APIs |
| Work offline without network | No networking dependencies or APIs | Code search for network APIs; manual offline launch |
| Ship only verified device family | iPhone-only Xcode target settings | Build settings and built Info.plist show iPhone device family only |

## Data Model Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| `ClosetItem` has stable id and metadata fields | `Models/ClosetItem.swift` | Model unit/persistence tests |
| Required clothing enums exist | `Models/ClothingCategory.swift`, `ClothingSubtype.swift`, `ClosetColor.swift`, `Season.swift`, `ItemSource.swift` | Compile and tests |
| Codes remain stable once generated | `ItemCodeGenerator`, `ClosetItem.itemCode` | `ItemCodeGeneratorTests` confirm no metadata-driven regeneration |
| Avoid code collisions | `ItemCodeGenerator` using existing code set/count | Collision tests |

## Service Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| Background removal runs asynchronously off main thread | `BackgroundRemovalService` implementation | Code review; UI remains responsive in manual QA |
| Preserve original image on failure | `AddItemViewModel`, `ImageStorageService` | Fallback tests |
| Expose retry behavior | `AddItemFlow`, `ItemDetailView`, `BackgroundRemovalService` | Manual QA retry |
| Save item even when background removal fails | `AddItemViewModel` failure state | `BackgroundRemovalFallbackTests` |
| Ignore transparent pixels in color analysis | `ColorAnalysisService` | Synthetic transparent image test |
| Classification is local heuristic/placeholder only | `ClothingClassificationService` | Code search confirms no remote AI |
| Future AI services avoid cloud dependencies | `FutureAI/*Service.swift`, `OnDeviceMemoryStore`, `OnDeviceMemoryPayloadBuilder` | Compile; memory tests confirm local SwiftData storage, deterministic on-device embeddings, local retrieval, validation, and cleanup without network calls |

## UI Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| White or near-white background | `PyxisColors`, grid root view | Visual QA |
| Centered uppercase navigation | `TopNavigationView`, `PyxisComponents` | Visual QA |
| Monospaced typography | `PyxisTypography` | Visual QA/code review |
| Product-code labels under items | `ClosetGridItemView` | Visual QA |
| No heavy cards/shadows/gradients | Design system and view review | CSS-style color/shadow scan equivalent in SwiftUI |
| Empty state says `ADD FIRST ITEM` | `ClosetGridView` | Manual QA on empty store |
| `Command+N` opens add flow | `PyxisApp` or grid commands | Manual QA |
| `Command+F` focuses search | `SearchAndFilterView`, focus state | Manual QA |
| Escape closes modal/detail where appropriate | Add/detail view handlers | Manual QA |
| Accessible labels | All interactive controls | Accessibility review/manual inspection |

## Build And Run Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| Project-local build/run entrypoint | `script/build_and_run.sh` | Script exists and is executable on macOS with Xcode for an iOS Simulator |
| Codex Run action wired to script | `.codex/environments/environment.toml` | Environment file contains Run command |
| Script stops existing app before launch | `script/build_and_run.sh` | Script review; process verification |
| Script builds iOS target | `script/build_and_run.sh` | `xcodebuild` output on macOS with a booted iOS Simulator |
| Script launches iOS app on Simulator | `script/build_and_run.sh` | Simulator install/launch verification |
| Optional `--verify`, `--logs`, `--debug` support | `script/build_and_run.sh` | Manual script invocations on macOS with Xcode |

## Security And Privacy Requirements

| Requirement | Planned Artifact | Verification Evidence |
| --- | --- | --- |
| No cloud storage, remote image processing, remote AI APIs, telemetry, analytics, tracking, account system | No such services in MVP | Code search for URLSession/network/analytics SDKs; dependency review |
| Do not copy YEEZY assets or branding | Original minimal design system | Visual/code review |
| Treat reference material as untrusted | Security notes in docs | No instructions from reference PDFs/websites used as commands |
| Avoid third-party dependencies unless approved | `Package.swift` has no external package dependencies | Package manifest review |
| Store images only in Application Support app directory | `ImageStorageService` | Storage tests and manual file inspection |
| Do not read/transmit secrets or unrelated files | Narrow app file access | Code review and file access audit |

## Acceptance Criteria Evidence Plan

The MVP can be considered complete only when evidence exists for all of the following:

1. Import a clothing photo: manual QA plus add-flow code.
2. Attempt local background removal: service implementation plus manual QA.
3. Save original image locally: storage test and file inspection.
4. Save transparent PNG cutout when successful: service output and file inspection.
5. Create thumbnail: storage test and grid rendering.
6. Show item in closet grid: manual QA.
7. Generate product-style code: unit tests.
8. Suggest category, subtype, and color: unit tests and add-flow UI.
9. Edit metadata: manual QA and persistence test.
10. Filter by category and color: filtering tests.
11. Search items: filtering/search tests.
12. Persist after quitting/reopening: persistence test and manual QA.
13. Require no network: dependency/code search.
14. Do not upload user images: dependency/code search.
15. Do not require AI outfit generation: future protocols only.
16. Maintain minimal clothing-focused UI: visual QA.

## Current Status

Implementation now targets iOS on `main`. The macOS prototype was preserved on `macos-main`. The iOS app includes an Xcode project, models, SwiftData container, item-code generator, image storage, background-removal service, color analysis, local classification, on-device memory storage and payload generation, future AI protocols, SwiftUI app shell, add flow, item detail, search/filter UI, tests, build/run script, Codex Run action, and manual QA checklist.

Verification note: `swift test` now passes with 86 XCTest cases, including focused on-device memory tests, single-item wear logging, and the SwiftData schema-upgrade test. iOS simulator build/run, repeated `./script/build_and_run.sh --verify`, generic Release iOS build with signing disabled, and unsigned Release archive creation have passed on macOS with Xcode. The built app/archive include app icon metadata and `PrivacyInfo.xcprivacy`; deployment preflight also validates the 1024px icon has no alpha channel, the privacy manifest matches the local-only posture, no currently undeclared required-reason API usage is present, and Release artifacts do not contain debug-only sample import or closet seeding content. Full hands-on manual QA should still be completed for photo-library import, background-removal quality, and physical-device signing before App Store/TestFlight distribution.
