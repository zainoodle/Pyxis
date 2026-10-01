# Selected Closet and Fit flow — design QA

Date: 2026-10-01. Worktree: `editorial-archive`, branch `codex/editorial-archive`, based on `ca3059e`.

The approved Closet Gallery, Closet Grid, and Your fit images are saved in `design-assets/selected-wardrobe-flow/`. The implementation retains the charcoal/ivory palette, photographic garment staging, garment codes, labeled Gallery/Grid controls, Keep/Swap rows, and primary Build/Save actions. Shared typography and buttons follow the same roles across the flow.

## Visual gate

**Passed for the native adaptation.** The [combined comparison](ui-evidence/selected-wardrobe-flow/mockup-comparison.png) places each approved reference beside the rendered app. The [native preview](ui-evidence/selected-wardrobe-flow/native-preview.png) shows the full Closet and Fit screens. No unresolved P0/P1/P2 issue was found in the tested layouts.

The reference content is approximately 390 × 844; the simulator is 402 × 874 with native status and home safe areas. The comparison crops only those OS areas and preserves aspect ratios. Touch targets remain at least 44 points for the new controls. Fit rows are compact at standard sizes so the garment stage, first two rows, Add a piece, and Save remain visible. All selected garments can be edited by scrolling. Accessibility sizes stack row actions below garment details and use a single grid column.

The screenshots use an isolated sample wardrobe, so counts, garment codes, ordering, and some photos differ from the illustrations. Generated tee and trousers images replaced only preview demo images, with original files backed up outside the repository. The loafers were imported through the existing local Add Item flow. None of these fixtures was added to the app bundle or the user's wardrobe.

## Resolved findings

| Priority | Finding | Resolution |
| --- | --- | --- |
| P1 | Build with this reused an open builder without applying the newly selected garment. | Give each explicit build request a new destination identity; reload the saved composition and keep the requested piece. Verified with different and repeated garments. |
| P2 | Keep/Swap squeezed garment names at the largest text size. | Stack actions below details at accessibility sizes; keep names and codes readable. |
| P2 | Add a piece required scrolling past every selected garment. | Keep Add a piece in the action rail above Save. |
| P2 | The initial fit stage and row spacing obscured the second editing row. | Use compact standard rows and preserve a larger garment stage. |
| P2 | Grid accessibility announced repeated image/name/code labels. | Expose one descriptive garment element per tile. |

## Verification

| Check | Result |
| --- | --- |
| Native Debug build, iPhone 18 Pro simulator, iOS 27 | Passed. Existing App Intents metadata warning remains. |
| Composition, builder, filtering, image resolution, and saved-fit tests | Passed: 32 tests, 0 failures, including 6 composition/draft regressions. |
| Gallery snapping, Gallery/Grid switch, details, and existing search | Passed. Search with no matches exposes Clear all and recovers. |
| Build from garment, Keep/unlock, per-slot swap, preserving other pieces | Passed through the rendered UI. |
| Back to Fits, Continue your fit, and app relaunch | Passed; selections and kept pieces survive. |
| Save complete fit and reopen its details | Passed; all 4 garment codes remain present and the draft entry clears. |
| Incomplete fit, empty closet, empty Fits, empty builder | Passed; incomplete/empty drafts cannot be saved. Empty states used a disposable isolated app, removed after QA. |
| Light/dark appearance and largest accessibility text size | Passed for Closet Gallery, Grid, and Fit builder. |
| Local import from the builder | Passed. Existing cutout failure fallback saved the original transparent fixture and added it to the fit. This is not a segmentation-quality test. |
| `git diff --check` | Passed. |

A signed Debug build was subsequently installed and foregrounded on the connected iPhone 17 Pro Max running iOS 27. A screenshot confirmed the approved Closet layout with the existing wardrobe. Physical-phone interactions, manual VoiceOver gestures, and forced storage-write failures were not run. The review does not claim coverage of every supported device size.

## Data and scope

The working composition stores garment IDs and kept slots in the versioned local preference `pyxis.outfitComposition.v1`. The SwiftData wardrobe schema and existing saved outfits are unchanged. Save uses the existing outfit/memory transaction; failure rolls back that transaction and keeps the working draft.

The approved app icon is retained. No version bump, PR, push, merge, or release was performed. The primary checkout's unrelated work remains separate.
