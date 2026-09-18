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

## Local-First Core and Opt-In AI Studio

- No accounts.
- No analytics or telemetry.
- Core closet organization, background removal, and saved-fit features work locally.
- `AI DE-WRINKLE` and `AI TRY-ON` are optional actions that upload only the photos selected for that generation.
- AI requests go through the Pyxis xAI gateway; never put an xAI provider key in the app.

Images are stored locally in Application Support. Metadata is stored with SwiftData.
On-device memory records, including item/fit summaries and local embedding vectors, are keyed, validated, stored with SwiftData, and retrieved in-process.

Deploy `backend/pyxis-ai-worker`, copy `config/Pyxis.local.xcconfig.example` to the Git-ignored `config/Pyxis.local.xcconfig`, then set:

- `PYXIS_AI_BASE_URL`: the Worker's HTTPS origin
- `PYXIS_AI_ACCESS_TOKEN`: the same scoped gateway token stored as the Worker's `PYXIS_ACCESS_TOKEN` secret

The gateway implements:

- `POST /v1/ai/garment-cleanup` with multipart field `source`
- `POST /v1/ai/virtual-try-on` with multipart fields `person` and `garment_1...n`

Each endpoint returns image bytes. The included Cloudflare Worker authenticates and rate-limits callers, validates uploads, calls `grok-imagine-image-quality`, and keeps `XAI_API_KEY` server-side. The app downsamples uploads and strips their source metadata before sending them.

See `docs/AI_GATEWAY.md` for secret setup, deployment, testing, and the production-authentication limitation of the initial shared gateway token.
