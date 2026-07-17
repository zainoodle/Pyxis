# Pyxis xAI Gateway

Pyxis sends user-requested AI image jobs to a Cloudflare Worker, which calls the official xAI Images API. The iOS app never receives or stores `XAI_API_KEY`.

## Request Flow

```text
Pyxis iOS -> Pyxis Cloudflare Worker -> xAI Images API
```

The Worker exposes the two routes already used by the app:

- `POST /v1/ai/garment-cleanup` with multipart field `source`
- `POST /v1/ai/virtual-try-on` with multipart fields `person` and `garment_1...n`

The Worker uses `grok-imagine-image-quality`. xAI accepts at most three source images per edit, so virtual try-on applies garments in batches of two. A person plus one or two garments uses one provider call; larger outfits use additional calls and consume more of the xAI usage pool.

## One-Time Setup

Requirements:

- An xAI account with API access visible in Grok's Usage screen
- A Cloudflare account
- Node.js 22 or newer

Install and verify the Worker:

```bash
cd backend/pyxis-ai-worker
npm install
npm test
npm run check
```

Sign in to Cloudflare. The keyring option keeps the Wrangler login credential in macOS Keychain:

```bash
npx wrangler login --use-keyring
```

Create an xAI API key in the xAI console. Do not paste either secret into chat, a shell command argument, Xcode source, or a committed file. Enter each value only when Wrangler prompts:

```bash
npx wrangler secret put XAI_API_KEY
npx wrangler secret put PYXIS_ACCESS_TOKEN
```

Use a separate long random value for `PYXIS_ACCESS_TOKEN`. You can generate one locally with `openssl rand -hex 32`. It is a revocable gateway credential, not the xAI provider key.

Deploy and check the public health route:

```bash
npm run deploy
curl https://YOUR-WORKER.workers.dev/health
```

The response should be:

```json
{"status":"ok","provider":"xai"}
```

## Configure The App

Create the Git-ignored local configuration:

```bash
cp Config/Pyxis.local.xcconfig.example Config/Pyxis.local.xcconfig
```

Set these values in `Config/Pyxis.local.xcconfig`:

- `PYXIS_AI_BASE_URL` to `https:/$()/YOUR-WORKER.workers.dev` (xcconfig syntax; it resolves to the normal `https://` URL)
- `PYXIS_AI_ACCESS_TOKEN` to the value entered for the Worker's `PYXIS_ACCESS_TOKEN`

Keep `Config/Pyxis.local.xcconfig` private and never stage it. The checked-in defaults remain blank. A missing URL or access token makes the feature fail closed with `AI Studio is not configured yet.`

The shared access token prevents an unconfigured public endpoint from being used casually, but it can be extracted from a distributed app. Before a broad public release, replace it with Apple App Attest assertions or short-lived server-issued tokens. The Worker also applies a six-generation-per-minute address limit to protect the xAI pool.

## Local Worker Development

Copy `.dev.vars.example` to `.dev.vars` and fill it locally. `.dev.vars` is ignored by Git:

```bash
cd backend/pyxis-ai-worker
cp .dev.vars.example .dev.vars
npm run dev
```

Never use production secrets in automated tests. Worker tests use fake values and mocked xAI responses.

## Privacy And Operations

- Pyxis re-encodes selected photos as bounded JPEGs, which removes source metadata before upload.
- The Worker accepts only JPEG, PNG, or WebP, limits each image to 4 MB, limits a try-on to six garments, and does not log request bodies.
- Responses use `Cache-Control: no-store`.
- The gateway does not write photos to KV, R2, D1, or another persistent store.
- xAI's standard API terms currently allow request and response retention for up to 30 days. The in-app disclosure and privacy policy must stay synchronized with the active provider terms.
- A repeated outfit may consume multiple xAI calls. Monitor Grok Settings -> Usage before raising the rate limit.

## Verification Before TestFlight

1. Run `npm test` and `npm run check` in `backend/pyxis-ai-worker`.
2. Run `./script/deployment_preflight.sh local` from the repository root.
3. Confirm `/health` on the deployed Worker.
4. On a physical iPhone, test one cleanup and try-ons with one, two, and three garments.
5. Confirm the xAI Usage screen records the expected one, one, one, and two provider calls respectively.
6. Confirm invalid tokens receive `401`, excess requests receive `429`, and the Worker contains no request-body logging.
