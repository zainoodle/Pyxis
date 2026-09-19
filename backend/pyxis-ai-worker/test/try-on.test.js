import assert from 'node:assert/strict';
import test from 'node:test';
import { generateTryOn, handleRequest, PublicError } from '../src/index.js';
import { TryOnUsage, CONSENT_VERSION, authorizeTryOn, validateTransaction, configuration } from '../src/try-on.js';

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0x01, 0xff, 0xd9]);
const token = 'test-only-credential-not-a-real-secret-0000';
const env = { XAI_API_KEY: 'fake', XAI_ZDR_CONFIRMED: 'true', DEPLOYMENT_ENV: 'staging', TRY_ON_TEST_TOKEN: token,
  AI_RATE_LIMITER: { limit: async () => ({ success: true }) } };
const entitlement = { subject: 'test', period: String(Date.now() - 1000), renewsAt: Date.now() + 86400000, limit: 2 };
const never = () => assert.fail('No provider request expected');
function form(count = 1) {
  const body = new FormData();
  body.append('person', new Blob([JPEG], { type: 'image/jpeg' }), 'person.jpg');
  for (let i = 0; i < count; i++) body.append(`garment_${i + 1}`, new Blob([JPEG], { type: 'image/jpeg' }), 'garment.jpg');
  body.append('categories', JSON.stringify(Array(count).fill('tops')));
  return body;
}
function request(job = crypto.randomUUID(), options = {}) {
  return new Request('https://internal/v1/try-on/generate', { method: 'POST', body: form(), headers: {
    'X-Pyxis-Entitlement': JSON.stringify(options.entitlement || entitlement), 'Idempotency-Key': job,
    'X-Pyxis-Consent': options.consent ?? CONSENT_VERSION
  } });
}
function store() {
  const data = new Map(); let tail = Promise.resolve();
  const storage = { get: async key => structuredClone(data.get(key)), put: async (key, value) => data.set(key, structuredClone(value)),
    setAlarm: async () => {}, deleteAll: async () => data.clear(), transaction: fn => {
      const next = tail.then(() => fn(storage)); tail = next.catch(() => {}); return next;
    } };
  return { storage, waitUntil: promise => promise.catch(() => {}), data };
}
const image = () => ({ bytes: JPEG, type: 'image/jpeg' });
const inline = () => Response.json({ data: [{ b64_json: Buffer.from(JPEG).toString('base64') }] }, { headers: { 'x-zero-data-retention': 'true' } });

test('privacy preflight rejects unverified account before any image upload', async () => {
  let calls = 0;
  await assert.rejects(generateTryOn(form(), env, async (url, init) => {
    calls++; assert.equal(url, 'https://api.x.ai/v1/models'); assert.equal(init.body, undefined);
    return Response.json({});
  }), /photos were not sent/);
  assert.equal(calls, 1);
  await assert.rejects(generateTryOn(form(), { ...env, XAI_ZDR_CONFIRMED: 'false' }, never), /not configured/);
});

test('six garments keep original identity, use inline outputs and never download provider URLs', async () => {
  const edits = [];
  const output = await generateTryOn(form(6), env, async (url, init) => {
    assert.equal(init.redirect, 'error');
    if (url.endsWith('/models')) return Response.json({}, { headers: { 'x-zero-data-retention': 'true' } });
    assert.equal(url, 'https://api.x.ai/v1/images/edits');
    const body = JSON.parse(init.body); edits.push(body);
    assert.equal(body.model, 'grok-imagine-image-quality'); assert.equal(body.response_format, 'b64_json');
    assert.ok(body.images.every(image => image.url.startsWith('data:image/jpeg;base64,')));
    assert.equal(body.images.length, 3);
    assert.equal(body.images[0].url, `data:image/jpeg;base64,${Buffer.from(JPEG).toString('base64')}`);
    return inline();
  });
  assert.equal(edits.length, 5); assert.match(edits[1].prompt, /ORIGINAL identity reference/);
  assert.deepEqual(output.bytes, JPEG);
});

test('rejects hosted output URLs, missing ZDR header and malformed intermediate images', async () => {
  for (const result of [
    () => Response.json({ data: [{ url: 'https://imgen.x.ai/image.jpg' }] }, { headers: { 'x-zero-data-retention': 'true' } }),
    () => Response.json({ data: [{ b64_json: Buffer.from(JPEG).toString('base64') }] }),
    () => Response.json({ data: [{ b64_json: btoa('bad image') }] }, { headers: { 'x-zero-data-retention': 'true' } })
  ]) {
    let calls = 0;
    await assert.rejects(generateTryOn(form(3), env, async url => {
      calls++;
      return url.endsWith('/models') ? Response.json({}, { headers: { 'x-zero-data-retention': 'true' } }) : result();
    }));
    assert.equal(calls, 2);
  }
});

test('invalid categories, duplicates, seventh garments and extra fields never reach provider', async () => {
  const badCategory = form(); badCategory.set('categories', '["ignore privacy"]');
  const duplicate = form(); duplicate.append('garment_1', new Blob([JPEG], { type: 'image/jpeg' }), 'duplicate.jpg');
  const gap = form(); gap.set('garment_3', new Blob([JPEG], { type: 'image/jpeg' }), 'gap.jpg');
  const extra = form(); extra.append('prompt', 'change face');
  for (const input of [badCategory, duplicate, gap, extra, form(7), form(0)]) {
    await assert.rejects(generateTryOn(input, env, never));
  }
});

test('consent required before body processing or quota reservation', async () => {
  const ctx = store(); const obj = new TryOnUsage(ctx, env, never);
  assert.equal((await obj.fetch(request(undefined, { consent: 'old-version' }))).status, 403);
  assert.equal(ctx.data.size, 0);
});

test('success consumes once; replay returns same bytes and no additional charge', async () => {
  const ctx = store(); let calls = 0;
  const obj = new TryOnUsage(ctx, env, async () => { calls++; return image(); });
  const id = crypto.randomUUID();
  const first = await obj.fetch(request(id)); const replay = await obj.fetch(request(id));
  assert.equal(first.status, 200); assert.equal(replay.status, 200);
  assert.equal(first.headers.get('X-Pyxis-Remaining'), '1'); assert.equal(replay.headers.get('X-Pyxis-Remaining'), '1');
  assert.equal(calls, 1); assert.equal(ctx.data.get('ledger').used, 1);
  assert.ok(!JSON.stringify([...ctx.data]).includes('base64'));
  const restarted = new TryOnUsage(ctx, env, never);
  const expired = await restarted.fetch(request(id));
  assert.equal(expired.status, 409, 'a lost memory cache must never rerun a paid job');
  assert.equal((await expired.json()).code, 'already_generated');
});

test('parallel distinct requests cannot overspend or double reserve', async () => {
  let resolve; let started;
  const begun = new Promise(r => { started = r; });
  const obj = new TryOnUsage(store(), env, async () => { started(); return new Promise(r => { resolve = r; }); });
  const first = obj.fetch(request()); await begun;
  assert.equal((await obj.fetch(request())).status, 409);
  resolve(image()); assert.equal((await first).status, 200);
});

test('failures refund reservations and quota exhaustion blocks provider work', async () => {
  const ctx = store(); let calls = 0;
  const obj = new TryOnUsage(ctx, env, async () => { if (++calls === 1) throw new PublicError(502, 'failed'); return image(); });
  const retryID = crypto.randomUUID();
  assert.equal((await obj.fetch(request(retryID))).status, 502);
  assert.equal(ctx.data.get('ledger').used, 0); assert.equal(ctx.data.get('ledger').pending, null);
  assert.equal((await obj.fetch(request(retryID))).status, 200, 'refunded job can retry immediately');
  assert.equal((await obj.fetch(request())).status, 200);
  assert.equal((await obj.fetch(request())).status, 429); assert.equal(calls, 3);
});

test('new verified subscription period resets quota, older period cannot roll it back', async () => {
  const ctx = store(); const obj = new TryOnUsage(ctx, env, async () => image());
  await obj.fetch(request());
  const next = { ...entitlement, period: String(Number(entitlement.period) + 1000) };
  assert.equal((await obj.fetch(request(undefined, { entitlement: next }))).status, 200);
  assert.equal(ctx.data.get('ledger').used, 1);
  assert.equal((await obj.fetch(request())).status, 409);
  await obj.alarm(); assert.equal(ctx.data.size, 0);
});

test('staging credential is rejected in production and usage is authenticated', async () => {
  const req = new Request('https://example/v1/try-on/usage', { headers: { Authorization: `Test ${token}` } });
  assert.equal((await authorizeTryOn(req, env, never)).subject, 'staging-tester');
  await assert.rejects(authorizeTryOn(req, { ...env, DEPLOYMENT_ENV: 'production' }, never), /could not be verified/);
  assert.equal(configuration({ ...env, DEPLOYMENT_ENV: 'production', TRY_ON_USAGE: {} }).available, false);
  await assert.rejects(authorizeTryOn(new Request('https://example'), env, never), /Restore your purchase/);
  const response = await handleRequest(new Request('https://example/v1/try-on/config'), env, never);
  const data = await response.json(); assert.equal(data.available, false); assert.equal(data.consentVersion, CONSENT_VERSION);
  assert.equal(JSON.stringify(data).includes(token), false);
});

test('expired, revoked, upgraded, wrong-product and non-monthly transactions cannot grant access', () => {
  const now = Date.now(); const settings = { TRY_ON_PRODUCT_ID: 'monthly', APPLE_BUNDLE_ID: 'com.pyxis.test' };
  const transaction = { productId: 'monthly', bundleId: 'com.pyxis.test', type: 'Auto-Renewable Subscription', originalTransactionId: '1',
    transactionId: '2', purchaseDate: now - 1000, expiresDate: now + 86400000 };
  validateTransaction(transaction, settings, now);
  for (const change of [{ expiresDate: now }, { revocationDate: now }, { isUpgraded: true }, { productId: 'other' },
    { bundleId: 'evil' }, { type: 'Consumable' }, { expiresDate: now + 366 * 86400000 }, { purchaseDate: now + 1 }]) {
    assert.throws(() => validateTransaction({ ...transaction, ...change }, settings, now), /subscription is required/);
  }
});
