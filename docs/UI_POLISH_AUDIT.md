# Pyxis integrated quality audit — October 2, 2026

## Candidate and scope

The integrated source is the primary checkout `/Users/isaiahjohnson/Documents/ChatGPT/Pyxis`, branch `codex/editorial-archive`, based on `be6cd23` plus the preserved working changes. Local version remains **1.0.0 (1)** and minimum deployment target remains **iOS 17**. This is a review candidate, not a distribution-ready release.

Before editing, 39 modified/untracked files were copied to `/tmp/pyxis-release-review-backup` with a SHA-256 manifest. Isolated rack-quality and flow-quality worktrees received the same dirty baseline; only their deltas were integrated. The primary owner resolved shared-file changes and built the combined result. No reset, commit, PR, push, upload, release, migration, or physical wardrobe change was performed. Unrelated AGENTS.md, CONTRIBUTING.md, project.pbxproj, and RELEASE_PROCESS.md remain byte-identical to the backup.

This audit supersedes the earlier polish report, especially its failed opaque extraction, bounds-only attachment, 180 ms tap guard, and older test counts. Existing accepted typography, garment codes, cutouts, and original photos are retained.

## Findings, corrections, and evidence

| Screen / state | Observed problem → user impact | Implemented correction | Verification |
| --- | --- | --- | --- |
| Closet / top and trousers | Bounds/category alone placed support without evidence of a neckline or waistband → floating or implausible hangers | Cached conservative alpha-contour support hints, shallow shoulders behind fabric, trouser clips, aligned rail/hook, restrained material shading. Ambiguous, translucent, strappy, asymmetric, or no-neckline silhouettes fall back to an unrotated flat presentation. No invented anatomical guarantee or pixel warping. | Native tee and trouser light/dark screenshots; attachment and geometry regressions including a very wide, short image. Dress/lace/complex real-photo coverage remains open. |
| Closet / drag, reversal, settling | A 180 ms timing workaround could confuse tapping and swiping → unwanted navigation | Native scroll remains authoritative; tap recognizer waits for pan failure, rejects dragging/deceleration and window-coordinate travel. Bounded continuous suspension motion; no idle activity. Reduce Motion removes decorative sway. | Recorded normal drags, four rapid flicks, deliberate centered-item tap with matching code, and reduced-motion swipes. All assertions passed. |
| Closet / framing | Alpha crop used the wrong Y coordinate convention → asymmetrically placed garments could be cropped away | Correct bitmap-to-CoreImage coordinates; retain uniform scaling and aspect ratio | Asymmetric-margin regression reproduces old empty crop and passes with correction. Native gallery/grid and filtered selection checked. |
| Closet / filter and long content | Selection, captions and layout must remain coherent after narrowing results | Retained native scroll position and stable item selection; shared stage and caption layout | Tops filter, empty Accessories filter, clear all, gallery/grid switch, long garment name, deliberate details navigation checked. Largest text requires vertical scrolling but keeps code/details/Build reachable. |
| Add / opaque import | Decoder returned zero mask output on iOS Simulator → local cutout failed despite macOS success | Decoder public masks/scores converted to Float32 with byte-identical Float16 learned weights; reproducible conversion script and manifest. Simulator uses CPU compute; hardware policy unchanged. No-hint prompts distributed through the interior. Quality threshold and mask review remain unchanged. | Opaque fixture accepted on iOS 27; actual native PhotosPicker selection, extraction, save, relaunch and original recovery passed on iOS 26.5. Hint and no-hint model integration passed separately. Physical hardware and representative photo accuracy remain open. |
| Add / corrupt image | Undecodable bytes could become an apparent original-only item → broken saved entry | Validate decoding before storing; no savable result or image files for invalid input. Error returns to photo chooser and hides the irrelevant editor/save action. | Regression verifies input untouched and no stored originals/cutouts/thumbnails. Final native error screen and choosing a replacement photo checked. |
| Add / loading, cancellation | Picker/drop callbacks could outlive the dismissed flow → abandoned processing and draft files | Progress feedback, cancellation checks after transfer, lifetime/generation guards for providers, cleanup restricted to owned temporary files | Real picker success and cancel checked; delayed iCloud and drag-provider race injection remain unverified. |
| Add / color editing | Late analysis overwrote a manually selected color → user choice lost | Track explicit color edits through analysis/retry and reset on a new photo | Regression passed with analysis, retry and subsequent selection. |
| Image editor / rotation | Failure could leave original rotated but cutout unchanged; EXIF and file format could diverge | Encode the entire image set first, commit with rollback, respect EXIF, preserve JPEG encoding for JPEG paths | Corrupt/missing cutout leaves original/thumbnail unchanged; EXIF 6, 8 and mirrored 2 corner/dimension regressions passed. Actual disk-full injection remains open. |
| Image editor / crease softening | Heavy-handed processing would erase fabric identity | Retained local conservative detail-protected smoothing, exact draft natural-texture restoration and original preservation; light/dark preview surfaces do not change stored alpha | Existing smoothing/alpha/detail/restore tests passed. This reduces small creases; it does not reconstruct heavy folds. AI de-wrinkle remains separate and explicitly opt-in. |
| Saved piece / Improve cutout | Same-path cache could display previous pixels in other pages → successful operation looked ineffective | Storage change notifications refresh mounted views and global caches; generation epoch rejects in-flight stale decodes | Source review and storage regression checks passed. A visibly different successful replacement across every page was not newly exercised end to end. |
| Saved piece / retry then reopen/delete | New detail instance lost in-flight state → deletion could race a retained task | Shared per-item processing lease gates duplicate retry and destructive deletion across detail instances | Suspended service regression passed; handlers reviewed. |
| Saved piece / Back after editing | Native Back bypassed explicit persistence, updated date and memory indexing → inconsistent metadata | Save-aware Back/Close with error handling before dismissal | Edited a long name, Back, terminated/relaunched, and checked persisted name/date. Storage-save failure UI not injected. |
| All pages / light and dark | Inconsistent photo surfaces and theme-dependent geometry → disconnected visual hierarchy | Shared photographic surface, restrained background depth, same typography/control geometry across appearances, readable disabled states | Gallery/grid/detail/Fits/builder/Profile/Measurements/Closets/import states reviewed. Screens listed below. |
| Detail / compact and large text | Two columns squeezed image and editing controls | Vertical compact/accessibility layout; regular width retains split layout | Native detail and long-content review. |
| Fits / suggestions / builder | Single piece stranded in a multi-piece composition; duplicate draft invitation; repeated accessibility labels | Center single-piece previews, suppress redundant first-fit message when a draft exists, group composition accessibility once | Save/duplicate/delete, suggestions save, builder piece change, draft resume after relaunch, saved fit and largest-text layout passed. Full VoiceOver traversal remains open. |
| Profile / closets | Private Select/Selected state had no browsing effect → misleading control | Removed dead selection state; actual Closet filter remains browsing control | Create, membership save/reload, duplicate-name feedback and group deletion checked. |
| Closets / long names and delete | Compressed accessibility row, keyboard obstruction and immediate removal | Vertical accessibility row, multiline name, keyboard dismissal after success, rollback on failed save, explicit confirmation preserving pieces | AX5 long name/count/Delete reachable. Short confirmation title complete; native message scroll reaches full explanation. Confirmed delete preserves garments. |
| Measurements / invalid value | Invalid nonempty input became nil → could silently clear stored measurement | Validate positive finite values before mutation; allow blank optional fields, whitespace and decimal comma | Chest saved/reloaded; waist 0 rejected while prior chest retained; two new regressions. Retailer match and no-comparable state checked. |
| AI unavailable | Unconfigured network features must not imply working generation | Retained explicit unavailable behavior and opt-in consent; production endpoint/token are blank | Builder options did not expose a fake working Try on; no photo upload occurred. Unit/backend tests pass, live generation/purchases remain release gates. |

## Native verification matrix

| Device/runtime | Evidence and result |
| --- | --- |
| iPhone 18 Pro, iOS 27 Simulator | Integrated Debug launch; opaque extraction, gallery/grid/filter/empty result, detail save/relaunch, corrupt import/replacement recovery; light/dark and long name. |
| iPhone 18 Pro Max, iOS 27 Simulator | Integrated rack build; normal/rapid swipe and tap assertions; tee/trouser support in both themes; largest text; Reduce Motion recordings. |
| iPhone 17e, iOS 26.5 Simulator | Actual PhotosPicker transparent and opaque imports; save/relaunch/original recovery; cancel; Fits/builder/suggestions; Profile; Measurements; closet management/AX5 confirmation. Simulator camera opens and cancels, but shutter produced no usable captured frame. |
| Paired physical iPhone | **Blocked:** devicectl cannot establish a connection. No claim of hardware camera, extraction, touch, haptic, thermal or frame-time acceptance. |
| iOS 17 deployment target | **Compile/artifact passed:** project, app metadata, Mach-O and model specification retain iOS 17. **Runtime unverified:** installed runtimes are 26.5 and 27 only. |

The final AddItemFlow-only error recovery refinement was rebuilt and its affected corrupt-to-valid import path rechecked. Earlier integrated rack/flow recordings remain applicable to unchanged code; their per-lane reports identify the snapshot and later affected rechecks. Screenshots and AX assertions establish the listed observations, not complete accessibility or performance acceptance.

## Automated and release checks

- **Passed:** final Xcode 27 Debug simulator build and generic unsigned Release iPhoneOS build. No Swift compiler warnings; informational App Intents metadata warning remains.
- **Passed:** Swift package suite: **193 reported, 192 passed, 1 optional fixture integration skipped, 0 failures**. The optional SAM test passed separately with both Vision-hint and no-hint paths and compiled bundled models.
- **Passed:** 25 workflow tests; 26 backend tests; backend syntax check; static deployment preflight; model package hashes; version consistency; 23 release-note fragments; `git diff --check`.
- **Passed:** Release resource/metadata inspection: three compiled models, fonts, icons, license and matching privacy manifest; Float32 decoder outputs/specification 8; min iOS 17. Debug fixture/diagnostic/private-PC/test-token markers absent; no ATS exception; AI configuration blank. The artifact is **unsigned**, not a distribution export.
- **Preserved:** unrelated dirty files verified against backup; no minimum OS or version change and no automatic reprocessing/migration of existing wardrobe images.

## Evidence and runnable build

Stable review evidence lives at:
`/Users/isaiahjohnson/.codex/visualizations/2026/10/01/01a0f678-2c10-7fb2-867a-db724f995c3d/release-review/`

`README.md` indexes screenshots, videos, checks, final artifact metadata and the preserved Debug app. `rack/` contains normal/rapid/deliberate-tap and reduced-motion recordings plus light/dark evidence; `flows/` contains actual picker/import/persistence and page checks. `before/` contains dated baseline screenshots. Evidence filenames are not claims of broader behavior than the accompanying reports.

One runnable integrated candidate is installed on the main iPhone 18 Pro simulator. Rebuild from the primary checkout using Xcode scheme `Pyxis`; canonical build output is `/tmp/pyxis-polish-derived/Build/Products/Debug-iphonesimulator/Pyxis.app`. Build identity is recorded with the evidence. The generic unsigned Release output is `/tmp/pyxis-release-review-derived/Build/Products/Release-iphoneos/Pyxis.app`.

## Remaining gates

1. Connect/unlock the physical phone and verify camera capture, actual model inference, touch/haptics, memory/thermal behavior and scrolling performance.
2. Exercise iOS 17 runtime, full VoiceOver traversal, delayed iCloud/drop cancellation, save/disk failure injection, and representative dresses, unusual necklines, asymmetric, translucent/lace and difficult-background photographs. Conservative flat fallback prevents pretending support is known; it does not replace photo QA.
3. Validate configured live AI failure/success, real StoreKit Sandbox purchase/entitlement/allowance flows and production deployment. The existing shared cleanup token architecture remains unsuitable for broad public AI release; see SECURITY_AUDIT_2026-09-18.md. No new auth infrastructure or uploads were introduced.
4. Complete distribution signing/export, App Store privacy/pricing metadata and release approval. This local candidate is not a TestFlight/App Store submission.

## Selected runway refinement — 2026-10-02

Isaiah selected runway option 2 and requested a smaller build action. The latest native Closet uses a continuous rail with overlapping garments, a bundled Antonio Light masthead, soft rail lighting, left-aligned name/code and compact navigation. “Build a fit” is a content-sized outline beside “View details,” measuring 123.33 × 44 pt at standard text size. The revised mock was shown before implementation.

The focused follow-up review is in [design-qa.md](../design-qa.md). Source/first/final combined comparisons, light/dark and largest-text captures, native motion recordings, interaction assertions, build logs and build identity are saved at `/Users/isaiahjohnson/.codex/visualizations/2026/10/01/01a0f678-2c10-7fb2-867a-db724f995c3d/runway-refinement/`. Prior audit evidence above is retained as a historical snapshot.

Passed in this follow-up: normal/rapid swipes, matching center-tap detail, neighboring-tap centering, first/last and single-piece boundaries, empty-filter recovery, long-name layout, Grid/Gallery selection, selected-piece builder handoff with draft retention, light/dark, compact iOS 26.5, Reduce Motion and largest-text action reachability. Eight existing rack tests, static preflight, Debug simulator and generic unsigned Release device builds passed. Both build artifacts include and register the matching font and license. No Swift compiler warnings; the informational App Intents metadata warning remains. Physical interaction, complete VoiceOver and fresh performance profiling remain unrun in this focused pass.

The current installed native candidate supersedes the earlier build path above for reviewing this selected direction: `/tmp/pyxis-runway-derived/Build/Products/Debug-iphonesimulator/Pyxis.app`. The corresponding generic unsigned device build is `/tmp/pyxis-runway-release-derived/Build/Products/Release-iphoneos/Pyxis.app`. The live simulator mirror remains at `http://localhost:3200/`. Version/build are unchanged at 1.0.0 (1). This refinement changes presentation and bundled typography; accepted garment pixels, model/service behavior and stored data are preserved.


## Contextual actions and typography — 2026-10-02

Isaiah’s later feedback supersedes the compact footer controls described above. The latest Closet caption contains only the garment name, identification code and count. Visible previous/next arrows and the persistent View details / Build a fit row are removed. Tapping a garment selects it and reveals those choices in the native contextual menu; next/previous accessibility actions and the adjustable count remain.

Garment names now use a scalable semibold role with tighter tracking and a smaller name/code gap. Browse and Gallery/Grid labels use smaller tracked uppercase text, stronger active weight and a clearer underline. At accessibility sizes the view choices stack without breaking words. Screenshot review caught an initial maximum-text word wrap and rail/caption selection mismatch; both were corrected and recaptured. The selected garment remains centered at standard and maximum text on 402 pt and 390 pt simulators.

Passed in this follow-up: selected and neighboring garment menus, matching details, TS-001 builder handoff with draft retention, normal/rapid swipes without accidental menus, Grid/Gallery selection, long names, light/dark, compact iOS 26.5, maximum-text reachability and selection centering, and Reduce Motion navigation. Final Debug simulator and generic unsigned Release device builds, static preflight and diff whitespace passed. Physical-device feel and full VoiceOver traversal remain unrun. Earlier unit-test counts are historical and were not rerun for this focused change.

Current review and combined before/after evidence are in [design-qa.md](../design-qa.md) and `/Users/isaiahjohnson/.codex/visualizations/2026/10/01/01a0f678-2c10-7fb2-867a-db724f995c3d/runway-contextual-actions/`. The live mirror remains `http://localhost:3200/`; current build paths remain those above, with fresh identity/hashes saved in the new evidence directory. The previous root QA report is archived beside the captures. Version/build, stored inventory and garment pixels are unchanged.
