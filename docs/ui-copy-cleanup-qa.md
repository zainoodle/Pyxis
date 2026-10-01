# Pyxis UI copy cleanup

Implemented the recommendations in `ui-copy-audit.md` on the existing `codex/editorial-archive` branch. The approved Closet gallery and Fit composition remain the basis of the app. This is local work; no PR, release, version bump, or stored-data migration was made.

## Result

| Screen | Change |
| --- | --- |
| Add piece | Choose photo leads the import screen. Removed the step rail, generic section headings, repeated image statuses, and duplicate Notes labels. Name, Category, Type, and Color remain visible; optional metadata sits in More details. Tags use removable chips, with unfinished input included in Save. |
| Measurements | Renamed Fit passport. Optional measurements, extra fields, and measuring instructions are clearer. Size-chart comparison has its own screen, blank ranges, and an explanation of the matching measurements instead of a confidence percentage. |
| Try on | Removed slogans and oversized empty-photo headings. Availability precedes preparation; unusable entry points are hidden. Saved previews stay reachable offline. Photo tips are collapsed, while consent, cost, subscription terms, and fit limitations remain in their relevant flows. |
| Piece detail | One visible garment code, prominent wardrobe actions, meaningful wear history, and collapsed editing controls. Original/cutout controls appear only when applicable. Deletion remains in a confirmed overflow action. |
| Saved fit | Wear today leads. Piece rows open their details; editing is collapsed. Share, duplicate, and delete retain their existing functions. |
| Suggestions and search | Suggestions use factual color names without generated prose or automatically written notes. Fit search shows a thumbnail and date fallback. Continue fit is a single short action. |

Ordinary instructions and disclosures use readable system type. Archive metadata keeps its established typography. Long garment codes wrap at accessibility text sizes. Shared disclosure, menu, and field controls retain persistent accessible names.

## Bugs found during native verification

- A saved metric profile was converted again during initial loading. Loading and user-initiated unit conversion now use a tested measurement draft, preserving the saved values.
- Committing tag fragments on every comma change caused native typing to duplicate tags. Tags now commit through the add control or Return; Save also retains pending input.
- The processing sweep could expand beyond the photo and cover metadata. Its geometry is now constrained to the preview bounds.

## Checks

- **Passed:** Final Debug iOS Simulator build. The existing App Intents metadata-extraction warning remains; the app has no AppIntents framework dependency.
- **Passed:** 78 targeted Swift tests, zero failures. Coverage includes add/save and image recovery, item detail, composition, draft/wear/gallery services, suggestions, size recommendations, Try On behavior/service boundaries, entry availability, tag editing, and metric hydration/unit conversion.
- **Passed:** `git diff --check`.
- **Passed:** Native iPhone 18 Pro simulator review at standard and largest accessibility text sizes. Dark and light appearances were inspected across the edited forms and detail flows. Screenshot and accessibility-tree evidence is in `ui-evidence/copy-cleanup/`.
- **Passed:** Signed Debug build, USB installation, foreground launch, and Closet screenshot confirmation on the connected iPhone 17 Pro Max running iOS 27. This check used the existing local wardrobe; it did not exercise every interaction on the physical phone. The capture is in `ui-evidence/copy-cleanup/physical-iphone-closet.png`.
- **Passed:** Add Piece processing/failure recovery, optional details, tags, Save, and deletion of the temporary test piece. The saved test piece contained exactly `casual`, `weekday`, and the unsubmitted `summer` tag, confirmed by a read-only check of the isolated preview store.
- **Passed:** Measurements save/reopen retained 99 cm chest and 84 cm waist. A chart with chest 96–102 and waist 80–86 returned Medium. Switching category cleared the previous result; an incomplete footwear comparison displayed the no-match message.
- **Passed:** Saved-fit wear action and piece history; fit-to-piece navigation; search dates/thumbnails and no results; collapsed photo/edit controls; unavailable Try On omitted from ordinary wardrobe entry points.

## Environment and limits

The normal preview bundle is `com.zainoodle.pyxis.editorialpreview`, using isolated fixture garments. No personal wardrobe was edited. A separate temporary QA host, `com.zainoodle.pyxis.copyqa`, rendered the real Measurements and Try On views with known measurement data and a deterministic availability response. Its fixture app entry point and service response live outside the repository. They do not enable Try On in the production app, and no photos were uploaded.

**Not run:** Manual VoiceOver navigation, camera capture, file import, live AI generation, purchases, paid allowance renewal, or provider-retention compliance checks. Store and service error contracts retain their existing tests; not every failure was injected into a rendered screen. Empty saved previews and privacy/consent screens were rendered in the separate QA host. The unavailable-preview entry policy, including unreadable saved-manifest recovery, has regression coverage.

Pre-existing work in the branch was preserved. The Xcode project also has a serialization-only diff (ordering and project-format metadata); it was left intact. No new backend, subscription, or storage schema was introduced.

## Screenshots

The overview and linked evidence show rendered native screens, not image-generated mockups. Measurements and available Try On captures use the separate QA host described above.

![Cleanup overview](/Users/isaiahjohnson/.codex/worktrees/editorial-archive/Pyxis/docs/ui-evidence/copy-cleanup/cleanup-overview.png)
