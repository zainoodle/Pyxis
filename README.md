# ARCHIVE

ARCHIVE is a local-first iOS SwiftUI app for logging and organizing clothing items.

The macOS prototype has been preserved on the `macos-main` branch. The `main` branch is the iOS version.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17+ simulator or device
- A signing team selected in Xcode for physical iPhone deployment

## Run On iPhone

1. Open `ARCHIVE.xcodeproj` in Xcode.
2. Select the `ARCHIVE` scheme.
3. Select your connected iPhone.
4. In Signing & Capabilities, choose your team if Xcode asks.
5. Press Run.

## Run On Simulator

Boot an iPhone simulator, then run:

```bash
./script/build_and_run.sh --verify
```

## Local-First Scope

- No accounts.
- No analytics or telemetry.
- No cloud upload.
- No remote image processing.
- No remote AI calls.

Images are stored locally in Application Support. Metadata is stored with SwiftData.
