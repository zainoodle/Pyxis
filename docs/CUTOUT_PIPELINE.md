# Local garment cutouts

New imports and both Improve Cutout entry points share `LocalBackgroundRemovalService`.

1. Store and orient the original photo.
   Transparent product photos that pass alpha review keep their supplied silhouette and skip segmentation; frame them and save a PNG.
2. Use Vision foreground instances as an approximate location hint.
3. Choose three distributed interior points in the dominant foreground region. A comparable neighboring piece gets an additional point to support paired shoes. If Vision produces no hint, use three central points.
4. Run bundled SAM 2 Tiny image, prompt, and mask encoders on device. Select a mask with predicted quality of at least 0.75 that contains the prompts and passes the existing area/density/edge checks.
5. Remove small detached regions, fill only tiny enclosed holes, and interpolate mask logits before producing full-resolution alpha. Tighten the matte by up to one source pixel and feather it to reduce weak background rims on light and dark surfaces.
6. Review rendered alpha, trim transparent margins, and add an 8% garment-relative margin. Save a PNG and thumbnail.

SAM is a prompted object-segmentation model, not a clothing classifier. Confidence and geometry checks cannot guarantee that attached hands, hanger parts, or a wrong foreground subject are excluded. Flat-lay/hanger photographs are the primary target; difficult backgrounds, lace, and multi-object scenes still need representative QA.

If inference or review fails, the import retains its original. A failed improvement retains the last accepted cutout and thumbnail. The old Vision mask is never silently accepted as the final replacement. No schema changes, automatic rewrites of old cutouts, or photo uploads are introduced. Existing items adopt the new processing when Improve Cutout is used.

## Garment presentation and local crease smoothing

The closet gallery, garment detail, builder carousel, and import preview share a softly lit stage in light and dark appearances. Framing balances opaque area with width and height limits: wide shoe pairs and narrow trousers retain their proportions without clipping. Original photos remain fitted normally.

The import editor offers Current / Light / Dark backgrounds for checking the same transparent cutout. This preview choice does not change the app appearance or bake a background into the stored PNG.

Soften small creases applies local noise reduction with a difference mask that protects strong details such as seams and buttons. It restores the source alpha and never changes the original photo. Restore natural texture returns the exact natural cutout bytes during that draft; rotation also rotates the natural version. Saving stores the selected finish, and Improve Cutout starts again from the retained original. This conservative treatment cannot reconstruct heavy folds or guarantee wrinkle removal. Optional AI de-wrinkle remains a separate, explicitly selected photo upload.

## Local verification

`./scripts/test.sh` covers prompt placement, paired components, isolated scraps, weak mask residue, tiny holes versus openings, malformed masks, framing, transparent imports, alpha/detail preservation, exact smoothing reversal, rotation, and retry preservation. The model integration case skips unless all three environment variables are set:

- `PYXIS_CUTOUT_FIXTURE`: absolute path to a private source photo.
- `PYXIS_CUTOUT_MODELS`: directory containing the three compiled `.mlmodelc` packages.
- `PYXIS_CUTOUT_OUTPUT`: absolute path for the resulting PNG.

Compile packages with `xcrun coremlcompiler compile <package> <output-directory>` under full Xcode, then set those variables when running `./scripts/test.sh`. Never commit private wardrobe fixtures or results.

For a Debug iPhone build, launch with arguments `-pyxis.cutoutDiagnostic Images/Originals/<filename>`. The opt-in diagnostic uses the production service and isolated temporary storage; it does not update wardrobe records. Read `tmp/Pyxis-CutoutDiagnostic/result.json` in the app data container for status, elapsed seconds, and the relative cutout path. The output path is relative to that diagnostic directory. Relaunch normally after testing. Release builds omit the diagnostic.

For a Debug simulator build, `-pyxis.importFixture <absolute-local-image-path>` opens the import editor with a local fixture. It exercises production processing and draft cleanup without saving a wardrobe item until Save piece is pressed. Release builds omit this entry point. Keep fixtures outside the repository.

### Verified on 2026-09-27

- Default Swift suite: 149 passed, one private-fixture integration test skipped.
- Local suite with the actual failing shirt photo: 150 passed.
- Signed iPhone Debug build and installation: passed.
- Production pipeline on the connected iPhone using that same original: succeeded in 8.48 seconds including first model load and file processing. Inspected the device-produced PNG: wooden table, hanger, and nearby objects were removed; full shirt retained.
- This is one real-photo hardware check, not a representative accuracy benchmark or a hands-removal guarantee. Interactive tapping of the retry button was not part of this diagnostic; retry state/persistence behavior has regression coverage.
