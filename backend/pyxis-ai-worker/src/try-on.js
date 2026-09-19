import { Buffer } from 'node:buffer';
import { createPrivateKey, sign } from 'node:crypto';
import { appleRoots } from './apple-roots.js';
import { PublicError, json, readBoundedBody, generateTryOn } from './index.js';

export const CONSENT_VERSION = 'try-on-xai-zdr-v1';
const day = 86_400_000;

export function configuration(env) {
  const limit = Number(env.TRY_ON_MONTHLY_LIMIT || 20);
  const configured = Boolean(env.XAI_API_KEY && env.XAI_ZDR_CONFIRMED === 'true' && env.TRY_ON_USAGE &&
    ((env.DEPLOYMENT_ENV === 'staging' && env.TRY_ON_TEST_TOKEN?.length >= 32) || (env.APPLE_PRIVATE_KEY && env.APPLE_KEY_ID && env.APPLE_ISSUER_ID &&
      env.APPLE_BUNDLE_ID && env.APPLE_APP_ID && env.TRY_ON_PRODUCT_ID)));
  return { available: configured && Number.isInteger(limit) && limit > 0 && limit <= 100,
    limit, consentVersion: CONSENT_VERSION, provider: 'xAI', retention: 'zero',
    productID: env.TRY_ON_PRODUCT_ID || null };
}

export async function handlePaidTryOn(request, env, fetchImpl) {
  const path = new URL(request.url).pathname;
  if (path === '/v1/try-on/config' && request.method === 'GET') return json(configuration(env));
  if (!configuration(env).available) throw new PublicError(503, 'Try-on is not available yet. Your photos have not been uploaded to xAI.');
  const entitlement = await authorizeTryOn(request, env, fetchImpl);
  const id = env.TRY_ON_USAGE.idFromName(entitlement.subject);
  const headers = new Headers(request.headers);
  headers.delete('Authorization');
  headers.set('X-Pyxis-Entitlement', JSON.stringify(entitlement));
  // The Durable Object has no public URL. Only this authenticated entry point supplies entitlements.
  return env.TRY_ON_USAGE.get(id).fetch(new Request(request, { headers }));
}

export async function authorizeTryOn(request, env, fetchImpl, now = Date.now()) {
  const authorization = request.headers.get('Authorization') || '';
  if (authorization.startsWith('Test ')) {
    // Explicit staging-only access. Production cannot opt into the test credential path.
    if (env.DEPLOYMENT_ENV !== 'staging' || !env.TRY_ON_TEST_TOKEN || env.TRY_ON_TEST_TOKEN.length < 32 ||
        !(await equal(authorization.slice(5), env.TRY_ON_TEST_TOKEN))) {
      throw new PublicError(401, 'Try-on access could not be verified.');
    }
    const start = Date.UTC(new Date(now).getUTCFullYear(), new Date(now).getUTCMonth(), 1);
    const end = Date.UTC(new Date(now).getUTCFullYear(), new Date(now).getUTCMonth() + 1, 1);
    return { subject: 'staging-tester', period: String(start), renewsAt: end, limit: configuration(env).limit };
  }
  if (!authorization.startsWith('Transaction ') || authorization.length > 24000) {
    throw new PublicError(401, 'Restore your purchase to use try-on.');
  }
  const environment = env.APPLE_ENVIRONMENT === 'Sandbox' && env.DEPLOYMENT_ENV === 'staging' ? 'Sandbox' : 'Production';
  // jsrsasign initializes randomness; load the verifier inside a request, never at Worker startup.
  const { SignedDataVerifier } = await import('@apple/app-store-server-library/dist/jws_verification.js');
  const verifier = new SignedDataVerifier(appleRoots.map(cert => Buffer.from(cert, 'base64')), false,
    environment, env.APPLE_BUNDLE_ID, Number(env.APPLE_APP_ID));
  let claimed;
  try { claimed = await verifier.verifyAndDecodeTransaction(authorization.slice(12)); }
  catch { throw new PublicError(401, 'Your App Store purchase could not be verified.'); }
  validateTransaction(claimed, env, now);
  // Refresh from Apple on every authorized request: an old, valid signature cannot bypass a refund.
  const host = environment === 'Sandbox' ? 'api.storekit-sandbox.apple.com' : 'api.storekit.apple.com';
  const response = await fetchImpl(`https://${host}/inApps/v1/transactions/${encodeURIComponent(claimed.transactionId)}`, {
    redirect: 'error', signal: AbortSignal.timeout(15000), headers: { Authorization: `Bearer ${appleToken(env, now)}` }
  });
  if (!response.ok) { await response.body?.cancel(); throw new PublicError(503, 'Purchase verification is temporarily unavailable.'); }
  const data = await readBoundedBody(response.body, 64000, new PublicError(502, 'Invalid purchase response.'));
  let current;
  try { current = await verifier.verifyAndDecodeTransaction(JSON.parse(new TextDecoder().decode(data)).signedTransactionInfo); }
  catch { throw new PublicError(401, 'Your App Store purchase could not be verified.'); }
  validateTransaction(current, env, now);
  if (current.originalTransactionId !== claimed.originalTransactionId || current.transactionId !== claimed.transactionId) {
    throw new PublicError(401, 'Purchase verification did not match.');
  }
  return { subject: `${environment}:${current.originalTransactionId}`, period: String(current.purchaseDate),
    renewsAt: current.expiresDate, limit: configuration(env).limit };
}

export function validateTransaction(transaction, env, now) {
  if (transaction.productId !== env.TRY_ON_PRODUCT_ID || transaction.bundleId !== env.APPLE_BUNDLE_ID ||
      transaction.type !== 'Auto-Renewable Subscription' || transaction.revocationDate || transaction.isUpgraded ||
      !transaction.originalTransactionId || !transaction.transactionId ||
      !Number.isFinite(transaction.purchaseDate) || !Number.isFinite(transaction.expiresDate) ||
      transaction.purchaseDate > now || transaction.expiresDate <= now ||
      transaction.expiresDate - transaction.purchaseDate > 32 * day) {
    throw new PublicError(403, 'An active monthly try-on subscription is required.');
  }
}

function appleToken(env, now) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({ alg: 'ES256', kid: env.APPLE_KEY_ID, typ: 'JWT' })}.${encode({
    iss: env.APPLE_ISSUER_ID, iat: Math.floor(now / 1000), exp: Math.floor(now / 1000) + 300,
    aud: 'appstoreconnect-v1', bid: env.APPLE_BUNDLE_ID
  })}`;
  const signature = sign('sha256', Buffer.from(unsigned), { key: createPrivateKey(env.APPLE_PRIVATE_KEY), dsaEncoding: 'ieee-p1363' });
  return `${unsigned}.${signature.toString('base64url')}`;
}

async function equal(a, b) {
  const hashes = await Promise.all([a, b].map(value => crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))));
  return new Uint8Array(hashes[0]).every((byte, index) => byte === new Uint8Array(hashes[1])[index]);
}

/** Stores counters and job IDs only. Photo bytes and replay results exist only in memory. */
export class TryOnUsage {
  constructor(ctx, env, generate = generateTryOn) {
    this.ctx = ctx; this.env = env; this.generate = generate;
    this.jobs = new Map();
  }
  async fetch(request) {
    try {
      const entitlement = JSON.parse(request.headers.get('X-Pyxis-Entitlement'));
      const path = new URL(request.url).pathname;
      if (path === '/v1/try-on/usage' && request.method === 'GET') return json(await this.status(entitlement));
      if (path !== '/v1/try-on/generate' || request.method !== 'POST') throw new PublicError(404, 'Not found.');
      if (request.headers.get('X-Pyxis-Consent') !== CONSENT_VERSION) throw new PublicError(403, 'Please agree to photo processing before generating.');
      const job = request.headers.get('Idempotency-Key');
      if (!/^[0-9a-f-]{36}$/i.test(job || '')) throw new PublicError(400, 'A valid generation ID is required.');
      // Read/validate before reserving. No image content is persisted.
      const type = request.headers.get('Content-Type') || '';
      if (!type.startsWith('multipart/form-data;')) throw new PublicError(415, 'Upload must use multipart form data.');
      const bytes = await readBoundedBody(request.body, 32 * 1024 * 1024, new PublicError(413, 'The selected photos are too large.'));
      const form = await new Response(bytes, { headers: { 'Content-Type': type } }).formData();
      const key = `${entitlement.period}:${job}`;
      if (this.jobs.has(key)) return await this.render(await this.jobs.get(key), entitlement);
      // Reserve atomically before yielding to provider work. One active generation per subscriber.
      await this.ctx.storage.transaction(async txn => {
        const ledger = await txn.get('ledger') || { period: entitlement.period, used: 0, completed: [] };
        if (ledger.period !== entitlement.period) {
          if (Number(ledger.period) > Number(entitlement.period)) throw new PublicError(409, 'Refresh your subscription status.');
          Object.assign(ledger, { period: entitlement.period, used: 0, completed: [], pending: null });
        }
        if (ledger.completed.includes(job)) throw new PublicError(409, 'This preview finished but is no longer available to recover. Starting another uses one more try-on.', 'already_generated');
        if (ledger.pending && Date.now() - ledger.pending.started < 10 * 60_000) throw new PublicError(409, 'A try-on is already processing. Please wait.');
        if (ledger.used >= entitlement.limit) throw new PublicError(429, 'You have used this month’s try-ons. Saved previews are still available.');
        ledger.pending = { job, started: Date.now() };
        await txn.put('ledger', ledger);
        await txn.setAlarm(entitlement.renewsAt + 35 * day);
      });
      const operation = this.run(form, entitlement, job);
      this.jobs.set(key, operation);
      // waitUntil keeps bookkeeping alive if the client disconnects. Never retries provider work automatically.
      this.ctx.waitUntil(operation.then(() => {}, () => {}));
      try { return await this.render(await operation, entitlement); }
      catch (error) {
        // A terminal, refunded failure may be retried immediately with the same job ID.
        this.jobs.delete(key);
        throw error;
      } finally {
        const timer = setTimeout(() => { if (this.jobs.get(key) === operation) this.jobs.delete(key); }, 60_000);
        timer.unref?.();
      }
    } catch (error) {
      return json({ error: error instanceof PublicError ? error.message : 'Try-on could not finish. Please try again.',
        code: error instanceof PublicError ? error.code : undefined }, error.status || 502);
    }
  }
  async run(form, entitlement, job) {
    try {
      const result = await this.generate(form, this.env);
      await this.ctx.storage.transaction(async txn => {
        const ledger = await txn.get('ledger');
        if (ledger?.period !== entitlement.period || ledger.pending?.job !== job) throw new PublicError(409, 'This generation expired.');
        ledger.used += 1; ledger.completed.push(job); ledger.pending = null;
        await txn.put('ledger', ledger);
      });
      return result;
    } catch (error) {
      await this.ctx.storage.transaction(async txn => {
        const ledger = await txn.get('ledger');
        if (ledger?.period === entitlement.period && ledger.pending?.job === job) {
          ledger.pending = null; await txn.put('ledger', ledger);
        }
      });
      throw error;
    }
  }
  async status(entitlement) {
    const ledger = await this.ctx.storage.get('ledger');
    const used = ledger?.period === entitlement.period ? ledger.used : 0;
    return { limit: entitlement.limit, remaining: Math.max(0, entitlement.limit - used), renewsAt: entitlement.renewsAt };
  }
  async render(result, entitlement) {
    const usage = await this.status(entitlement);
    return new Response(result.bytes, { headers: { 'Content-Type': result.type, 'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff', 'X-Pyxis-Remaining': String(usage.remaining),
      'X-Pyxis-Limit': String(usage.limit), 'X-Pyxis-Renews-At': String(usage.renewsAt) } });
  }
  async alarm() { await this.ctx.storage.deleteAll(); this.jobs.clear(); }
}
