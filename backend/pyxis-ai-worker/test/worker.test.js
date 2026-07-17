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

test("garment cleanup sends one xAI edit and streams the result", async () => {
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

test("try-on applies more than two garments in sequential xAI batches", async () => {
  let editCount = 0;
  const fetchMock = async (input, init) => {
    if (String(input).includes("/images/edits")) {
      editCount += 1;
      const body = JSON.parse(init.body);
      assert.equal(body.images.length, editCount === 1 ? 3 : 2);
      return Response.json({ data: [{ url: `https://imgen.x.ai/result-${editCount}.jpeg` }] });
    }
    return new Response(JPEG, { headers: { "Content-Type": "image/jpeg" } });
  };

  const response = await handleRequest(
    request("/v1/ai/virtual-try-on", [
      ["person", JPEG],
      ["garment_1", JPEG],
      ["garment_2", JPEG],
      ["garment_3", JPEG]
    ]),
    environment(),
    fetchMock
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("X-Pyxis-AI-Calls"), "2");
  assert.equal(editCount, 2);
});

test("fails closed when rate limiting is missing", async () => {
  const response = await handleRequest(
    request("/v1/ai/garment-cleanup", [["source", JPEG]]),
    environment({ AI_RATE_LIMITER: undefined })
  );
  assert.equal(response.status, 503);
});

test("rejects duplicate or non-sequential garment fields", async () => {
  const response = await handleRequest(
    request("/v1/ai/virtual-try-on", [
      ["person", JPEG],
      ["garment_1", JPEG],
      ["garment_1", JPEG]
    ]),
    environment(),
    () => assert.fail("provider must not be called")
  );
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "Garment fields must be sequential and unique." });
});
