# Pyxis Deployment Readiness

Last audited: 2026-08-27

## Current v1.1 Verification

- `./script/test.sh` passes with 110 XCTest cases from a fresh temporary SwiftPM scratch directory while using `/Applications/Xcode.app/Contents/Developer` explicitly.
- A full iOS 17 source type-check against the installed iPhoneOS SDK passes with no diagnostics.
- `./script/deployment_preflight.sh static` passes, including the privacy/document consistency validator.
- Worker `npm ci`, six Node tests, JavaScript syntax checking, and `npm audit --audit-level=high` pass; the current lockfile reports zero vulnerabilities.
- Xcode's iOS 26.5 Simulator runtime is installed, and current Debug builds, installs, launches, and process verification pass on iPhone 17e and iPhone 17 Pro Max simulators.
- `./script/build_and_run.sh --verify` passes repeatedly on the booted iPhone 17e. It now keeps DerivedData outside the iCloud-synced checkout and verifies the host-side Simulator process without relying on unavailable in-runtime `ps` tooling.
- `./script/deployment_preflight.sh local` passes, including clean tests, a generic unsigned Release iOS build, artifact inspection, and an unsigned Release archive.
- Current simulator smoke checks pass for empty Closet, Add Item open/cancel, debug import through review, save-original fallback, grid persistence after relaunch, subtype/filter chips and reset, search-specific no-results recovery, native item detail navigation, direct Build handoff, AI unavailable state, Save Fit confirmation, and compact/Pro Max initial layouts.
- An AX5 Dynamic Type plus Increased Contrast check exposed and then verified the accessibility fallback for the Closet header, search/sort/favorites controls, and single-column filter options. Full VoiceOver and Reduce Motion walkthroughs remain manual gates.
- The connected iPhone 17 Pro Max is paired and recognized as an eligible destination. Physical-device build/install remains gated on enabling Developer Mode in Settings > Privacy & Security on that phone.

## Previously Verified Release Evidence

- `swift test` passed with 97 XCTest cases at the time of the earlier release audit.
- Focused on-device memory tests pass with 13 XCTest cases.
- SwiftData can open a store created before `OnDeviceMemoryRecord` existed and then persist a memory record.
- Closet item and saved-fit save paths populate local memory records with deterministic on-device embeddings.
- iOS simulator Debug build passed through XcodeBuildMCP with no diagnostics during the earlier release audit.
- iOS simulator build/install/launch passed through XcodeBuildMCP during the earlier release audit.
- `./script/build_and_run.sh --verify` passed on a booted iOS Simulator during the earlier release audit and replaced the existing app process.
- `./script/deployment_preflight.sh local` passes, covering metadata linting, policy scans, privacy-manifest regression scans, whitespace checks, `swift test`, generic Release iOS build, artifact metadata inspection, Release debug-content scans, and unsigned Release archive.
- Generic Release iOS build passes with `CODE_SIGNING_ALLOWED=NO`.
- Unsigned Release archive creation passes with `CODE_SIGNING_ALLOWED=NO`.
- The built app and archive include compiled app icon files, `CFBundleIconName = AppIcon`, and `PrivacyInfo.xcprivacy`.
- The built app and archive assert `CFBundleDisplayName = Pyxis`, camera and photo-library usage descriptions, `LSApplicationCategoryType = public.app-category.lifestyle`, minimum iOS `17.0`, and iPhone-only `UIDeviceFamily = [1]`.
- The App Store icon source is a 1024 x 1024 opaque RGB PNG with no alpha channel.
- The Release build and unsigned archive scan clean for debug-only sample import, closet seeding strings, and sample item codes.
- Static scan confirms the only app networking surface is the opt-in `AIGarmentStudioService`; provider credentials are absent from the app, while analytics and telemetry remain absent.
- Static scan found no currently undeclared required-reason API usage in `Pyxis` or `Package.swift`.
- Static manifest validation confirms `PrivacyInfo.xcprivacy` declares optional photos/videos for app functionality as unlinked and non-tracking, with no tracking domains or required-reason API categories.
- Static support-page validation confirms the support and privacy drafts use the same concrete support contact.
- Screenshot inspection confirmed the launched simulator app presents the Pyxis closet grid and empty state.
- The app is configured and Release-built as iPhone-only (`UIDeviceFamily = [1]`) so App Store submission does not require unverified iPad screenshots or iPad manual QA.
- App Store Connect draft metadata, support-page draft, and privacy-policy draft are documented in `docs/APP_STORE_SUBMISSION.md`, `docs/SUPPORT.md`, and `docs/PRIVACY_POLICY.md`.
- App Store Connect export options are documented in `deployment/ExportOptions-AppStoreConnect.plist`.
- Connected `Isaiah’s iPhone` was detected through `devicectl` and is paired for development.
- Debug iPhone device build succeeded for `Isaiah’s iPhone` using team `2AW3C9R4CX`, `Apple Development: zainoodle@gmail.com (8NQ4NJFK43)`, and an automatically provisioned `iOS Team Provisioning Profile: com.zainoodle.pyxis`.
- The signed Debug app installed and launched successfully on the connected iPhone through `devicectl`.
- Signed Release archive creation succeeded, but the archive is development-signed with `get-task-allow = true`; it is not yet an App Store/TestFlight distribution export.
- Local App Store Connect export with `deployment/ExportOptions-AppStoreConnect.plist` was attempted, but Xcode could not authenticate an App Store Connect provider and no App Store export profile for `com.zainoodle.pyxis` was available.
- `./script/deployment_preflight.sh distribution` currently stops at the same distribution-signing gate because the signed archive is development-signed.

## Fixed During Audit

- Downsampled local wardrobe images before decoding and caching them for display, capping memory use during grid and carousel browsing.
- Added one-tap single-item wear logging and automated coverage for wear count and last-worn date updates.
- Added a destructive confirmation before item and local-image deletion.
- Added SwiftData-backed on-device memory records and local memory retrieval.
- Added stable local memory keys, optional scopes for global preference memory, summary/tag sanitization, finite-vector validation, and transactional memory cleanup on item deletion.
- Added local memory payload generation for closet items and saved fits, then wired item add/edit and fit save/edit/wear paths to upsert records in the same SwiftData transaction.
- Added local memory tests for payload generation, persistence, idempotent upsert, scoped global memories, validation, similarity ranking, rollback-safe upsert/deletion, and full memory deletion.
- Added schema-upgrade coverage for stores created before the memory model existed.
- Updated the simulator run script to terminate an existing app process before install/launch.
- Strengthened script verification to confirm the launched simulator process remains alive.
- Added Escape close shortcuts to modal/detail surfaces.
- Made item detail close explicitly save pending edits.
- Added clearer accessibility labels and selected-state values for filters and key item actions.
- Added Dynamic Type-backed typography, stronger inactive/border contrast, and 44-point minimum targets for shared and filtering controls.
- Added protected local image storage and cleanup for abandoned add-item drafts.
- Added one-piece outfit support, complete saved-fit lifecycle actions, and boundary-safe sizing including footwear charts.
- Added an asset catalog with app icon and accent color assets.
- Added an app privacy manifest declaring no tracking or tracking domains and no required-reason API declarations; it now truthfully declares photos/videos used for optional AI app functionality as unlinked and non-tracking.
- Aligned the Xcode target to iPhone-only deployment and opted out of unverified Mac/Vision "Designed for iPhone/iPad" compatibility.
- Added App Store submission notes and a publishable privacy-policy draft.
- Added a publishable support-page draft with a concrete support contact.
- Removed draft-marker text from the publishable privacy policy.
- Added an App Store Connect export options template using Xcode's current `app-store-connect` method.
- Reverified simulator, physical-device build/install, unsigned archive, signed archive, and App Store export gates after wiring on-device memory into save paths.
- Added `script/deployment_preflight.sh` for repeatable static, local, and distribution readiness checks.
- Flattened the 1024px App Store icon source to an opaque RGB PNG and added preflight validation for icon pixel size and alpha.
- Added a preflight scan for required-reason API usage while the privacy manifest declares no accessed API categories.
- Added Release artifact scans to prevent debug-only sample import, closet seeding UI, messages, and sample item codes from shipping.
- Added explicit preflight validation that the privacy manifest still matches the local-core and opt-in AI privacy posture.
- Added preflight validation for user-visible app metadata, the photo-library purpose string, app category, and absence of iPad device-family metadata in built Release artifacts.
- Added preflight validation that the support-page and privacy-policy drafts use the same support contact.
- Expanded the git ignore rule to cover generated `DerivedData*` build directories.
- Updated stale docs that still described the old macOS prototype as the current app shape.

## Remaining Manual Gates

- The release privacy label must disclose photos/videos used for app functionality if optional AI is enabled while xAI's standard request/response retention of up to 30 days is active; confirm the final answers in App Store Connect against the shipped artifact and current provider terms.

- Deploy `backend/pyxis-ai-worker`, configure its secrets, and complete the real xAI checks in `docs/AI_GATEWAY.md`.
- Replace the initial shared gateway token with App Attest or short-lived server-issued tokens before a broad public release.
- Update App Store privacy answers to disclose photos sent for optional xAI image generation and xAI's current temporary retention.
- Publish `docs/SUPPORT.md` and `docs/PRIVACY_POLICY.md` at stable public URLs before App Store submission.
- Confirm both public pages use the same support contact configured in App Store Connect.
- Run the full checklist in `docs/MANUAL_QA.md` with real clothing images.
- Confirm photo-library import on a physical iPhone.
- Confirm local background-removal quality with representative clothing photos.
- Complete App Store Connect metadata, age rating, content rights, pricing/availability, export compliance, DSA/trader status, and any region-specific compliance fields.
- Capture final iPhone App Store screenshots using owned or licensed clothing images.
- Create/download an Apple Distribution signing identity and App Store distribution provisioning profile for `com.zainoodle.pyxis`; this Mac currently has only the Apple Development identity used for phone testing.
- Run `./script/deployment_preflight.sh distribution`, then create a distribution-signed archive/export and TestFlight/App Store upload only after the signing team, bundle ID, version, build number, and App Store distribution profile/certificate are confirmed in Xcode and App Store Connect.
