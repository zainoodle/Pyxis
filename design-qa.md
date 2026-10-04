# Closet contextual actions and typography review — 2026-10-02

## Findings

No actionable P0/P1/P2 findings remain in this focused change. Isaiah requested removal of the rail arrows and persistent details/build actions, with those options revealed by tapping a garment. He also requested stronger weight and spacing for the garment name and browse/view controls. This report supersedes the previous footer and tap behavior; the previous report is preserved as `previous-design-qa.md` in the evidence directory.

- Resolved [P2] **Broken view label at maximum text size.** The initial implementation wrapped “Gallery” before its final letter. Gallery/Grid now stack at accessibility sizes and each label keeps its full width. Matching light-appearance before/after evidence shows intact labels.
- Resolved [P2] **Selected garment drift after text-size changes.** The initial render retained TS-001 in the caption while the rail centered the trousers. Restoring the scroll position after the new layout keeps the selected garment centered. TS-001 measured x = 200.993 pt at standard text, maximum text, after detail navigation, after vertical caption scrolling, and after restoring standard text. The viewport center is 201 pt. The compact simulator measured 195.033 pt against a 195 pt center.
- Implemented user feedback: **Cleaner browsing.** The caption contains name, code and count. The redundant visible arrows and persistent action row are removed. A garment tap selects that piece and reveals native View details / Build a fit options. Accessible next/previous and adjustable-position actions remain in code.
- Implemented user feedback: **Clearer typographic hierarchy.** Garment names use a scalable 22 pt semibold role with tighter tracking and a 6 pt name/code gap. Browse and view labels use a scalable 15 pt utility role, uppercase and 1.4 pt tracking. Active Gallery/Grid adds semibold weight and a 2 pt underline; inactive mode stays lighter. Touch targets remain at least 44 pt.

## Source and implementation evidence

Evidence directory: `/Users/isaiahjohnson/.codex/visualizations/2026/10/01/01a0f678-2c10-7fb2-867a-db724f995c3d/runway-contextual-actions/`

- Source visual context: `before-native-dark.png`, the previously reviewed native option 2 adaptation with TS-001 selected. The selected generated direction remains at `../runway-refinement/selected-target.png`.
- Latest source instructions: Isaiah’s arrows, contextual-action and typography requests, with the attached crops preserved as `user-footer.png`, `user-garment-title.png` and `user-browse-labels.png`. These requests explicitly supersede the old footer controls and light label weights.
- Final rendered implementation: `native-dark.png`, `native-light.png`, `native-options-dark.png` and `native-options-light.png`.
- Combined full comparison: `comparison-full.png` shows the prior native screen, final browse screen, and tap options together. `comparison-focus.png` compares the controls and garment caption at equal scale.
- Correction comparison: `comparison-accessibility-repair.png` shows the initial and repaired maximum-text layouts in light appearance. The first captures are retained as `native-largest-top-before-repair.png` and `native-largest-caption-before-repair.png`.
- Resilience evidence: `native-largest-top.png`, `native-largest-top-light.png`, `native-largest-caption.png`, `native-largest-options.png`, `native-long-name.png`, `native-neighbor-options.png`, `native-builder-handoff.png`, `native-compact-26.png`, `native-compact-largest-26.png` and `native-compact-options-26.png`, with AX snapshots beside them.
- Assertions: `interaction-checks.json`, `layout-repair-checks.json` and `compact-layout-checks.json`. The native interaction scripts, final build logs and `build-identity.json` are retained in the same directory.
- Live implementation: `http://localhost:3200/`, streaming the native simulator. This is the SwiftUI app, not a browser recreation.

## Viewport, density and state

The main native images are 1206 × 2622 px, representing 402 × 874 pt at 3× on iPhone 18 Pro / iOS 27.0. The compact images are 1170 × 2532 px, representing 390 × 844 pt at 3× on iPhone 17e / iOS 26.5. CSS viewport and browser deviceScaleFactor do not apply to the native screenshots.

The full comparison uses dark appearance, Large text, Gallery, All pieces and TS-001 at 04 / 05. Each full native capture is uniformly resized to 402 px wide, including the OS status bar and home indicator. The change in clock time is incidental. The options column deliberately shows the contextual menu. Focused crops use the same scale and preserve the shorter final caption rather than stretching it to the previous footer height.

The correction comparison uses light appearance, maximum accessibility text, Gallery, All pieces, and a TS-001 selection on the same 402 pt simulator. Its earlier rail/caption mismatch is the defect being compared. Stacking the view choices intentionally increases the control region’s height; vertical scrolling reaches the full caption above the persistent tabs.

The compact simulator has separate existing QA/demo inventory and is used for layout and interaction checks, not a literal photo-fidelity comparison. Main simulator wardrobe photographs, names, codes, ordering and stored data are unchanged. The native fallback name is “Tshirt”; the user’s “White tee” crop is a typographic reference, not a request to rename inventory.

## Required fidelity surfaces

| Surface | Assessment |
| --- | --- |
| Fonts and typography | Passed. The approved Antonio Light masthead and existing code role remain. Stronger scalable garment names and tracked utility labels follow the latest user request. Active/inactive view weights are visibly distinct. Long names wrap fully; accessibility labels remain readable and Gallery stays intact at maximum size. No new font dependency was introduced. |
| Spacing and layout rhythm | Passed. The single caption row removes two arrow circles and the action row, returning room to the garment stage. Name/code grouping is tighter, view choices have 24 pt spacing, and the selected underline is clearer. Both widths retain 44 pt targets. Maximum text stacks the controls and caption; vertical scrolling keeps the code/count above the tabs. Selection stays centered across layout changes. |
| Colors and tokens | Passed. Existing charcoal/ivory and warm-paper palettes are reused. Browse text now uses the primary text token to strengthen hierarchy. Native contextual menus adapt to both themes. No surface or color-token redesign was required for this change. Increase Contrast and Reduce Transparency were not separately rerun in this focused pass. |
| Image quality and asset fidelity | Passed for the main real-photo inventory. No garment pixels were regenerated or processed. Aspect-fit framing, rail/hanger components and rigid motion remain. Larger available stage space changes display scale without changing texture or proportions. Flat-fallback garments and the clip-hung trousers remain visible. Compact demo assets are only layout fixtures. |
| Copy and content | Passed. Actual garment names/codes and counts remain. Menu titles identify the selected code and name. View details and Build a fit use existing wording; the build action is shown only for supported outfit slots. The gallery’s accessible hint now describes its options. No design-process text was introduced into the app. |

## Comparison history

1. Previous approved native option 2 adaptation had light utility/name weights and persistent footer controls. The latest user requests authorize the deliberate differences shown in the full and focused comparisons.
2. First implementation removed those controls, added the garment menu and revised the type. Native detail/build handoffs, normal/rapid swipes, Grid/Gallery selection, light/dark and Reduce Motion checks passed.
3. Visual inspection of maximum-text screenshots found the split Gallery label and selected-garment drift. Both were treated as P2 findings rather than accepted as passing reachability checks.
4. The picker now stacks with intact labels at accessibility sizes. Deferred scroll restoration keeps the selected item centered after layout changes. Post-fix captures and measured AX frames verify both repairs on the two screen sizes, including matching light-appearance comparison evidence.

## Verification

- Passed: persistent arrows/details/build controls absent during browsing; a garment tap opens its options.
- Passed: TS-001 View details opens the matching item; Build a fit passes TS-001 to the builder with the existing draft retained.
- Passed: tapping a visible neighboring PT-001 centers it and opens its own menu and matching detail.
- Passed: normal 0.6 s swipes and rapid 0.2 s flicks remain in the gallery without accidentally showing a menu; Grid → Gallery preserves TS-001.
- Passed: long-name wrapping, light/dark rendering and both screen widths.
- Passed: maximum-text Gallery/Grid labels remain intact; code/count scroll above tabs; both options are reachable and matching details open. Standard → maximum → standard selection-centering checks passed on both simulators, plus detail-return and vertical-scroll checks on the main simulator.
- Passed: Reduce Motion swipes and contextual detail navigation in the initial implementation. Its preference was restored afterward. The layout repair changes scroll restoration, not motion transforms.
- Passed: final Debug simulator and generic unsigned Release device builds. No Swift compiler warnings; the existing informational App Intents metadata extraction warning remains. Version/build remain 1.0.0 (1).
- Passed: static deployment preflight and `git diff --check` after the final source/documentation changes. Source hashes/build identity and prior-work preservation results are saved with the evidence.
- Historical only: the previous refinement’s eight rack tests and broader app tests were not rerun for this focused interaction/type follow-up. Current relevant verification is the native interaction and layout assertions above.
- Not run: physical-device feel, complete VoiceOver traversal, signed distribution and fresh performance profiling. These are not claimed as passing.

## Implementation checklist

- [x] Remove redundant rail arrows and persistent footer actions.
- [x] Reveal matching detail/build choices through a garment tap.
- [x] Strengthen name and utility-control hierarchy in the rendered app.
- [x] Compare full views and focused regions together.
- [x] Fix, recapture and verify the maximum-text defects.
- [x] Preserve garment content, motion conventions and prior unrelated work.
- [x] Keep the finished native screen available in the simulator mirror.

final result: passed
