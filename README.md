# Pyxis

Pyxis is a local-first iOS SwiftUI app for logging and organizing clothing items.

The macOS prototype has been preserved on the `macos-main` branch. The `main` branch is the iOS version.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17+ simulator or device
- A signing team selected in Xcode for physical iPhone deployment

## Contributor Notes

- Confirm the project/app name with the user before naming or renaming project surfaces. Suggestions are welcome, but do not decide the name without approval.

## Run On iPhone

1. Open `Pyxis.xcodeproj` in Xcode.
2. Select the `Pyxis` scheme.
3. Select your connected iPhone.
4. In Signing & Capabilities, choose your team if Xcode asks.
5. Press Run.

## Run On Simulator

Boot an iPhone simulator, then run:

```bash
./script/build_and_run.sh --verify
```

Deployment readiness notes are tracked in `docs/DEPLOYMENT_READINESS.md`.
App Store Connect submission notes are tracked in `docs/APP_STORE_SUBMISSION.md`.
Public support and privacy page drafts are in `docs/SUPPORT.md` and `docs/PRIVACY_POLICY.md`.

## Deployment Preflight

Run the local deployment preflight before handing off a build:

```bash
./script/deployment_preflight.sh local
```

Run the distribution preflight after App Store Connect provider access and an App Store distribution profile are configured:

```bash
./script/deployment_preflight.sh distribution
```

## Local-First Scope

- No accounts.
- No analytics or telemetry.
- No cloud upload.
- No remote image processing.
- No remote AI calls.

Images are stored locally in Application Support. Metadata is stored with SwiftData.
On-device memory records, including item/fit summaries and local embedding vectors, are keyed, validated, stored with SwiftData, and retrieved in-process.
