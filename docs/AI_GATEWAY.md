# Pyxis AI gateway

The app talks to Pyxis over HTTPS. Provider keys, model selection, receipt verification, and allowance enforcement live in the Cloudflare Worker. There are no API settings in the customer interface.

## Outfit on you

Users choose a full-body reference and up to six garment images from their closet or Photos. Vision suggests garment categories on device; users can correct them. The model receives category hints and identifies garments in the images. No conversational prompt is exposed. Each generation uses the original person reference, including subsequent multi-garment edits.

The first version uses xAI `grok-imagine-image-quality`, configurable through `XAI_MODEL`. One or two garments require one edit; each additional garment requires another edit so the original person and latest preview can both remain in context. Six garments can therefore cost five provider calls while consuming **one** user try-on. Price the subscription with this maximum cost in mind. Current xAI documentation schedules this model's retirement for November 2, 2026; revalidate prompts and image limits before changing models. See [xAI image generation](https://docs.x.ai/developers/model-capabilities/images/generation).

The default allowance is **20 successful previews per monthly subscription period**, configured by `TRY_ON_MONTHLY_LIMIT` (1–100). The App Store product supplies the actual price. The server validates the signed StoreKit transaction against Apple's pinned certificate roots, refreshes it from Apple's transaction endpoint, rejects expired/refunded/upgraded or different-product purchases, and keeps a per-subscription Durable Object ledger. Failed jobs release reservations. Concurrent jobs are rejected; idempotency keys prevent duplicate charges. A successful result can be replayed in memory for 60 seconds; after eviction the same job returns 409 rather than generating/charging again. A disconnected request may still finish and consume a try-on; the app refreshes the server allowance on error. No automatic provider retries occur.

Routes:

| Route | Authorization | Result |
| --- | --- | --- |
| `GET /v1/try-on/config` | None | Availability, allowance, product ID, versioned privacy contract |
| `GET /v1/try-on/usage` | Verified purchase | Remaining allowance and renewal date |
| `POST /v1/try-on/generate` | Verified purchase and explicit consent | Image bytes and updated allowance headers |
| `POST /v1/ai/garment-cleanup` | Existing prototype gateway token | Cleanup image bytes |
| `POST /v1/ai/virtual-try-on` | None | 410; retired to prevent bypassing paid limits |

Generation multipart fields are `person`, consecutive `garment_1` through `garment_6`, and JSON `categories`. Headers include `Authorization: Transaction <StoreKit JWS>`, `X-Pyxis-Consent: try-on-xai-zdr-v1`, and a UUID `Idempotency-Key`. These are internal implementation details.

## Connect a test API later

1. Install dependencies with `npm ci` in `backend/pyxis-ai-worker`. Run `npm test` and `npm run check`.
2. Enable **team-wide Zero Data Retention** with xAI. Try-on fails closed without it, even if the environment flag was set incorrectly. Before sending any photos, the Worker checks the account's `x-zero-data-retention` response header; it checks edit responses too. All results must be base64 bytes, never hosted image URLs. See [xAI Zero Data Retention](https://docs.x.ai/developers/faq/security).
3. Sign into Cloudflare with `npx wrangler login --use-keyring`. Use prompt-based secrets; never paste keys into source, chat, or command arguments:

```bash
npx wrangler secret put XAI_API_KEY --env staging
npx wrangler secret put TRY_ON_TEST_TOKEN --env staging
```

Use a random staging token of at least 32 characters. After ZDR is enabled, set `env.staging.vars.XAI_ZDR_CONFIRMED` to `"true"` in the Worker config. Deploy explicitly with `npx wrangler deploy --env staging` when authorized. Nothing in this feature branch deploys automatically.

4. Copy `config/Pyxis.local.xcconfig.example` to the ignored `config/Pyxis.local.xcconfig`. Set `PYXIS_AI_BASE_URL` to the final HTTPS staging Worker origin (`https:/$()/...` in xcconfig syntax) and `PYXIS_TRY_ON_TEST_TOKEN` to the staging token. Debug builds read it; Release builds force it blank. The real xAI key stays exclusively in Worker secrets. Staging testers share one calendar-month allowance; this path is never accepted by production.
5. Build Debug and open Build → Outfit on you. No customer-facing configuration is needed. Until the service is configured, users can prepare photos and browse saved previews; generation is unavailable.

Local Worker testing uses ignored `.dev.vars` copied from `.dev.vars.example`. Use mocked responses and fake credentials for automated tests. Do not point a real person's photo at a test service without their permission.

## Production purchases

Create one monthly auto-renewable subscription in App Store Connect. Configure `TRY_ON_PRODUCT_ID`, `APPLE_BUNDLE_ID`, and numeric `APPLE_APP_ID`; set `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, and `APPLE_PRIVATE_KEY` (In-App Purchase .p8 key) through Wrangler secrets. Use production `DEPLOYMENT_ENV`, which forces Apple's Production verification environment and rejects test tokens. For Apple Sandbox testing use the staging environment with `APPLE_ENVIRONMENT=Sandbox` and the same product identifiers. No price is hard-coded. The app supports purchase, pending/cancelled purchases, restore, renewal dates, and subscription management.

The server refreshes transaction information on every authorized call. Certificate chains and signatures are verified with Apple's library; online certificate-revocation checks are disabled, so production validation must include review of that trust policy. Provider-account ZDR availability and real StoreKit Sandbox flows remain release gates.

## Privacy and storage

Selected images are re-encoded as bounded JPEGs on device to strip source metadata. Try-on requires versioned, explicit sharing consent and never falls back to standard provider retention. xAI ZDR does not persist photo inputs or outputs; Pyxis does not authorize training use. The gateway never writes photos to durable storage or logs bodies. Brief replay bytes exist only in memory. Responses use `Cache-Control: no-store`, reject redirects, and have transfer size/deadline limits.

Durable storage contains only billing-period/usage counters and generation IDs, keyed to the subscription's original transaction identifier. An alarm deletes them 35 days after that period ends unless continued usage updates the ledger. Apple handles payment details. The privacy manifest conservatively declares photos as linked because paid requests authenticate a subscription, even though photo bytes are not persisted. The client stores consent in app-only UserDefaults. Try-on reference photos and saved previews use protected, backup-excluded local files; saving a reference is opt-in. Unsaved session images are deleted when the screen closes, and abandoned sessions are cleaned on the next try-on launch. A version-1 manifest is additive; existing closet/SwiftData records are unchanged, and unknown future manifests are never overwritten.

**Garment cleanup remains a separate, existing path:** xAI's standard retention may retain its requests/responses for up to 30 days. Its prototype shared gateway token must be replaced before broad public release. See [security audit](SECURITY_AUDIT_2026-09-18.md).

## Verification before release

Run Swift and Worker tests, privacy preflight, and both Debug/Release builds. On staging, verify Apple purchase/restore/renew/refund, concurrent and exhausted allowances, poor-network recovery, and generations with one, two, three, and six garments. Inspect xAI usage and ZDR response headers. Test consent refusal/revocation, remembered-photo removal, saved-preview deletion, accessibility, and real photo imports on a physical iPhone. Do not advertise try-on until provider quality, costs, privacy configuration, and purchase flows have passed these checks.

## Personal PC model connection

A separate Debug-only adapter can connect Outfit on you directly to a ComfyUI image-edit model over Tailscale. It uses its own explicit consent contract because ComfyUI writes temporary files on the PC. It does not reuse the xAI zero-retention claim, deploy the Worker, or grant paid production access. See [Private PC image API](PC_IMAGE_API.md) for setup, workflow requirements, privacy, and current verification limits.
