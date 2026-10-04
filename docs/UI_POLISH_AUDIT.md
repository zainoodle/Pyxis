# Pyxis interface polish audit — 2026-10-02

Local implementation on `codex/editorial-archive` in the primary checkout. The existing rack patch was incorporated after backing up every modified/untracked file to `/tmp/pyxis-polish-backup` with a SHA-256 manifest. The rack experiment remains recoverable in its original worktree. No commit, push, or PR was made.

## Findings and changes

| Before | After | Why |
| --- | --- | --- |
| Thin hook appeared attached directly to the collar | Shaded metal hook, solid shoulder support, and separate trouser clips | Makes the support legible while keeping it behind the accepted photo |
| Rail was a single flat stroke | Restrained cylindrical shading and contact shadow | Adds depth without regenerating fabric or adding texture overlays |
| Very damped slider movement | Bounded, interruptible pendulum response with a small counter-swing | Connects movement to swipe acceleration and settles at rest |
| Rapid swipe reversals could activate a moving photo | Explicit tap recognition and a guard within 180 ms of a drag | Prevents unintended navigation while preserving deliberate taps and the details link |
| Dark trousers disappeared against the stage | Brighter charcoal photo surface, unchanged page background | Separates dark garments from the surface |
| Grid thumbnails and flat lays used inconsistent surfaces | Shared photographic surface for grid, saved fits, suggestions, builder, and details | Keeps scale, depth, corners, and borders coherent across the flow |
| Theme changes altered fonts, tile heights, and appearance controls | Matching typography, dimensions, and appearance controls in both themes | Appearance now changes colors without rearranging the interface |
| Detail layout compressed into two columns on an iPhone | Vertical layout on compact screens and accessibility sizes; two columns on regular-width screens | Gives the garment and editable controls usable space |
| Single-piece fit occupied a corner of a multi-piece composition | Centered, balanced single-piece preview | Avoids a visibly unfinished composition |
| Upload processing looped a shine, sparkle, and floating shadow | Clear native progress indicator | Communicates work without decorative activity |
| Disabled outlined buttons looked enabled | Visible disabled treatment and restrained press feedback | Makes state readable across every page using the shared control |
| Duplicate first-fit message appeared under a saved draft | Show the first-fit invitation only without a draft | Reduces competing instructions |
| All-caps errors and settings empty states | Sentence-case errors and useful empty-state copy | Improves readability without removing garment codes |
| Measurement panels used unrelated square corners | Consistent 8 pt form surfaces | Aligns supporting pages with the rest of the app |
| Profile label broke awkwardly at largest text size | Native control typography and removal of decorative row icons at accessibility sizes | Reserves space for readable setting names |

## Verification

- **Passed:** iOS Simulator Debug build on Xcode 27, iPhone 18 Pro / iOS 27. No Swift compiler warnings in the final build. Xcode still emits its informational App Intents metadata warning because the app has no App Intents dependency.
- **Passed:** Swift package suite: 181 reported, 180 executed successfully, 1 optional integration test skipped, 0 failures.
- **Passed separately:** optional SAM model inference test on macOS using the opaque overshirt fixture and compiled model packages.
- **Reviewed in the simulator:** Closet gallery and grid; garment details; Fits before and after saving a fixture fit; fit details and builder; Profile; Measurements; empty Closets; upload entry, transparent-image editor, and failed extraction; empty search and clearing search.
- **Reviewed:** light/dark appearance, largest Dynamic Type closet scrolling and reachable controls, vertically arranged appearance controls, large-text details and measurements, and a Reduce Motion swipe recording. Simulator settings were restored after the checks.
- **Passed:** transparent garment import, light preview, local crease softening and restoring natural texture. The original garment pixels remain independent from rack transforms.
- **Passed:** recorded ordinary swipes and rapid direction reversals remained in the gallery after replacing the photo link with explicit tap recognition; deliberate photo taps still opened details.
- **Passed:** `git diff --check`. Pre-existing changes in AGENTS.md, CONTRIBUTING.md, the Xcode project file, and RELEASE_PROCESS.md were preserved byte-for-byte against the backup manifest.

## Open limits

- **Failed in iOS Simulator:** extraction of the opaque overshirt fixture. The UI correctly offers the retained original and retry. Simulator logs report Vision could not create an inference context. The equivalent macOS model test passes, but this does not prove the root cause or physical-device success. No mask-quality thresholds were weakened to hide the failure.
- Physical-device touch feel, performance, camera capture, and PhotosPicker end-to-end import were not verified in this pass. The fixture launcher exercises the editor and services directly.
- Garment attachment still uses category and visible-image bounds. Arbitrary asymmetric poses, unusual necklines, and draped garments need representative photo validation or garment-specific attachment metadata.
- The layout checks cover one simulator size plus accessibility text reflow, not the entire iOS 17–27/device matrix. AI network flows and purchase/release flows were not exercised.
- One suggested fit was saved only in the simulator fixture wardrobe to inspect populated Fits and fit-detail states. No physical-device wardrobe data was changed.
