# Pyxis native acceptance checks

Use the integrated primary checkout and record its exact build, runtime, appearance and text size. Use disposable wardrobe data. Passing core tests or launching the app does not complete this checklist. Current findings/evidence are in [UI_POLISH_AUDIT.md](UI_POLISH_AUDIT.md); release gates remain separate from visual review.

## Closet and rack

- Check gallery and grid in both appearances; layout choice is independent of appearance. Inspect dark and light clothing, shoes, wide/long garments, empty wardrobe, empty search, favorites and filtered results.
- Swipe normally, flick rapidly, reverse direction, interrupt settling and stop deceleration with a touch. Swipes must never open details; a fresh deliberate tap must. Image, code, caption and position must agree after every gesture.
- Filter/search while a later piece is selected; preserve it when still present and choose a valid neighbor otherwise. Repeat after adding/deleting a piece and switching layouts.
- Supported opaque tee/shoulder and waistband silhouettes may use a hanger/clip hint. Asymmetric, unusual-neckline, strappy, translucent or otherwise ambiguous images must gracefully remain flat. Check actual photographs: cached alpha-contour validation is not anatomical ground truth.
- Verify the hook engages the rail, supports stay behind opaque cloth, and the full silhouette stays within the stage during a small rigid swing. Garment pixels/aspect ratio must remain unchanged.
- Enable Reduce Motion: no decorative swing or neighbor fading; navigation and selection still work. Check largest text and compact/large screens: scroll to the full caption and Build action.
- Use VoiceOver on hardware for reading order, a single selected garment, activation and Next/Previous garment. Automated accessibility-tree inspection is not VoiceOver acceptance.

## Import, editing and recovery

- Use the real PhotosPicker, file importer and camera where available. Include a camera image with EXIF orientation, an opaque photo and a transparent cutout. Check photo loading, cancel, retry, invalid/unreadable input and offline use. A DEBUG fixture launcher does not replace picker/camera checks.
- Cancel during a delayed transfer and processing; confirm no abandoned draft files or late sheet changes. Drop-provider callbacks must also be ignored after dismissal.
- Inspect extraction edges against Current/Light/Dark backgrounds. Retry a rejected result; retain the accepted cutout and readable original. An incorrect result must not be accepted by weakening quality thresholds.
- Test SAM on native iOS, not just macOS. Compiled decoder outputs are FLOAT32, weights remain FLOAT16; verify the pinned bundled model files and no-Vision fallback. Broaden photographs to patterned backgrounds, hands, paired shoes, dresses and lace.
- Toggle Soften small creases and Restore natural texture; restoration must be byte-exact and original storage independent. Rotate both natural/softened states; failure must leave accepted files unchanged. Preserve EXIF display orientation and JPEG encoding.
- Edit color/category while analysis is pending. Manual choices must survive completion and retry. Inspect long names, tags, notes, keyboard and large text; Save stays unavailable during photo edits.
- Save, relaunch, reopen and toggle Use original. Verify original/cutout/thumbnail persistence. Delete only the disposable test item and confirm its associated files are removed.

## Saved garment details

- Edit metadata with Edit details expanded, then Back/Close without collapsing. Reopen and verify values, updated date and local memory search. A failed save must keep the detail visible with a useful error.
- Improve cutout and return to gallery/grid/Fits without restarting: every image consumer must show the new accepted file. Check rapid replacement during a pending decode.
- Start Improve, navigate away, reopen the same piece: Delete and a second improvement must remain unavailable until the first completes. Verify failure preserves the existing cutout/thumbnail.
- Mark Wear today and check count/date after relaunch. Cancel and then confirm deletion; fits referencing the deleted piece must explain the missing item.

## Fits, suggestions and builder

- Check no saved fits, suggestions, saved draft and populated fits. Save a suggestion, search/favorite/clear filters, open details, duplicate, share/cancel, cancel deletion and delete a duplicate. Clothing must remain.
- Build shirt/pants/shoes and one-piece/shoes fits. Selecting one-piece clears separates and vice versa. Swap/remove pieces, save, leave/resume a draft and relaunch. Inspect one-piece and multi-piece image composition.
- Inspect standard and accessibility sizes, light/dark, keyboard, long names and missing-piece states. Essential Save/Build actions stay reachable.
- Exercise the actual configured AI service's availability, disclosure/consent, failed requests, cancellation/retry and success when authorized. Missing configuration must remain honest; a mocked transport test is not live generation or purchase acceptance. Never introduce a new photo-upload service for QA.

## Profile, Measurements and Closets

- Profile appearance controls preserve geometry/hierarchy in both themes. Check all navigation and supporting screens with largest text.
- Save/reopen partial measurements; switch units twice without drift. Nonempty invalid/zero/negative/nonfinite input must show an error before changing persisted values. Empty optional fields may clear a measurement deliberately.
- Supply retailer chart ranges and check matching size, unmatched size and no comparable measurements. Changing category/chart clears stale recommendations. Verify footwear uses foot length and keep the fit disclaimer.
- Cancel and confirm profile deletion. Create/rename a closet, edit membership, relaunch, cancel and confirm group deletion; garments remain. Duplicate names explain the conflict. Keyboard Done and large-text controls remain usable.
- Browse a closet through Closet's existing filter; Profile management does not offer a disconnected Select control.

## Release and device matrix

- Run relevant package, workflow/backend and static privacy/configuration checks; build the final Debug simulator and Release device artifact after all source changes.
- Inspect Release for bundled models, permission text, deployment target, absence of DEBUG seed/import/diagnostic/private-PC behavior and absence of embedded credentials. Do not bump versions for routine local review.
- Test iOS 17 (declared minimum) and current runtimes, compact and large phones, both appearances, large text and Reduce Motion. Record unavailable runtimes as unverified; do not raise the target to bypass a failure.
- Use a connected physical phone for touch feel, real camera, inference quality/performance and VoiceOver. A browser mirror is only a viewing aid. Record physical unavailability separately.
- Verify existing-data upgrade/recovery before distribution. Complete production authentication, StoreKit/backend/privacy and signing/TestFlight checks separately, with explicit release authorization.
