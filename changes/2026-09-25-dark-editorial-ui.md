---
type: changed
bump: patch
area: design
summary: Bring the dark appearance across Closet, Build, Fits, and Profile in line with the editorial outfit mockup.
---

## Details

- Add a charcoal palette (#232325), bundled IBM Plex Mono, spaced headings, warm white accents, soft control glow, and a flat four-section navigation bar in dark appearance.
- Lead Fits with saved outfit flat lays and working search, color, season, favorite, and sort controls; place locally generated looks after the saved collection.
- Keep original garment colors and carry the styling into Closet, item and fit details, a restrained avatar stage in Build, and Profile. Add quick category filters and a readable sort menu to Closet.
- Keep clothing selection in the rows below the stage so the avatar area stays clear.
- Preserve the light palette and local data. Shared typography uses bundled fonts with Dynamic Type support; glow is reduced for accessibility preferences. No runtime font download, migration, or photo upload is needed.

## Verification

- `./scripts/test.sh`: 137 passed.
- `python3 -m unittest discover -s tests/workflow -v`: 25 passed.
- iPhone 17 Pro simulator build: passed.
- Dark Closet, Build, Fits, fit detail, and Profile: visually checked on iPhone 17 Pro simulator; screenshots in `docs/ui-evidence/dark-editorial-*.png`.
- Light Closet and dark Closet at an accessibility text size: simulator smoke checks passed.
- Signed physical-device build: passed. Current iPhone installation is blocked while the device is disconnected.
- Bundled Light, Regular, and Medium fonts and UIAppFonts registration: verified in the built app.
