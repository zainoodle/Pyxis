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
9. Import a clothing image from Photos or Files.
10. Confirm the original preview appears.
11. Confirm background removal starts without blocking the UI.
12. Confirm a cutout appears, or the failure state says `BACKGROUND REMOVAL FAILED — RETRY`.
13. Confirm category, subtype, and color suggestions are populated.
14. Edit display name, brand, size, tags, notes, category, subtype, color, and favorite.
15. Save the item.
16. Confirm the item appears in the grid with a product-style code below it.
17. Quit Pyxis.
18. Relaunch Pyxis.
19. Confirm the item persists.
20. Filter by category.
21. Filter by color.
22. Press `Command+F` and search by item code.
23. Search by display name, brand, tag, notes, category, subtype, and color.
24. Open item detail.
25. Toggle original/cutout view.
26. Retry background removal.
27. Edit metadata in detail, press `Escape`, reopen detail, and confirm the edits persisted.
28. Open closet management, outfit builder, saved fits, and fit detail when available; press `Escape` in each and confirm the sheet closes.
29. Delete the item.
30. Confirm the item disappears from the grid.
31. Inspect `Application Support/Pyxis/Images` and confirm related original, cutout, and thumbnail files are cleaned up.
32. Run `./script/build_and_run.sh --verify` twice and confirm the second run terminates the existing simulator app before launching a fresh process.
33. Disconnect network and repeat launch/import/save/search to confirm local-only behavior.
