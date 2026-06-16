# ARCHIVE Implementation Plan

> Note: This original plan described the macOS prototype. The macOS version is preserved on the `macos-main` branch. The `main` branch now targets iOS with `ARCHIVE.xcodeproj`.

This plan starts after explicit approval of `docs/ARCHITECTURE_REVIEW.md`. It follows the phases in `Instructions.docx` and the macOS build/run guidance from the Build macOS Apps workflow.

## Pre-Flight

Do not begin this section until architecture approval is given.

1. Confirm the workspace is still not inside a parent git repo.
2. If no repo is present, run `git init` at `C:\Users\zaino\OneDrive\Documents\Github\Pyxis`.
3. Create a SwiftPM macOS app package for `ARCHIVE`.
4. Keep all MVP functionality local-first.
5. Add no third-party package dependencies unless the user explicitly approves them.
6. Add no network, analytics, telemetry, cloud storage, account, or remote processing code.

## Phase 2: Models And Persistence

### Files

- `Package.swift`
- `ARCHIVE/App/ArchiveApp.swift`
- `ARCHIVE/Models/ClosetItem.swift`
- `ARCHIVE/Models/ClothingCategory.swift`
- `ARCHIVE/Models/ClothingSubtype.swift`
- `ARCHIVE/Models/ClosetColor.swift`
- `ARCHIVE/Models/Season.swift`
- `ARCHIVE/Models/ItemSource.swift`
- `ARCHIVE/Persistence/SwiftDataContainer.swift`
- `ARCHIVE/Services/ItemCodeGenerator.swift`
- `Tests/ArchiveTests/ItemCodeGeneratorTests.swift`
- `Tests/ArchiveTests/PersistenceTests.swift`

### Work

1. Define all enums as `String`, `CaseIterable`, `Codable`, `Identifiable`, and `Sendable` where appropriate.
2. Implement `ClosetItem` as a SwiftData `@Model`.
3. Store enum values as raw strings for schema durability.
4. Add convenience properties for typed enum access if they do not fight SwiftData.
5. Implement SwiftData container creation for app and test contexts.
6. Implement `ItemCodeGenerator` with stable prefixes and collision avoidance.
7. Add future-safe fields for image paths, classification confidence, color confidence, source, wear data, favorite, tags, seasons, notes, brand, and size.

### Tests

- Generate each required item code prefix.
- Continue numbering with existing codes.
- Avoid collisions when a code already exists.
- Confirm metadata changes do not regenerate item codes.
- Insert and fetch a `ClosetItem` in a test model container.
- Update metadata and refetch.
- Delete an item and confirm it is gone.

### Exit Gate

- `swift test` passes on macOS.
- The package compiles.
- No network-related dependencies or APIs are introduced.

## Phase 3: Image Storage And Processing

### Files

- `ARCHIVE/Services/ImageStorageService.swift`
- `ARCHIVE/Services/BackgroundRemovalService.swift`
- `ARCHIVE/Utilities/ImageUtilities.swift`
- `ARCHIVE/Utilities/FileManagerExtensions.swift`
- `Tests/ArchiveTests/ImageStorageTests.swift`
- `Tests/ArchiveTests/BackgroundRemovalFallbackTests.swift`

### Work

1. Resolve `Application Support/ARCHIVE/Images`.
2. Create `Originals`, `Cutouts`, and `Thumbnails` directories.
3. Save imported original images using UUID filenames.
4. Create thumbnails for grid display.
5. Define `BackgroundRemovalService` protocol and result/status types.
6. Implement local Vision/Core Image background removal where available.
7. Preserve original image on every failure path.
8. Allow save without cutout when background removal fails.
9. Add retry-friendly result/error structure.

### Tests

- Directory creation uses configurable root for tests.
- Original, cutout, and thumbnail paths are generated without hardcoded absolute paths.
- Save and delete related image files.
- Fallback result allows item save when removal fails.
- Thumbnail generation works for a small synthetic image where the platform APIs are available.

### Exit Gate

- Storage and fallback tests pass.
- Code search confirms no remote image processing or network APIs.
- Background removal failure is represented as data, not a crash.

## Phase 4: Color And Classification

### Files

- `ARCHIVE/Services/ColorAnalysisService.swift`
- `ARCHIVE/Services/ClothingClassificationService.swift`
- `ARCHIVE/Services/FutureAI/OutfitRecommendationService.swift`
- `ARCHIVE/Services/FutureAI/PurchaseCompatibilityService.swift`
- `ARCHIVE/Services/FutureAI/EmbeddingService.swift`
- `Tests/ArchiveTests/ColorAnalysisTests.swift`

### Work

1. Analyze cutout image first, original image second.
2. Ignore transparent pixels during color sampling.
3. Map sampled RGB values to `ClosetColor`.
4. Return primary color, secondary colors where practical, and confidence.
5. Implement local filename/metadata heuristic classification only.
6. Keep classifier manual-first and low confidence unless a strong heuristic match exists.
7. Add future AI protocols as placeholders only.

### Tests

- Transparent pixels are ignored.
- Synthetic black, white, gray, cream, brown, navy, blue, green, red, yellow, and orange samples map correctly.
- Multicolor/unknown cases are handled.
- Filename heuristic maps common subtype tokens.
- Future AI services have no network implementation.

### Exit Gate

- Color/classification tests pass.
- Code search confirms no remote AI, embeddings service implementation, or network calls.

## Phase 5: UI

### Files

- `ARCHIVE/DesignSystem/ArchiveTypography.swift`
- `ARCHIVE/DesignSystem/ArchiveColors.swift`
- `ARCHIVE/DesignSystem/ArchiveSpacing.swift`
- `ARCHIVE/DesignSystem/ArchiveComponents.swift`
- `ARCHIVE/ViewModels/ClosetGridViewModel.swift`
- `ARCHIVE/ViewModels/AddItemViewModel.swift`
- `ARCHIVE/ViewModels/ItemDetailViewModel.swift`
- `ARCHIVE/Views/ClosetGrid/ClosetGridView.swift`
- `ARCHIVE/Views/ClosetGrid/ClosetGridItemView.swift`
- `ARCHIVE/Views/AddItem/AddItemFlow.swift`
- `ARCHIVE/Views/AddItem/ImageImportView.swift`
- `ARCHIVE/Views/AddItem/MetadataEditorView.swift`
- `ARCHIVE/Views/ItemDetail/ItemDetailView.swift`
- `ARCHIVE/Views/Navigation/TopNavigationView.swift`
- `ARCHIVE/Views/Search/SearchAndFilterView.swift`
- `Tests/ArchiveTests/FilteringTests.swift`

### Work

1. Build the minimal design system first.
2. Implement grid-first app shell.
3. Add centered uppercase navigation.
4. Add search/filter state and sorting.
5. Implement import and drag/drop image entry points.
6. Show original preview, background-removal progress, cutout/failure state, metadata editor, save, and save-anyway behavior.
7. Implement item detail editing, retry, favorite, delete, notes/tags/brand/size/wear metadata.
8. Add keyboard shortcuts:
   - `Command+N`: open add item flow.
   - `Command+F`: focus search.
   - `Escape`: close modal/detail where appropriate.
9. Add accessibility labels for image import, save, retry, delete, favorite, filters, and search.

### Tests

- Search predicate covers code, display name, brand, notes, tags, category, subtype, and color.
- Category filter works.
- Color filter works.
- Favorites filter works.
- Sort by newest/category/color/most worn works.

### Visual QA

- White or near-white background.
- No heavy cards, shadows, gradients, or decorative chrome.
- Clothing thumbnails are the visual focus.
- Product-code labels sit under item images.
- Active filters are dark; inactive filters are light gray.
- Empty state is exactly `ADD FIRST ITEM`.

### Exit Gate

- Filtering tests pass.
- App compiles on macOS.
- Manual visual inspection does not show heavy chrome or reference-brand copying.

## Phase 6: QA And Polish

### Build/Run Files

- `script/build_and_run.sh`
- `.codex/environments/environment.toml`

### Work

1. Add `script/build_and_run.sh` after the runnable target exists.
2. Stage SwiftPM GUI output into `dist/ARCHIVE.app`.
3. Generate minimal `Info.plist`.
4. Launch with `/usr/bin/open -n dist/ARCHIVE.app`.
5. Add `--verify`, `--logs`, and `--debug` support where practical.
6. Wire `.codex/environments/environment.toml` Run action to `./script/build_and_run.sh`.
7. Run unit tests.
8. Run the build/run script on macOS.
9. Complete the manual QA checklist from `docs/REQUIREMENTS_TRACE.md`.
10. Fix compile, test, launch, persistence, and UI issues found during QA.

### Exit Gate

- `swift test` passes.
- `./script/build_and_run.sh --verify` succeeds on macOS.
- Manual QA checklist passes or each remaining limitation is documented.
- Code search confirms:
  - no `URLSession` or networking for MVP functionality,
  - no analytics or telemetry SDKs,
  - no third-party remote processing APIs,
  - no copied reference brand assets.

## Final Completion Evidence

The implementation goal should be considered complete only after these artifacts and evidence exist:

1. A runnable macOS app project.
2. Models, services, view models, and views matching the architecture review.
3. Unit tests for item codes, persistence, image storage, color analysis, filtering, and fallback behavior.
4. A local build/run script and Codex Run action.
5. Test results from a macOS Swift/Xcode environment.
6. Manual QA results for the add-item, persistence, filter/search, detail, retry, and delete workflows.
7. Security review confirming no network, telemetry, cloud upload, remote AI, or copied protected assets.

## Subagent Use

After implementation approval, useful independent subagent workstreams are:

- Model/persistence tests.
- Image storage and fallback tests.
- Search/filter predicate tests.
- UI visual review against the minimal catalog direction.
- Security/code-search audit for network and telemetry violations.

Do not split work into parallel edits until write scopes are disjoint.
