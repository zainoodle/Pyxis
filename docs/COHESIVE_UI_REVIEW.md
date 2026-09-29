# Cohesive editorial UI review

## Result

Implemented and verified locally on `codex/editorial-archive`. The compact Closet mockup selected by the user now defines the primary header across Closet, Fits, and Profile. IBM Plex Mono and the black/charcoal palette are retained. Overall: the reviewed flows have a consistent hierarchy with no blocking layout issue at the tested sizes.

## Review and changes

1. **Closet — competing headings.** The wordmark, oversized title, and separate search row consumed too much vertical space. Replaced them with one 32-point title and search/add group, with All pieces below. On the 402 × 874-point simulator, the garment stage starts at y174 instead of y268: 94 points recovered. [Before](ui-evidence/cohesive-headers/01-closet-before.png) / [After](ui-evidence/cohesive-headers/01-closet-after.png).
2. **Fits — too many controls before content.** Consolidated favorites, sort, color, and season into All fits; moved search into a sheet. Empty Fits hides irrelevant browse controls and offers Create a fit. [Before](ui-evidence/cohesive-headers/02-fits-before.png) / [Empty after](ui-evidence/cohesive-headers/02-fits-after.png) / [Populated after](ui-evidence/cohesive-headers/07-fits-populated.png).
3. **Profile — inconsistent title and branding.** Uses the same primary header, calmer Wardrobe links, consistent margins, and a small PYXIS footer. [Before](ui-evidence/cohesive-headers/03-profile-before.png) / [After](ui-evidence/cohesive-headers/03-profile-after.png).
4. **Builder and Add — repeated labels.** Removed the redundant Your fit heading, retained the piece count, and simplified the clothing tray. Add item becomes Add piece, with Photo / Clean up / Details steps. [Builder before](ui-evidence/cohesive-headers/04-builder-before.png) / [Builder after](ui-evidence/cohesive-headers/04-builder-after.png); [Add before](ui-evidence/cohesive-headers/05-add-before.png) / [Add after](ui-evidence/cohesive-headers/05-add-after.png).
5. **Secondary screens — title consistency.** Shared mono inline titles now cover detail, search, sort/filter, Closets, Fit passport, and try-on support screens while retaining native back navigation. Fit passport has shorter supporting copy and section labels. [Before](ui-evidence/cohesive-headers/06-passport-before.png) / [After](ui-evidence/cohesive-headers/06-passport-after.png).
6. **Accessibility layout findings, resolved.** At maximum text size, the Fits count squeezed All fits, and Profile icons competed with text. Fits now stacks its count and uses one content column; Profile uses compact icons and leading-aligned multiline labels. [Fits](ui-evidence/cohesive-headers/08-fits-accessibility.png), [Profile](ui-evidence/cohesive-headers/09-profile-accessibility.png), [Closet](ui-evidence/cohesive-headers/10-closet-accessibility.png).

## Visual comparison

The selected compact-header mockup and final native Closet screenshot were inspected together in one tool output. The title/actions/category arrangement matches the selected direction. The app retains the native status area and shows the complete garment and caption; the mockup cropped the garment. Colors, font family, side margins, action grouping, and quiet supporting labels are consistent across the reviewed screens. Main navigation labels retain their existing uppercase style. Small native system controls retain their platform treatment.

Preview catalog contains DEBUG demo shapes and one imported wool overshirt. Black labels embedded in demo images are fixture artwork, not new UI labels. No generated garment is bundled into the app.

## Verification

**Passed**

- Debug simulator build, isolated preview bundle `com.zainoodle.pyxis.editorialpreview`, iPhone 18 Pro / iOS 27.
- 26 existing targeted tests across FilteringTests, ClosetItemImageResolverTests, OutfitBuilderServiceTests, and OutfitGalleryServiceTests; zero failures.
- `git diff --check`.
- Closet search by wool, result visibility, query clearing, Add piece opening and canceling.
- Fits creation/save, search by clothing name, result/detail navigation, favorites with no matches, and Clear all restoring the saved fit.
- Profile navigation to Fit passport and Closets, including back navigation.
- Rendered dark primary screens and supporting flows; maximum Dynamic Type on Closet, Fits, and Profile.
- Light Closet and Fits retain the shared header and readable content. [Closet](ui-evidence/cohesive-headers/11-closet-light.png) / [Fits](ui-evidence/cohesive-headers/12-fits-light.png).

**Not run in this pass**

- Physical-device acceptance, full VoiceOver traversal, rotation, and other screen sizes.
- Live AI try-on generation, remote requests, and every secondary form interaction. Those screens received shared-title styling, not changes to their service logic.

All verification used the separate preview app. Changes remain local; no PR or push was requested.

## Follow-up: restore garment codes

Restored the existing IBM Plex Mono `ItemCodeLabel` beneath the garment name in the dark gallery and in Closet search results. Name tracking matches the existing grid. Category and position share the third caption line, keeping the compact layout. Stored codes and their generation format are preserved.

Passed: simulator build, `git diff --check`, rendered gallery/search inspection, searching for `OT-001`, and clearing search. [Gallery](ui-evidence/cohesive-headers/13-restored-item-code.png) / [Code search](ui-evidence/cohesive-headers/14-item-code-search.png).
