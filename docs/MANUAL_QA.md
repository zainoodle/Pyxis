# Pyxis Manual QA

Run this checklist on iPhone or iOS Simulator after Xcode builds the `Pyxis` scheme and `./scripts/build_and_run.sh --verify` launches the app on a booted simulator.

1. Launch Pyxis.
2. Confirm the first screen is Closet: a garment gallery in Dark appearance and a grid in Light appearance.
3. Confirm the empty state says `ADD FIRST ITEM`.
4. On a Release build, confirm `SEED CLOSET` is not visible.
5. Press `Command+N`.
6. Press `Escape` and confirm the add sheet closes.
7. Press `Command+N` again.
8. On a Release build, confirm `DEMO IMAGE` is not visible in the import step.
9. On a physical iPhone, tap `TAKE PHOTO`, approve camera access, capture a clothing item, and choose `Use Photo`; on Simulator, confirm the unavailable camera action cannot be opened. Repeat the add flow with `PHOTO LIBRARY` or `CHOOSE FILE` to confirm existing imports still work.
10. Confirm the stable `ADD PHOTO → CLEAN IMAGE → REVIEW DETAILS` indicator advances and the original preview appears.
11. Confirm background removal starts without blocking the UI and the labeled review form remains visible.
12. Confirm the cutout automatically fills its frame with a small margin and needs no approval step. If the mask is empty, tiny, or covers nearly the whole image, confirm `ORIGINAL ONLY` appears and the original can still be saved.
    Tap `IMPROVE CUTOUT` in Add Item and on a saved item. Confirm accepted results use the same framing and refresh the preview; rejected results retain the current cutout and thumbnail. Repeat after rotating, and confirm the stored original remains readable.
13. Test flat-lay and hanger photos against wood, patterned fabric, and a plain wall. Confirm the garment outline excludes the hanger and background. Include a hand touching the garment and nearby body parts; inspect that no skin remains and no fabric is removed. With a pair of shoes, confirm both pieces remain. These are acceptance checks, not guarantees from mask confidence alone. Repeat offline. Use the [cutout diagnostic](CUTOUT_PIPELINE.md#local-verification) to inspect the production result without modifying a saved item.
14. With `PYXIS_AI_BASE_URL` configured, tap `AI DE-WRINKLE`, confirm the disclosure appears before the action, and verify the generated result replaces the cutout preview while the original remains stored.
15. Build a fit, tap `TRY THIS FIT ON YOU`, choose a full-body photo, generate, and confirm the person and selected garments are sent only after tapping the generate button. Confirm offline/backend failures remain retryable.
16. Compare AI results with the originals and confirm the interface does not describe the try-on as a size or fit guarantee.
17. Open `PROFILE > FIT PASSPORT`, save a partial profile, go back and reopen it, and confirm the values persist.
18. Toggle between imperial and metric units twice and confirm profile values and retailer chart ranges convert without drift or reinterpretation.
19. Enter three retailer size-chart rows and confirm the result names the likely size, measurements used, preferred fit, confidence, and fit disclaimer. Remove comparable chart fields and confirm no recommendation is invented.
20. Confirm `DELETE FIT PASSPORT` is available after a profile has been saved.
21. Enter a body measurement outside every supplied chart range and confirm Pyxis returns no recommendation. Enter foot length and footwear ranges and confirm footwear sizing uses only foot length.
22. Delete the Fit Passport, cancel the confirmation, and confirm the values remain; repeat and confirm deletion.
23. Start importing a photo, wait for processing, close without saving, and confirm the draft image files are removed from `Application Support/Pyxis/Images`.
24. Confirm category, subtype, and color suggestions are populated.
25. Edit display name, brand, size, tags, notes, category, subtype, color, and favorite.
26. Save the item.
27. Confirm the saved item appears in Closet. In Dark appearance, it becomes the selected garment; open its detail to verify the same product-style code shown during Studio Snap.
28. Scroll rapidly through a seeded closet and swipe outfit rows; confirm images appear without blocking scrolling or repeatedly flashing `NO IMAGE`.
    Confirm previously saved transparent cutouts also fill their frames without changing their stored originals.
29. Quit Pyxis, relaunch it, and confirm the item persists.
30. In Dark appearance, open All pieces beneath the Closet heading. Select Tops, Bottoms, and Outerwear in turn, then toggle Favorites only. Open Sort & filter, change Sort from Newest, and select a closet, type, and color. Confirm the gallery updates and the menu label summarizes active choices. Choose All pieces and confirm category and type clear. Tap Clear all and confirm search, closet, category, subtype, color, favorites, and sort return to defaults. In Light appearance, confirm the shared compact header opens search from its magnifying glass and the garment grid remains available.
31. Leave the active search and filters applied, open an item, and return to Closet; confirm the state remains intact. Terminate and relaunch Pyxis; confirm Closet starts with the default unfiltered, newest-first catalog because filters are intentionally session-scoped.
32. Press `Command+F` and search by item code, display name, brand, tag, notes, category, subtype, and color.
33. Open item detail, toggle original/cutout, retry background removal, edit metadata, press `Escape`, reopen detail, and confirm the edits persisted.
34. Use the `CLOSET`, `BUILD`, `FITS`, and `PROFILE` tabs. Confirm each tab preserves predictable navigation, item and fit details use standard back navigation, and only focused capture/import tasks appear as sheets.
35. In the outfit builder, build and save both a shirt/pants/shoes fit and a one-piece/shoes fit. Confirm selecting a one-piece clears separates and selecting a separate clears the one-piece.
36. With no saved fits, open the `FITS` tab, tap `BUILD A FIT`, and confirm the `BUILD` tab opens directly without a modal handoff delay.
37. Open a saved fit, duplicate it, share its text summary, then cancel and confirm its delete dialog. Delete the duplicate and confirm closet items remain.
38. Delete a closet item used by a saved fit and confirm fit detail reports the missing item.
39. During background removal, confirm the Studio Snap surface shows `SAVING CLEAN ITEM`, the item subtype, candidate item code, a small settling contact shadow, and a restrained finish sparkle; turn on Reduce Motion and confirm no sweep animation plays.
40. With a large accessibility text size, confirm navigation, sizing fields, filters, builder rows, and saved-fit actions remain readable and tappable. Use VoiceOver to confirm measurement names and selected outfit items are announced.
41. Tap `WORE TODAY`; confirm the wear count increments and the last-worn date becomes today after closing and reopening the item.
42. Tap `DELETE ITEM`, cancel the confirmation, and confirm the item remains. Repeat, confirm deletion, and confirm the item and related image files disappear.
43. Run `./scripts/build_and_run.sh --verify` twice and confirm the second run terminates the existing simulator app before launching a fresh process.
44. Disconnect network and repeat launch/import/save/search to confirm core local behavior remains available.

## Editorial dark Closet regression checks

- Swipe through at least three pieces: image, name, category, and count must agree. Tap a garment, return, switch to Fits and back; selection must be preserved.
- Search from the magnifying glass, select a result, open its detail, and return. Clear search and confirm the selected garment still agrees with the caption. Try a query with no results and use Clear all.
- Filter while a later garment is selected. If the selected garment remains in the results, keep it centered; otherwise select a valid remaining garment. Check favorites with zero results.
- Import a new garment while a later garment is selected. After save, the image and caption must both refer to the new garment when it matches the active filters.
- At default text size, the entire garment caption and count must sit above the bottom navigation. Confirm only one set of tabs is exposed, and the custom bar reserves its own layout space.
- Change Dynamic Type while the second garment is selected. Its image and caption must remain paired. At the largest accessibility size, scroll the gallery vertically to reach the full caption/count; tab labels must remain readable.
- Use a transparent original without a processed cutout. The large gallery must show the original at display resolution, not an enlarged thumbnail. Keep thumbnail resolution for compact search results.
- Turn on Increase Contrast or Reduce Transparency and confirm the decorative backdrop lighting disappears. With Reduce Motion, VoiceOver Next/Previous garment actions should change selection without an animated transition.

Local verification evidence and exact checks: [editorial design QA](../design-qa.md).

## Cohesive screen hierarchy

- Closet, Fits, and Profile use the same 32-point IBM Plex Mono title, 24-point side margins, and compact top spacing. Closet and Fits group search/add together in 44-point targets.
- On Fits, open search, search by garment name, select a result, return, toggle Favorites, and clear all filters. With no saved fits, hide browse controls and offer Create a fit.
- Create and save a fit. Confirm the builder has one title, a piece count, a readable clothing tray, and reachable Save fit / Try on actions above navigation.
- Open Add piece and cancel. Confirm Photo / Clean up / Details remain legible, with the current step announced.
- Open Closets and Fit passport from Profile, then return. Check inline titles, spacing, and the native back action.
- At maximum accessibility text, Fits uses one column and stacks its browse count; Profile keeps icons compact, wraps labels left aligned, and stacks appearance choices.
- Repeat the primary header/search checks in Light appearance. Its existing garment grid and light palette remain available.

Current captures, findings, and verification: [cohesive UI review](COHESIVE_UI_REVIEW.md).
