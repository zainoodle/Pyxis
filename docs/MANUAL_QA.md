# Pyxis Manual QA

Run this checklist on iPhone or iOS Simulator after Xcode builds the `Pyxis` scheme and `./script/build_and_run.sh --verify` launches the app on a booted simulator.

1. Launch Pyxis.
2. Confirm the first screen is the closet grid.
3. Confirm the empty state says `ADD FIRST ITEM`.
4. On a Release build, confirm `SEED CLOSET` is not visible.
5. Press `Command+N`.
6. Press `Escape` and confirm the add sheet closes.
7. Press `Command+N` again.
8. On a Release build, confirm `DEMO IMAGE` is not visible in the import step.
9. On a physical iPhone, tap `TAKE PHOTO`, approve camera access, capture a clothing item, and choose `Use Photo`; on Simulator, confirm the unavailable camera action cannot be opened. Repeat the add flow with `PHOTO LIBRARY` or `CHOOSE FILE` to confirm existing imports still work.
10. Confirm the original preview appears.
11. Confirm background removal starts without blocking the UI.
12. Confirm a cutout appears, or the failure state says `BACKGROUND REMOVAL FAILED — RETRY`.
13. With a photo where hands or arms sit beside the garment, confirm small detached body fragments are excluded; with a pair of shoes, confirm both pieces remain.
14. With `PYXIS_AI_BASE_URL` configured, tap `AI DE-WRINKLE`, confirm the disclosure appears before the action, and verify the generated result replaces the cutout preview while the original remains stored.
15. Build a fit, tap `TRY THIS FIT ON YOU`, choose a full-body photo, generate, and confirm the person and selected garments are sent only after tapping the generate button. Confirm offline/backend failures remain retryable.
16. Compare AI results with the originals and confirm the interface does not describe the try-on as a size or fit guarantee.
17. Open `MORE > MY SIZE`, save a partial profile, close and reopen it, and confirm the values persist.
18. Toggle between imperial and metric units twice and confirm profile values and retailer chart ranges convert without drift or reinterpretation.
19. Enter three retailer size-chart rows and confirm the result names the likely size, measurements used, preferred fit, confidence, and fit disclaimer. Remove comparable chart fields and confirm no recommendation is invented.
20. Confirm `DELETE FIT PASSPORT` is available after a profile has been saved.
21. Enter a body measurement outside every supplied chart range and confirm Pyxis returns no recommendation. Enter foot length and footwear ranges and confirm footwear sizing uses only foot length.
22. Delete the Fit Passport, cancel the confirmation, and confirm the values remain; repeat and confirm deletion.
23. Start importing a photo, wait for processing, close without saving, and confirm the draft image files are removed from `Application Support/Pyxis/Images`.
24. Confirm category, subtype, and color suggestions are populated.
25. Edit display name, brand, size, tags, notes, category, subtype, color, and favorite.
26. Save the item.
27. Confirm the item appears in the grid with the same product-style code shown during Studio Snap.
28. Scroll rapidly through a seeded closet and swipe outfit rows; confirm images appear without blocking scrolling or repeatedly flashing `NO IMAGE`.
29. Quit Pyxis, relaunch it, and confirm the item persists.
30. Open `FILTERS`; select a closet, category, and color, then confirm each filter affects the grid. Clear filters and confirm the full collection returns.
31. Press `Command+F` and search by item code, display name, brand, tag, notes, category, subtype, and color.
32. Open item detail, toggle original/cutout, retry background removal, edit metadata, press `Escape`, reopen detail, and confirm the edits persisted.
33. Open closet management, outfit builder, saved fits, and fit detail when available; press `Escape` in each and confirm the sheet closes.
34. In the outfit builder, build and save both a shirt/pants/shoes fit and a one-piece/shoes fit. Confirm selecting a one-piece clears separates and selecting a separate clears the one-piece.
35. With no saved fits, open `SAVED FITS`, tap `BUILD A FIT`, and confirm the builder opens after the gallery closes.
36. Open a saved fit, duplicate it, share its text summary, then cancel and confirm its delete dialog. Delete the duplicate and confirm closet items remain.
37. Delete a closet item used by a saved fit and confirm fit detail reports the missing item.
38. During background removal, confirm the Studio Snap surface shows `SAVING CLEAN ITEM`, the item subtype, candidate item code, a small settling contact shadow, and a restrained finish sparkle; turn on Reduce Motion and confirm no sweep animation plays.
39. With a large accessibility text size, confirm navigation, sizing fields, filters, builder rows, and saved-fit actions remain readable and tappable. Use VoiceOver to confirm measurement names and selected outfit items are announced.
40. Tap `WORE TODAY`; confirm the wear count increments and the last-worn date becomes today after closing and reopening the item.
41. Tap `DELETE ITEM`, cancel the confirmation, and confirm the item remains. Repeat, confirm deletion, and confirm the item and related image files disappear.
42. Run `./script/build_and_run.sh --verify` twice and confirm the second run terminates the existing simulator app before launching a fresh process.
43. Disconnect network and repeat launch/import/save/search to confirm core local behavior remains available.
