# Outfit Stack Slider Design

## Summary

Build a premium manual outfit builder for ARCHIVE where users see a complete fit at once: shirts on top, pants in the middle, and shoes at the bottom. Each row is a swipeable bay-window carousel inspired by the reference video, with the centered item in each row becoming the active outfit piece. Users can save the assembled fit locally.

This feature remains local-first. It does not add accounts, cloud sync, remote image processing, recommendations, analytics, or network calls.

## Reference Animation Analysis

The provided reference video is a 4-second image slider loop. Its key behavior is a bay-window carousel: the focused image sits forward and readable in the center, neighboring images rotate backward in perspective, and farther images fade into the sides. The effect creates depth without hiding the current item.

For ARCHIVE, the animation should be translated into function rather than copied literally. Each clothing category row should use the same depth grammar:

- Center item: full opacity, largest scale, no horizontal rotation, active selection.
- Near side items: lower opacity, smaller apparent size, rotated on the Y axis toward the center.
- Far side items: lowest opacity, farther from center, stronger rotation, visually present but not distracting.
- Swipe or drag: horizontal gesture advances the row by one item with a snap animation.
- Scroll: vertical page scrolling should remain available when the outfit stack exceeds the viewport.

## Current App Context

ARCHIVE currently launches directly into `ClosetGridView`, queries `ClosetItem` records with SwiftData, and displays items in a grid. Tapping an item opens `ItemDetailView`; adding an item opens `AddItemFlow`.

Existing useful foundations:

- `ClosetItem` stores local image paths for original, cutout, and thumbnail images.
- `ImageStorageService` stores image files locally under Application Support.
- `LocalBackgroundRemovalService` already attempts local Vision/Core Image background removal during upload.
- `AddItemViewModel.processSelectedImage` starts processing after image selection.
- `ClosetFilteringService` already handles category, subtype, color, favorites, search, and sort logic.

Important constraints:

- There is no outfit model or saved-fit persistence today.
- There is no app navigation shell today.
- `LocalImageView` loads `UIImage(contentsOfFile:)` synchronously, which may stutter in a carousel if not improved.
- The current grid uses fixed desktop-like widths that need responsive iPhone handling.

## Approaches Considered

### Approach A: Outfit Stack Builder

Add a dedicated builder screen with multiple category rows visible together. Shirt, pants, and shoes rows each swipe horizontally with the bay-window effect. The selected center item in each row forms the current outfit. A fixed bottom rail previews the selected pieces and offers `SAVE FIT`.

This is the recommended approach because it matches the user's desired mental model: the outfit is visible all together while each layer remains independently swipable.

### Approach B: Single Closet Browser

Add one immersive bay-window carousel for all closet pieces, then let users add selected pieces to an outfit tray. This is simpler to model and useful for browsing, but it does not show the outfit stacked together while decisions are being made.

### Approach C: Swipe Decision Deck

Use a keep/skip card deck where users swipe right to add and left to skip. This is fast and familiar, but it loses the bay-window depth and feels less premium for deliberate outfit building.

## Product Design

The MVP should ship as a manual outfit-building mode, reachable from the main closet surface through a clear `BUILD` entry. The first version should support three required rows:

- `Shirt`: items from `tops`.
- `Pants`: items from `bottoms`.
- `Shoes`: items from `footwear`.

Outerwear and accessories should be supported by the data model from the start but not required for saving an outfit. The UI can add optional rows after the core interaction feels clean.

The screen should feel premium and calm:

- Use the existing minimal ARCHIVE visual language: near-white background, black type, restrained lines, no heavy chrome.
- Put clothing images on clean transparent or near-white surfaces so the garments carry the interface.
- Avoid loud gradients, marketing hero layouts, nested cards, and decorative shapes.
- Use steady spring-like snapping, subtle scale, and perspective. The animation should feel deliberate, not bouncy or game-like.
- Keep labels small and utilitarian: `SHIRT`, `PANTS`, `SHOES`, `SAVE FIT`.
- The current center items should visually align as a complete outfit stack, not as isolated catalog cards.

## Interaction Model

Each row owns its selected item index and responds to:

- Horizontal swipe left/right to move to the next or previous item.
- Tap on side item to snap that item to center.
- Tap on center item to open item detail.
- Row-level filter controls are out of scope for this implementation.

The builder owns the current outfit draft:

- `topItemID`
- `bottomItemID`
- `footwearItemID`
- optional `outerwearItemID`
- optional `accessoryItemIDs`

The `SAVE FIT` action is enabled when the required rows have selected items. Saving creates a local persisted outfit record.

Empty row behavior:

- If a category has no items, show a quiet row-level empty state with an add/import action for that category.
- Do not block the entire builder unless all required categories are empty.

## Persistence Design

Add a SwiftData `Outfit` model. It should persist local outfit assemblies without duplicating clothing metadata.

Fields:

- `id: UUID`
- `name: String?`
- `topItemID: UUID?`
- `bottomItemID: UUID?`
- `footwearItemID: UUID?`
- `outerwearItemID: UUID?`
- `accessoryItemIDs: [UUID]`
- `dateCreated: Date`
- `dateUpdated: Date`
- `favorite: Bool`
- `notes: String?`

Use UUID references instead of SwiftData relationships for the MVP. This keeps persistence simple, avoids relationship migration complexity, and matches the existing future outfit service contract that returns item UUIDs.

Saved outfits should appear in a small saved-fits surface in the builder. The minimum viable saved-fit experience is a compact list or strip of saved fits with date-based labels, a visual summary of selected pieces, and enough persistence tests to prove saved outfits survive fetches. Rename, delete, and share actions are out of scope for this implementation.

## Image And Background Removal Requirements

Background removal should happen on upload and should produce a cutout image when Vision succeeds. The carousel and outfit builder should prefer transparent cutouts, then thumbnails, then originals only as a fallback.

Implementation requirements:

- Keep local Vision/Core Image background removal. Do not add remote image processing.
- Continue preserving the original image on every failure path.
- Make upload status clear: processing, cutout ready, or background removal failed with retry.
- Ensure saved closet items store `imageCutoutPath` when removal succeeds.
- Ensure thumbnails used by the grid and builder are generated from cutouts when available.
- In the builder, prefer cutout images so clothing pieces visually stack cleanly against the premium surface.

If background removal fails, users may still save the item with the original image, but the UI should clearly show that the cutout is missing and allow retry. This preserves the local-first fallback behavior while making the ideal path clear.

## Architecture

Add the feature in focused units:

- `ARCHIVE/Models/Outfit.swift`: SwiftData model for saved fits.
- `ARCHIVE/Persistence/SwiftDataContainer.swift`: include `Outfit` in the schema.
- `ARCHIVE/Services/OutfitBuilderService.swift`: pure logic for grouping items into rows, choosing default selections, advancing row indices, and creating outfit draft data.
- `ARCHIVE/ViewModels/OutfitBuilderViewModel.swift`: UI state for selected indices, current draft, saving, and row empty states.
- `ARCHIVE/Views/OutfitBuilder/OutfitBuilderView.swift`: screen shell with top controls, stacked rows, and save rail.
- `ARCHIVE/Views/OutfitBuilder/OutfitCarouselRow.swift`: reusable bay-window row.
- `ARCHIVE/Views/OutfitBuilder/OutfitCarouselItemView.swift`: item rendering, image priority, labels, and accessibility.
- `ARCHIVE/Views/OutfitBuilder/SavedFitsStrip.swift`: compact saved-fit surface inside the builder.
- `ARCHIVE/Views/Shared/ClosetItemImageResolver.swift`: shared helper for cutout/thumbnail/original URL priority.

The reusable row should not know about SwiftData or saving. It should render item view data and report selection changes. The service should be testable in `ArchiveCore` without UI automation.

## Data Flow

1. `OutfitBuilderView` receives all `ClosetItem` records from SwiftData.
2. `OutfitBuilderViewModel` asks `OutfitBuilderService` to build rows for tops, bottoms, and footwear.
3. Each `OutfitCarouselRow` displays its row items and selected index.
4. A swipe updates the selected index for that row.
5. The selected center items update the current outfit draft.
6. `SAVE FIT` inserts an `Outfit` model into the SwiftData model context and saves it.
7. The builder shows a saved confirmation, leaves the selected outfit visible, and updates the saved-fits strip.

## Testing

Unit tests should cover logic before UI implementation:

- Outfit rows group `ClosetItem`s by required categories.
- Empty categories produce empty rows without crashing.
- Initial selection picks the first item in each non-empty required row.
- Advancing next/previous wraps or clamps consistently.
- Draft creation uses the selected top, bottom, and footwear IDs.
- Save eligibility requires all required rows to have selections.
- `Outfit` persists and refetches through `SwiftDataContainer.makeTestContainer`.
- Saved outfits can be mapped back to their selected `ClosetItem` summaries.
- Background removal fallback continues to preserve original images when cutout generation fails.
- Image URL priority prefers cutout over thumbnail over original for builder display.

Manual QA should cover:

- Swipe rows on an iPhone simulator.
- Tap center item opens detail.
- Save fit creates a persisted record.
- Saved fit appears in the builder saved-fits strip.
- Uploading a new item processes background removal before save.
- Cutout images appear cleanly in the builder.
- Failed background removal still allows save with visible retry affordance.
- The layout works on small and large iPhone simulator sizes.

## Accessibility

Each carousel row should expose a clear accessibility label such as `Shirt carousel`, `Pants carousel`, or `Shoes carousel`. Each item should include item code and display name when available. Save should be labeled `Save fit`. Empty row import actions should name the missing category.

Gesture-only behavior must have button alternatives:

- Previous item.
- Next item.
- Save fit.
- Open selected item detail.

## Out Of Scope For This Iteration

- AI outfit recommendations.
- Remote sync or accounts.
- Social sharing.
- Calendar planning.
- Generated outfit names.
- Advanced per-row filters beyond existing closet filtering.
- Complex wardrobe rules such as color matching or weather.
- Persistent outfit images rendered as flattened composites.

## Success Criteria

- Users can open the builder and see shirt, pants, and shoes together.
- Users can swipe each row to browse their closet while preserving the full outfit view.
- Users can save a local fit and fetch it again after persistence.
- Builder images prefer background-removed cutouts.
- Upload still attempts local background removal before save.
- The feature builds without adding network, telemetry, or remote processing.
- The experience feels premium: calm, clean, responsive, and focused on the clothing.
