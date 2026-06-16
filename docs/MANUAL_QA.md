# ARCHIVE Manual QA

Run this checklist on iPhone or iOS Simulator after Xcode builds the `ARCHIVE` scheme and `./script/build_and_run.sh --verify` launches the app on a booted simulator.

1. Launch ARCHIVE.
2. Confirm the first screen is the closet grid.
3. Confirm the empty state says `ADD FIRST ITEM`.
4. Press `Command+N`.
5. Import a clothing image with the file picker.
6. Confirm the original preview appears.
7. Confirm background removal starts without blocking the UI.
8. Confirm a cutout appears, or the failure state says `BACKGROUND REMOVAL FAILED — RETRY`.
9. Confirm category, subtype, and color suggestions are populated.
10. Edit display name, brand, size, tags, notes, category, subtype, color, and favorite.
11. Save the item.
12. Confirm the item appears in the grid with a product-style code below it.
13. Quit ARCHIVE.
14. Relaunch ARCHIVE.
15. Confirm the item persists.
16. Filter by category.
17. Filter by color.
18. Press `Command+F` and search by item code.
19. Search by display name, brand, tag, notes, category, subtype, and color.
20. Open item detail.
21. Toggle original/cutout view.
22. Retry background removal.
23. Edit metadata in detail and close/reopen detail.
24. Delete the item.
25. Confirm the item disappears from the grid.
26. Inspect `Application Support/ARCHIVE/Images` and confirm related original, cutout, and thumbnail files are cleaned up.
27. Disconnect network and repeat launch/import/save/search to confirm local-only behavior.
