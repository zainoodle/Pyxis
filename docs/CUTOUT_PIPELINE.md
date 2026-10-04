# Local garment cutouts

New imports and both Improve Cutout entry points share `LocalBackgroundRemovalService`.

1. Store and orient the original photo.
   Transparent product photos that pass alpha review keep their supplied silhouette and skip segmentation; frame them and save a PNG.
2. Use Vision foreground instances as an approximate location hint.
3. Choose three distributed interior points in the dominant foreground region. A comparable neighboring piece gets an additional point to support paired shoes. If Vision produces no hint, use three distributed interior points at normalized (0.35, 0.5), (0.65, 0.5), and (0.5, 0.75).
4. Run bundled SAM 2 Tiny image, prompt, and mask encoders on device. Select a mask with predicted quality of at least 0.75 that contains the prompts and passes the existing area/density/edge checks.
5. Remove small detached regions, fill only tiny enclosed holes, and interpolate mask logits before producing full-resolution alpha. Tighten the matte by up to one source pixel and feather it to reduce weak background rims on light and dark surfaces.
6. Review rendered alpha, trim transparent margins, and add an 8% garment-relative margin. Save a PNG and thumbnail.

SAM is a prompted object-segmentation model, not a clothing classifier. Confidence and geometry checks cannot guarantee that attached hands, hanger parts, or a wrong foreground subject are excluded. Flat-lay/hanger photographs are the primary target; difficult backgrounds, lace, and multi-object scenes still need representative QA.

Unreadable source files are rejected before storage and cannot become savable original-only items. The editor returns to the photo chooser with a corrective message. If inference or review fails for a decodable photo, the import retains its original. A failed improvement retains the last accepted cutout and thumbnail. The old Vision mask is never silently accepted as the final replacement. No schema changes, automatic rewrites of old cutouts, or photo uploads are introduced. Existing items adopt the new processing when Improve Cutout is used.

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

### Current verification — October 2, 2026

- Swift suite: 192 passed, one optional integration skipped. Optional integration passed separately with Vision hint and no hint using the bundled compiled models.
- Opaque overshirt extraction succeeded natively on iOS 27 Simulator and through actual PhotosPicker on iOS 26.5 Simulator. Save, relaunch and original recovery were exercised. Physical camera and inference are unverified in this pass because the paired phone is unreachable.
- The original Float16 decoder output produced zero masks on the tested simulator path. The packaged decoder now publishes Float32 masks/scores while preserving byte-identical Float16 learned weights, input interfaces, specification 8, and iOS 17 availability. Simulator uses CPU compute; physical-device compute policy remains unchanged. No quality/area/prompt checks were relaxed.
- `scripts/prepare_sam_decoder.py` reproduces the output conversion with coremltools 9.0 and verifies the pinned upstream model and unchanged weights. `assets/Models/SAM2-MODELS.md` records the precise contract; `sam2-manifest.json` retains upstream and current checksums. Conversion is a build preparation tool, not a runtime dependency.
- Core Image crop coordinates now correctly handle top-first alpha scans; asymmetric-margin regression passes. Rotations stage the full image set, preserve EXIF orientation and JPEG encoding, and roll back partial writes. Replacing a stored image invalidates both mounted views and the shared image cache.
- One opaque fixture is not representative extraction accuracy. Edge/neckline artifacts, hands, lace and difficult foregrounds still require photo QA. Historical hardware evidence below predates the converted decoder and does not verify it on a phone.

### Historical verification — 2026-09-27

- Default Swift suite: 149 passed, one private-fixture integration test skipped.
- Local suite with the actual failing shirt photo: 150 passed.
- Signed iPhone Debug build and installation: passed.
- Production pipeline on the connected iPhone using that same original: succeeded in 8.48 seconds including first model load and file processing. Inspected the device-produced PNG: wooden table, hanger, and nearby objects were removed; full shirt retained.
- This is one real-photo hardware check, not a representative accuracy benchmark or a hands-removal guarantee. Interactive tapping of the retry button was not part of this diagnostic; retry state/persistence behavior has regression coverage.
