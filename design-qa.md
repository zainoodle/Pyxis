# Editorial dark Closet — implementation QA

final result: passed for the initial gallery pass

The later compact-header and cross-screen review supersedes this header: [cohesive UI review](docs/COHESIVE_UI_REVIEW.md).

## Target and scope

Selected reference: `docs/design-assets/editorial-reference.png` (853 × 1844).
Rendered native app: `docs/ui-evidence/editorial-archive-dark.png` (1206 × 2622; iPhone 18 Pro, 402 × 874 points, 3× density, iOS 27 simulator).

The reference and final capture were opened together in one comparison input. Compare their common portrait aspect ratio at equal displayed width; the implementation also reserves the native status safe area. The user explicitly requested keeping IBM Plex Mono, so the reference's serif heading is intentionally replaced by the existing font family. This is an implementation in the existing SwiftUI app, not a static image recreation.

## Findings and iterations

1. **Resolved P1: navigation obscured the garment counter.** The existing custom bar's safe-area overlay did not reduce the TabView content frame. A root VStack now reserves the bar's measured height, and each navigation stack hides the system tab bar. Final capture shows all three caption lines above the divider.
2. **Resolved P2: image and caption diverged after a text-size layout change.** A ScrollViewReader restores the bound selection when the gallery's dimensions, item IDs, or presentation change. Verified second-item selection before and after changing Dynamic Type, plus tab and detail round trips.
3. **Resolved P2: large images fell back to catalog thumbnails.** Added a full-size resolver that prefers a cutout and otherwise uses the original. The final capture shows fabric detail without thumbnail enlargement. A regression test covers cutout priority and skipping the thumbnail fallback.
4. **Resolved P2: tab labels truncated at maximum accessibility size.** Navigation labels now scale through xxxLarge, with complete accessibility labels. Gallery metadata retains full Dynamic Type scaling and becomes vertically scrollable when necessary.

## Required fidelity surfaces

- **Fonts/typography:** IBM Plex Mono Light/Regular/Medium retained. Large Closet heading, tracked brand and garment name, quieter category/counter. The serif difference is explicitly requested. No new font files.
- **Spacing/layout:** unboxed browsing controls, a single central garment, centered caption, full-width divider and three tabs. Native safe areas and the existing mono font metrics make the garment stage shorter than the concept. The full garment remains visible; adjacent-piece visibility varies with the actual photo's silhouette and whitespace. This is accepted for a real wardrobe rather than cropping every garment to the concept image.
- **Colors/tokens:** neutral black `#161618`, charcoal surfaces `#1E1E20`/`#242426`, soft ivory `#EAE7E1`, and quiet gray supporting text. A low-opacity radial light and garment shadow supply depth. Decorative light is suppressed for increased contrast/reduced transparency. Light color tokens remain unchanged.
- **Image quality:** generated transparent wool overshirt imported using the normal Photo Library flow in a separate preview app. Final hero uses the original resolution, preserving texture and alpha. Existing cutouts continue to use automatic framing. The photo is a QA fixture only; it is not bundled into the app. Actual photos determine garment shape, texture and surrounding whitespace.
- **Copy/content:** Closet, All pieces, Wool overshirt, Outerwear and three navigation labels match the intended content roles. Count is live `01 / 15`, reflecting the preview catalog rather than the concept's invented 24 items. No design-process language appears in app UI.

The full-view paired comparison exposes all controls and small labels legibly; a separate focused crop was not needed.

## Verification

**Passed**

- Debug simulator build of Pyxis, isolated bundle `com.zainoodle.pyxis.editorialpreview`.
- 15 tests: FilteringTests, GarmentImageFramingTests, ClosetItemImageResolverTests; zero failures.
- `git diff --check`.
- Normal Photo Library import, automatic save, metadata editing and garment display.
- Horizontal snapping: image, name, category and index update together.
- Outerwear category reduces catalog to three pieces; selected item remains paired with its image.
- Search query, selecting a result, detail/back, clearing query, no-match state and Clear all.
- Sort & filter sheet opens and dismisses.
- Fits/Closet tab round trip preserves selection.
- Maximum accessibility text: selected image stays correct and vertical scroll reaches the complete caption/count. Evidence: `docs/ui-evidence/editorial-archive-accessibility.png`.
- Initial-pass Light appearance retained the grid and original search layout (superseded by the shared compact header and search sheet in the cohesive review). Evidence: `docs/ui-evidence/editorial-archive-light.png`.

**Not run**

- Physical-device acceptance and VoiceOver gesture traversal.
- Every filter combination, rotation and all supported device sizes; these remain in `docs/MANUAL_QA.md`.

## Implementation checklist

- [x] Keep the existing font family.
- [x] Apply charcoal palette and restrained lighting.
- [x] Implement the native gallery and quieter header/browse controls.
- [x] Connect existing data, detail navigation, import, search and filtering.
- [x] Reserve real layout space for navigation and preserve selection through layout changes.
- [x] Verify rendered dark/light and accessibility layouts, and add regression coverage.

All work remains local on `codex/editorial-archive`, based on `codex/closet-category-menu` (`faebe57`). No remote PR activity.
