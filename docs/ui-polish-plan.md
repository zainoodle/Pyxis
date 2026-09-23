# Pyxis interface refinement

## Baseline and scope

Base: `codex/profile-privacy-section` (PR #6), which depends on `codex/app-versioning` (PR #4). The Closet diff stays separate from Profile copy removal, while the combined branch preview includes both changes. Pyxis is a SwiftUI iPhone app targeting iOS 17. The root `TabView` has Closet, Build, Fits, and Profile tabs; detail views and editors use navigation stacks and sheets. The project declares iPhone device family only. No orientation restriction was found in the project settings.

The unmodified app built and launched on an iPhone 17 Pro simulator running iOS 26.5. [Baseline closet screenshot](ui-evidence/baseline-closet.png) shows a populated demo closet. The other tabs were rendered by a temporary debug launch argument, which was removed after capture. The available UI control interfaces cannot operate controls, so interaction findings below are source confirmed unless marked visual. Only demo data appears in committed screenshots.

| Screen | User goal | Main action | Source files | States inspected | Missing coverage |
| --- | --- | --- | --- | --- | --- |
| Closet | Find and organize garments | New item; search and filter | `src/views/ClosetGrid/ClosetGridView.swift`, `src/views/Navigation/TopNavigationView.swift`, `src/views/Search/SearchAndFilterView.swift` | Populated demo, rendered; empty and filtered empty, source | Empty and filtered empty render; controls and sheet interaction |
| Item detail | Inspect or edit one garment | Edit, favorite, build | `src/views/ItemDetail/ItemDetailView.swift` | Source only | Render and actions |
| Add item | Import and describe a garment | Save item | `src/views/AddItem/AddItemFlow.swift` and child views | Source only | Camera, import, errors, keyboard |
| Build | Assemble an outfit | Save fit | `src/views/OutfitBuilder/OutfitBuilderView.swift` and carousel views | Populated demo, [rendered](ui-evidence/baseline-build.png) | Selection, disabled and saved interactions |
| Fits | Review saved outfits | Open fit; build when empty | `src/views/OutfitBuilder/SavedFitsGalleryView.swift` | Populated demo, [rendered](ui-evidence/baseline-fits.png); empty, source | Empty render and navigation |
| Profile | Manage closets and sizing | Open a setting | `src/views/Profile/ProfileView.swift` | [Baseline before PR #6](ui-evidence/baseline-profile.png) | Navigation and detail views |

## Style Preservation Contract

The visible closet is **restrained** (white canvas, fine rules), **catalog-like** (large isolated garment cutouts and item codes), **technical** (uppercase monospaced type and compact labels), and **airy** (generous space around imagery). The code confirms a white background and surface, near-black text, warm gray supporting text and rules, and a warm off-white field. The app uses system monospaced text styles. Spacing tokens are 4, 8, 16, 28, and 44 points. Corners on fields and buttons use an 8-point radius; catalog tiles use a bottom rule. SF Symbols appear beside terse text labels. Garment imagery is centered with ample white space. The root tabs and sheet-based filters provide familiar navigation. Existing motion is limited to short selection and state transitions, though the builder uses a more expressive carousel.

The Closet grid and its code labels are the strongest visible reference. Build's carousel is an intentional exception to the otherwise restrained motion. The typography and whitespace are intentional; cramped controls and truncated names are inconsistencies.

| Attribute | Current evidence | Preserve | Permitted refinement |
| --- | --- | --- | --- |
| Palette | `PyxisColors` and closet screenshot | White, ink, warm gray | Improve contrast where measured |
| Type | `PyxisTypography` and uppercase codes | System monospaced character | Reflow and allow wrapping |
| Density | Spacious product grid, compact controls | Garment-first hierarchy | Give primary search more room |
| Shapes | Fine rules; 8-point field corners | Flat catalog surfaces | Increase hit regions without enlarging decoration |
| Images | Isolated cutouts in grid | Uncropped garment emphasis | Adapt tile height only if text needs it |
| Navigation | Four tabs, detail pushes, filter sheet | Existing destinations and terms | Clarify actions within each screen |
| Motion | Brief state animations; builder carousel | Purposeful feedback | Respect Reduce Motion in any changed custom motion |

The refined app should still feel **like a quiet clothing catalog**, while becoming clearer through **better control grouping and text adaptation**.

## Prioritized backlog

| ID | Screen/component | Observed problem and impact | Exact change | Files | Acceptance test | Priority/status |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | Closet controls | Baseline screenshot shows search competing with sort and favorites in one compressed row; source fixes search to 180 points outside accessibility sizes | Put search on its own full-width row; place sort and favorites below and stack those controls at accessibility sizes | `SearchAndFilterView.swift` | Search remains readable and usable on supported iPhones and enlarged text | P1 / implemented, rendered |
| C2 | Closet navigation and filter sheet | Source gives `NEW` and `DONE` a 44-point height but no minimum width | Give text actions a 44-point minimum hit width; let title/actions reflow if needed | `PyxisComponents.swift`, `TopNavigationView.swift` | Each action exposes an accessible button and a 44-point hit region | P1 / implemented, interaction pending |
| C3 | Active filters | Source fixes chips at 36 points high and truncates favorites text with scale down | Raise chip hit height to 44 points; allow favorites label to wrap without shrinking | `SearchAndFilterView.swift` | Remove and favorites controls remain readable and operable at large type | P1 / implemented, chip interaction pending |
| C4 | Closet tiles | Source truncates garment display names at one line; long names lose distinguishing words | Allow two lines while preserving cutout and code priority | `ClosetGridItemView.swift` | Long names display up to two lines without overlapping next tile | P2 / implemented, long-name fixture pending |
| B1 | Builder carousel | Source uses 3D rotation and automatic movement without a Reduce Motion branch | Review rendered motion and add a reduced-motion alternative | `OutfitCarouselRow.swift` | Selection remains understandable with Reduce Motion enabled | P1 / deferred pending rendered interaction |
| B2 | Builder readiness | [Rendered Build](ui-evidence/baseline-build.png) clips the rightmost slot summary with no scroll indicator | Wrap slot counts into visible rows while keeping the compact mono labels | `OutfitBuilderView.swift` | Every slot count is visible at default and large type | P1 / deferred; overlaps PR #7 |
| A1 | Add item | Several fixed heights may collide with large text and keyboard | Inspect rendered flow, then adjust actual clipping points | Add item views | Save and errors remain reachable with keyboard and large text | P1 / deferred pending rendered flow |
| P1 | Profile | [Rendered Profile](ui-evidence/baseline-profile.png) uses a large sans title unlike the mono headings in the other tabs | Align the title with the established mono hierarchy while preserving navigation | `ProfileView.swift` | Profile and pushed settings retain clear back navigation | P2 / deferred; overlaps PR #6 |

First batch: C1–C4. These are confined to the rendered Closet screen and shared text actions. Interactive checks remain pending because the available simulator control interfaces cannot operate the app.

## Verification checkpoint

| Check | Device/settings | Expected | Actual | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| Baseline build and launch | iPhone 17 Pro, iOS 26.5, default type | App runs | Build succeeded; PID returned and remained alive | Passed | `./scripts/build_and_run.sh --verify`, local build log |
| Baseline Closet render | Same | Populated catalog visible | Four demo garments and controls visible | Passed | `ui-evidence/baseline-closet.png` |
| Other top-level renders | iPhone 17 Pro, default type | Build, Fits and Profile display | All three rendered with demo data using a temporary launch argument, then removed | Passed, visual only | `ui-evidence/baseline-build.png`, `baseline-fits.png`, `baseline-profile.png` |
| Refined Closet render | iPhone 17 Pro, default and largest accessibility type | Header and controls reflow without clipping | Search takes full row; controls stack at largest type; garment list remains scrollable | Passed, visual only | `ui-evidence/refined-closet.png`, `refined-closet-accessibility.png` |
| Narrower iPhone render | iPhone 17e, default type | Controls remain readable | Header, search, sort, favorites, and grid rendered without overlap | Passed, visual only | Local screenshot excluded because this simulator contains pre-existing non-demo closet data |
| App build and core tests | iPhone 17 Pro build; Swift package tests | Build and tests pass | Final build succeeded after temporary launch code was removed; 110 tests passed | Passed | `./scripts/build_and_run.sh --verify`, `./scripts/test.sh` |
| PR workflow tests | Local Python suite | Policy tests pass | 25 tests passed | Passed | `python3 -m unittest discover -s tests/workflow -v` |
| Palette contrast | Source token pairs | Normal text meets 4.5:1 | Ink/white 18.54:1; secondary/white 7.21:1; inactive/white 5.30:1; secondary/field 6.67:1 | Passed for these pairs | Calculated from `PyxisColors` sRGB values |
| Light and dark system setting | iPhone 17 Pro | App preserves intended appearance | Both display the same light catalog; `PyxisApp` explicitly sets `.preferredColorScheme(.light)` | Passed, visual only | Dark appearance screenshot inspected locally |
| Filter sheet, chip removal, keyboard, VoiceOver and gestures | iPhone 17 Pro | Controls work and stay reachable | Runtime UI snapshot reports no interaction targets despite a visible app frame | Blocked | XcodeBuildMCP build and capture work through an explicit Xcode path; interaction targets remain unavailable |

Completed: C1–C4 implementation and default/large-type visual checks. PR #6 removes the verbose Profile copy shown in the baseline screenshot. After PRs #4 and #6 merge, rebase this branch onto `main`, rerun checks and interactive QA. Remaining priorities: B1, B2, A1, P1, and cross-screen interaction/accessibility review. B2 overlaps open PR #7 and P1 overlaps open PR #6, so those should be addressed after their respective branches settle.
