---
type: changed
bump: minor
area: outfits
summary: Create outfits within Fits using a visual composition of garments from your closet.
---

## Details

- Consolidate the bottom navigation into Closet, Fits, and Profile. Create Outfit opens from Fits or a closet item.
- Replace the free builder's avatar stage with a garment composition and a horizontal tray of real closet images. The initial fit chooses a top, bottom, and shoes when available; layers and accessories are optional.
- Keep one Save Fit action. Saving returns to the Fits gallery. The Try On Pro action opens the existing try-on flow with its purchase and photo-consent steps.
- Preserve local outfit records and image storage. No migration or new photo upload path is introduced.

## Verification

- `./scripts/test.sh`: 138 passed.
- `python3 -m unittest discover -s tests/workflow -v`: 25 passed.
- iPhone 17 Pro Max simulator: three-tab navigation, opening the builder from Fits, adding a bag, and saving a four-piece fit passed.
- iPhone 17 Pro Max simulator: opening Create Outfit from a closet item selected that item in the fit.
- Light appearance builder: visually checked on iPhone 17 Pro Max simulator.
- Final iPhone 17 Pro Max simulator and signed physical iPhone builds: passed.
- Updated build installed and launched on the paired iPhone in dark appearance.
