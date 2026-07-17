# Pyxis

Pyxis is a local-first iOS SwiftUI app for logging and organizing clothing items.

The optional Fit Passport stores body measurements locally and compares them with retailer-provided size charts. It explains the measurements used and does not claim a universal size or medical assessment.

The macOS prototype has been preserved on the `macos-main` branch. The `main` branch is the iOS version.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17+ simulator or device
- A signing team selected in Xcode for physical iPhone deployment

## Contributor Notes

- Confirm the project/app name with the user before naming or renaming project surfaces. Suggestions are welcome, but do not decide the name without approval.
- Install the repository Git hooks with `./script/install_git_hooks.sh`.
- Add a structured file under `changes/` for every pushed update and use Conventional Commit subjects.
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

## Local-First Core and Opt-In AI Studio

- No accounts.
- No analytics or telemetry.
- Core closet organization, background removal, and saved-fit features work locally.
- `AI DE-WRINKLE` and `AI TRY-ON` are optional actions that upload only the photos selected for that generation.
- AI requests go through a Pyxis-owned backend; never put an OpenAI API key in the app.

Images are stored locally in Application Support. Metadata is stored with SwiftData.
On-device memory records, including item/fit summaries and local embedding vectors, are keyed, validated, stored with SwiftData, and retrieved in-process.

Set the `PYXIS_AI_BASE_URL` Xcode build setting to the HTTPS origin that implements:

- `POST /v1/ai/garment-cleanup` with multipart field `source`
- `POST /v1/ai/virtual-try-on` with multipart fields `person` and `garment_1...n`

Each endpoint returns image bytes, or JSON `{ "image_base64": "..." }`. The backend should use GPT Image 2, authenticate/rate-limit callers, remove image metadata, impose upload limits, and keep `OPENAI_API_KEY` server-side.
