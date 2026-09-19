# Pyxis

Pyxis is a local-first iOS SwiftUI app for logging and organizing clothing items.

The optional Fit Passport stores body measurements locally and compares them with retailer-provided size charts. It explains the measurements used and does not claim a universal size or medical assessment.

The macOS prototype has been preserved on the `macos-main` branch. The `main` branch is the iOS version.

## Repository Layout

```text
Pyxis/
├── README.md
├── Package.swift              # Swift package and core test targets
├── Pyxis.xcodeproj/           # iOS application build configuration
├── src/
│   ├── main/                 # App entry point and root view
│   ├── services/
│   ├── models/
│   ├── utils/
│   ├── persistence/
│   ├── design-system/
│   ├── view-models/
│   └── views/
├── tests/PyxisTests/          # Swift core tests
├── scripts/                  # Build, test, release, and validation commands
├── docs/
│   └── references/           # Original requirements and reference documents
├── assets/                   # Asset catalog and bundled privacy manifest
├── config/
│   └── deployment/           # App Store export configuration
├── backend/pyxis-ai-worker/   # Independently deployed gateway and its tests
└── changes/                  # Structured release notes
```

Xcode includes `src/` and `assets/` through synchronized groups. Swift Package Manager uses explicit source and test paths in `Package.swift`. Gateway dependencies and configuration stay with its `package.json`, lockfile, and `wrangler.jsonc`; generated dependencies and build output are Git-ignored.

Run core tests with `./scripts/test.sh`, and gateway tests with `npm test --prefix backend/pyxis-ai-worker`.

## Versioning

App versions use `major.minor.patch`; a separate build counter identifies each TestFlight/App Store upload. Both values live in `config/Version.xcconfig`. Run `python3 scripts/version.py next` to see the next release implied by pending notes, then `./scripts/prepare_release.sh auto --dry-run` to preview preparation. See `docs/RELEASE_PROCESS.md` for releases and build-only updates.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17+ simulator or device
- A signing team selected in Xcode for physical iPhone deployment

## Contributor Notes

- Follow `AGENTS.md` and `CONTRIBUTING.md` for code standards, PR scope, and review.
- Codex names PRs and flags work that needs a separate PR. App/product renames still require Isaiah’s approval.
- Install the repository Git hooks with `./scripts/install_git_hooks.sh`.
- Maintain one structured file under `changes/` per PR and use Conventional Commit subjects.
- Follow `docs/RELEASE_PROCESS.md` for version bumps, changelog generation, tags, and release verification.

## Run On iPhone

1. Open `Pyxis.xcodeproj` in Xcode.
2. Select the `Pyxis` scheme.
3. Select your connected iPhone.
4. In Signing & Capabilities, choose your team if Xcode asks.
5. Press Run.

## Run On Simulator

Boot an iPhone simulator, then run:

```bash
./scripts/build_and_run.sh --verify
```

Deployment readiness notes are tracked in `docs/DEPLOYMENT_READINESS.md`.
App Store Connect submission notes are tracked in `docs/APP_STORE_SUBMISSION.md`.
Public support and privacy page drafts are in `docs/SUPPORT.md` and `docs/PRIVACY_POLICY.md`.

## Deployment Preflight

Run the local deployment preflight before handing off a build:

```bash
./scripts/deployment_preflight.sh local
```

Run the distribution preflight after App Store Connect provider access and an App Store distribution profile are configured:

```bash
./scripts/deployment_preflight.sh distribution
```

## Local-first closet and Outfit on you

The closet, background removal, garment recognition, measurements, and saved fits work on device. Outfit on you adds an optional paid image preview: choose a full-body reference, add up to six pieces from the closet or Photos, correct suggested garment types if needed, and generate. There is no chat interface. You can compare the original and preview, save results locally, and remove your reference or saved previews.

Cloud generation requires explicit consent and xAI zero-retention processing. The provider, model, and credentials are backend concerns; users see photos, privacy choices, and a monthly allowance. Until configured, the app shows a coming-soon state and makes no photo uploads. On-device try-on generation is not bundled in this version; the client service protocol leaves room for a future implementation.

StoreKit supplies subscription pricing and verified purchases. The Worker enforces a configurable monthly allowance (initially 20 successful previews) and idempotent requests. Reference saving is opt-in, protected try-on files are excluded from backups, and purchase/usage metadata is retained separately from photos.

AI garment cleanup remains an independent optional action with its existing disclosure and prototype authentication. Never embed an xAI provider key in the app. See [AI gateway setup](docs/AI_GATEWAY.md) for staging tests, purchase configuration, privacy requirements, and remaining release gates.
