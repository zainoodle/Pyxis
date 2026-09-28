---
type: changed
bump: minor
area: closet
summary: Replace the accordion closet rail with a curved garment gallery driven by a continuous drag offset.
---

## Details

- Rework the Closet screen into an editorial garment gallery after Scrolltide's "Media Gallery" reference: portrait cards stand on a shallow concave ring, smallest at the farthest middle slot, growing larger and leaning inward toward the edges.
- Solve card positions in projected space by integrating scaled half-widths, keeping the gaps between projected card edges even instead of bunching where perspective compresses.
- Drive position, scale, lean, lift, and depth from one continuous offset. Horizontal drag tracks 1:1, rubber-bands past the ends, and on release projects momentum and springs to the nearest card, which becomes the selection.
- Capture the presentation-layer offset through an animatable reporter so a new drag can pick up mid-settle without a jump.
- Move the item code and favorite heart into a counter-positioned overlay pass so they stay legible and tappable at every arc position; hearts appear on cards near enough to host a comfortable target.
- Keep the washed charcoal texture backdrop, slim hairline card outlines, translucent dark card surfaces, and the soft ivory glow feathering up behind the selected garment. Light appearance stays functional with the same geometry.
- Preserve search, filters, sorting, favorites, add-item, VIEW ITEM navigation, and outfit-building entry points. Empty, single-item, and filtered states behave as before; selection re-resolves when filters change.
- DEBUG launch arguments: `-pyxisSeedCloset` seeds the sample closet on appear, `-pyxisGalleryDemo` sweeps the gallery offset for headless motion capture.
- Raise the deployment target to iOS 26.

## Verification

- Build for iPhone 17 Pro simulator (iOS 26): passed.
- Swift suite: 150 passed, 1 skipped.
- Simulator screenshots: dark washed-charcoal gallery with five-to-six visible garments, even projected gaps, inward lean, code/heart overlays, and bottom-edge glow; light appearance verified.
- Motion capture: `-pyxisGalleryDemo` sweep frames stitched into a short clip; interactive drag feel needs device verification.
- Tap-versus-drag disambiguation (10 pt drag threshold over card buttons) is verified by construction, not by instrumented touch playback.
