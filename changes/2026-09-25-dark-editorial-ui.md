---
type: changed
bump: patch
area: design
summary: Bring the dark appearance across Closet, Build, Fits, and Profile in line with the editorial outfit mockup.
---

## Details

- Add a near-black palette, spaced monospaced headings, outlined controls, and a flat four-section navigation bar in dark appearance.
- Lead Fits with saved outfit flat lays and working search, color, season, favorite, and sort controls; place locally generated looks after the saved collection.
- Lighten dark garment cutouts for contrast and carry the same styling into Closet, item and fit details, the spinning Build stage, and Profile.
- Keep the light appearance and existing local data unchanged. No font download, migration, or photo upload is needed.

## Verification

- `./scripts/test.sh`: 137 passed.
- `python3 -m unittest discover -s tests/workflow -v`: 25 passed.
- iPhone 17 Pro simulator build: passed.
- Dark Closet, Build, Fits, fit detail, and Profile: visually checked on iPhone 17 Pro simulator; screenshots in `docs/ui-evidence/dark-editorial-*.png`.
- Light Closet: simulator smoke check passed with the existing light layout.
