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
14. Confirm category, subtype, and color suggestions are populated.
15. Edit display name, brand, size, tags, notes, category, subtype, color, and favorite.
16. Save the item.
17. Confirm the item appears in the grid with the same product-style code shown during Studio Snap.
18. Scroll rapidly through a seeded closet and swipe outfit rows; confirm images appear without blocking scrolling or repeatedly flashing `NO IMAGE`.
19. Quit Pyxis.
20. Relaunch Pyxis.
21. Confirm the item persists.
22. Open `FILTERS`; select a closet, category, and color, then confirm each filter affects the grid.
23. Clear filters and confirm the grid returns to the full collection.
24. Press `Command+F` and search by item code.
25. Search by display name, brand, tag, notes, category, subtype, and color.
26. Open item detail.
27. Toggle original/cutout view.
28. Retry background removal.
29. Edit metadata in detail, press `Escape`, reopen detail, and confirm the edits persisted.
30. Open closet management, outfit builder, saved fits, and fit detail when available; press `Escape` in each and confirm the sheet closes.
31. In the outfit builder, change a shirt, pants, or shoes selection and confirm the `CURRENT FIT` preview updates before saving.
32. During background removal, confirm the Studio Snap surface shows `SAVING CLEAN ITEM`, the item subtype, candidate item code, a small settling contact shadow, and a restrained finish sparkle; turn on Reduce Motion and confirm no sweep animation plays.
33. Tap `WORE TODAY`; confirm the wear count increments and the last-worn date becomes today after closing and reopening the item.
34. Tap `DELETE ITEM`, cancel the confirmation, and confirm the item remains.
35. Tap `DELETE ITEM` again, confirm deletion, and confirm the item disappears from the grid.
36. Inspect `Application Support/Pyxis/Images` and confirm related original, cutout, and thumbnail files are cleaned up.
37. Run `./script/build_and_run.sh --verify` twice and confirm the second run terminates the existing simulator app before launching a fresh process.
38. Disconnect network and repeat launch/import/save/search to confirm local-only behavior.
