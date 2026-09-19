import assert from "node:assert/strict";
import test from "node:test";
import { handleRequest } from "../src/index.js";

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43, 0x00, 0xff, 0xd9]);

function environment(overrides = {}) {
  return {
    XAI_API_KEY: "xai-test-key",
    PYXIS_ACCESS_TOKEN: "client-test-token",
    XAI_MODEL: "grok-imagine-image-quality",
    AI_RATE_LIMITER: { limit: async () => ({ success: true }) },
    ...overrides
  };
}

function request(path, fields, token = "client-test-token") {
  const form = new FormData();
  for (const [name, value] of fields) {
    form.append(name, new Blob([value], { type: "image/jpeg" }), `${name}.jpg`);
  }
  return new Request(`https://ai.pyxis.example${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "CF-Connecting-IP": "192.0.2.1" },
    body: form
  });
}

test("health check does not expose configuration", async () => {
  const response = await handleRequest(new Request("https://ai.pyxis.example/health"), {});
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok", provider: "xai" });
});

test("rejects missing client authorization before provider work", async () => {
  const response = await handleRequest(
    request("/v1/ai/garment-cleanup", [["source", JPEG]], "wrong-token"),
    environment(),
    () => assert.fail("provider must not be called")
  );
  assert.equal(response.status, 401);
});

test("garment cleanup sends one xAI edit and returns the validated result", async () => {
  const calls = [];
  const fetchMock = async (input, init) => {
    calls.push({ input: String(input), init });
    if (String(input).includes("/images/edits")) {
      const body = JSON.parse(init.body);
      assert.equal(body.model, "grok-imagine-image-quality");
      assert.match(body.image.url, /^data:image\/jpeg;base64,/);
      return Response.json({ data: [{ url: "https://imgen.x.ai/result.jpeg" }] });
    }
    return new Response(JPEG, { headers: { "Content-Type": "image/jpeg" } });
  };

  const response = await handleRequest(
    request("/v1/ai/garment-cleanup", [["source", JPEG]]),
    environment(),
    fetchMock
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(response.headers.get("X-Pyxis-AI-Calls"), "1");
  assert.equal(calls.length, 2);
});



test("fails closed when rate limiting is missing", async () => {
  const response = await handleRequest(
    request("/v1/ai/garment-cleanup", [["source", JPEG]]),
    environment({ AI_RATE_LIMITER: undefined })
  );
  assert.equal(response.status, 503);
});



const neverFetch = () => assert.fail("provider must not be called");
const cleanupRequest = () => request("/v1/ai/garment-cleanup", [["source", JPEG]]);
const inlineResult = () => Response.json({ data: [{ b64_json: Buffer.from(JPEG).toString("base64") }] });

function oversizedBody() {
  const state = { pulls: 0, cancelled: false };
  state.stream = new ReadableStream({
    pull(controller) {
      if (state.pulls === 40) { controller.close(); return; }
      state.pulls++; controller.enqueue(new Uint8Array(1024 * 1024));
    },
    cancel() { state.cancelled = true; }
  });
  return state;
}

for (const length of [undefined, "1"]) {
  test(`bounds actual upload bytes with Content-Length ${length}`, async () => {
    const body = oversizedBody();
    const headers = { Authorization: "Bearer client-test-token", "Content-Type": "multipart/form-data; boundary=test" };
    if (length) headers["Content-Length"] = length;
    const upload = new Request("https://ai.pyxis.example/v1/ai/garment-cleanup", {
      method: "POST", headers, body: body.stream, duplex: "half"
    });
    const response = await handleRequest(upload, environment(), neverFetch);
    assert.equal(response.status, 413);
    assert.ok(body.cancelled);
    assert.ok(body.pulls <= 34, "must stop consuming at the bound");
  });
}

test("rejects invalid lengths and MIME prefixes before reading the body", async () => {
  for (const value of ["-1", "NaN", "1.5", "9007199254740993", String(33 * 1024 * 1024)]) {
    const upload = cleanupRequest();
    upload.headers.set("Content-Length", value);
    const response = await handleRequest(upload, environment(), neverFetch);
    assert.equal(response.status, value === String(33 * 1024 * 1024) ? 413 : 400);
  }
  const upload = cleanupRequest();
  upload.headers.set("Content-Type", "multipart/form-data-spoof; boundary=test");
  assert.equal((await handleRequest(upload, environment(), neverFetch)).status, 415);
});

test("rejects unexpected fields, duplicates, missing images, oversized and spoofed files", async () => {
  for (const [fields, status] of [
    [[["source", JPEG], ["extra", JPEG]], 400],
    [[["source", JPEG], ["source", JPEG]], 400],
    [[], 400],
    [[["source", new Uint8Array(4 * 1024 * 1024 + 1)]], 413],
    [[["source", new Uint8Array()]], 413],
    [[["source", new TextEncoder().encode("fake JPEG")]], 415]
  ]) {
    assert.equal((await handleRequest(request("/v1/ai/garment-cleanup", fields), environment(), neverFetch)).status, status);
  }
});

test("requires the full PNG signature", async () => {
  const form = new FormData();
  form.append("source", new Blob([new Uint8Array([0x89, 0x50, 0x4e, 0x47])], { type: "image/png" }), "photo.png");
  const upload = new Request("https://ai.pyxis.example/v1/ai/garment-cleanup", {
    method: "POST", headers: { Authorization: "Bearer client-test-token" }, body: form
  });
  assert.equal((await handleRequest(upload, environment(), neverFetch)).status, 415);
});



test("rejects provider and download redirects without forwarding photos or credentials", async () => {
  for (const redirectAt of [1, 2]) {
    let calls = 0;
    const response = await handleRequest(cleanupRequest(), environment(), async (url, init) => {
      calls++;
      assert.equal(init.redirect, "error");
      assert.ok(init.signal instanceof AbortSignal);
      if (calls === redirectAt) {
        return new Response(null, { status: 307, headers: { Location: "https://evil.example/collect" } });
      }
      return Response.json({ data: [{ url: "https://imgen.x.ai/result.jpeg" }] });
    });
    assert.equal(response.status, 502);
    assert.equal(calls, redirectAt);
  }
});



test("bounds provider JSON and downloaded image streams without Content-Length", async () => {
  for (const oversizedAt of [1, 2]) {
    const body = oversizedBody();
    let calls = 0;
    const response = await handleRequest(cleanupRequest(), environment(), async () => {
      calls++;
      if (calls === oversizedAt) return new Response(body.stream, { headers: { "Content-Type": "image/jpeg" } });
      return Response.json({ data: [{ url: "https://imgen.x.ai/result.jpg" }] });
    });
    assert.equal(response.status, 502);
    assert.ok(body.cancelled);
    assert.ok(body.pulls <= (oversizedAt === 1 ? 30 : 22));
  }
});

test("rejects malformed JSON, base64, and generated image signatures", async () => {
  for (const providerResponse of [
    () => new Response("not JSON"),
    () => Response.json({ data: [{ b64_json: "%%%" }] }),
    () => Response.json({ data: [{ b64_json: btoa("not JPEG") }] }),
    () => Response.json({ data: [] })
  ]) {
    const response = await handleRequest(cleanupRequest(), environment(), providerResponse);
    assert.equal(response.status, 502);
  }
  let calls = 0;
  const response = await handleRequest(cleanupRequest(), environment(), async () => ++calls === 1
    ? Response.json({ data: [{ url: "https://imgen.x.ai/result.jpg" }] })
    : new Response("not JPEG", { headers: { "Content-Type": "image/jpeg" } }));
  assert.equal(response.status, 502);
});

test("preserves inline image results and generic errors without leaking secrets", async () => {
  const response = await handleRequest(cleanupRequest(), environment(), inlineResult);
  assert.equal(response.status, 200);
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), JPEG);
  const failure = await handleRequest(cleanupRequest(), environment(), () => { throw new Error("sensitive-provider-detail"); });
  assert.equal(failure.status, 502);
  assert.deepEqual(await failure.json(), { error: "AI generation failed. Try again." });
});

test("authorization and rate limits protect garment cleanup", async () => {
  for (const path of ["/v1/ai/garment-cleanup"]) {
    for (const [env, token, status] of [
      [environment(), "", 401],
      [environment({ XAI_API_KEY: undefined }), "client-test-token", 503],
      [environment({ AI_RATE_LIMITER: { limit: async () => ({ success: false }) } }), "client-test-token", 429]
    ]) {
      const response = await handleRequest(request(path, [], token), env, neverFetch);
      assert.equal(response.status, status);
      assert.equal(response.headers.get("Cache-Control"), "no-store");
      assert.equal(response.headers.get("X-Content-Type-Options"), "nosniff");
      assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
    }
  }
});

test("legacy try-on cannot bypass purchase, consent or quota checks", async () => {
  assert.equal((await handleRequest(request('/v1/ai/virtual-try-on', [['person', JPEG]]), environment(), neverFetch)).status, 410);
});
