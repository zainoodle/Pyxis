const XAI_EDIT_URL = "https://api.x.ai/v1/images/edits";
const MAX_REQUEST_BYTES = 32 * 1024 * 1024;
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const MAX_GARMENTS = 6;
const SUPPORTED_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

const CLEANUP_PROMPT = [
  "Edit presentation only.",
  "Preserve the exact garment identity, silhouette, proportions, color, material, seams, hardware, print, logo, and distressing.",
  "Remove wrinkles and photography or background artifacts.",
  "Add no new garment details.",
  "Center one garment on a plain neutral studio background."
].join(" ");

const FIRST_TRY_ON_PROMPT = [
  "The first source image is the person. The remaining source images are exact garment references.",
  "Keep the person's face, body, skin tone, hair, pose, and background unchanged.",
  "Dress them in the referenced garments while preserving garment colors, construction, patterns, logos, proportions, and intended layering.",
  "Do not reshape the person's body or imply actual size or fit.",
  "Return one photorealistic full-body catalog image."
].join(" ");

const CONTINUE_TRY_ON_PROMPT = [
  "The first source image is an existing try-on preview. The remaining source images are additional exact garments.",
  "Add the new garments to the existing outfit without removing or redesigning pieces already worn.",
  "Keep the person's face, body, skin tone, hair, pose, and background unchanged.",
  "Preserve all garment colors, construction, patterns, logos, proportions, and layering.",
  "Do not reshape the person's body or imply actual size or fit.",
  "Return one photorealistic full-body catalog image."
].join(" ");

class PublicError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export default {
  fetch(request, env) {
    return handleRequest(request, env, fetch);
  }
};

export async function handleRequest(request, env, fetchImpl = fetch) {
  try {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ status: "ok", provider: "xai" });
    }

    if (request.method !== "POST") {
      throw new PublicError(405, "Method not allowed.");
    }
    if (!["/v1/ai/garment-cleanup", "/v1/ai/virtual-try-on"].includes(url.pathname)) {
      throw new PublicError(404, "Route not found.");
    }

    await authorize(request, env);
    await applyRateLimit(request, env);
    validateRequestHeaders(request);

    let form;
    try {
      form = await request.formData();
    } catch {
      throw new PublicError(400, "The image upload could not be read.");
    }
    let output;
    let callCount;
    if (url.pathname === "/v1/ai/garment-cleanup") {
      const source = await readImage(form, "source");
      output = await editImages([source.dataURL], CLEANUP_PROMPT, env, fetchImpl);
      callCount = 1;
    } else {
      const person = await readImage(form, "person");
      const garments = await readGarments(form);
      if (garments.length === 0) {
        throw new PublicError(400, "Select at least one garment.");
      }

      output = person.dataURL;
      callCount = 0;
      for (let index = 0; index < garments.length; index += 2) {
        const batch = garments.slice(index, index + 2).map((image) => image.dataURL);
        output = await editImages(
          [output, ...batch],
          index === 0 ? FIRST_TRY_ON_PROMPT : CONTINUE_TRY_ON_PROMPT,
          env,
          fetchImpl
        );
        callCount += 1;
      }
    }

    const imageResponse = await fetchOutput(output, fetchImpl);
    const headers = new Headers(imageResponse.headers);
    headers.set("Cache-Control", "no-store");
    headers.set("X-Content-Type-Options", "nosniff");
    headers.set("X-Pyxis-AI-Calls", String(callCount));
    return new Response(imageResponse.body, { status: 200, headers });
  } catch (error) {
    if (error instanceof PublicError) {
      return json({ error: error.message }, error.status);
    }
    return json({ error: "AI generation failed. Try again." }, 502);
  }
}

async function authorize(request, env) {
  if (!env.XAI_API_KEY || !env.PYXIS_ACCESS_TOKEN) {
    throw new PublicError(503, "AI Studio is not configured.");
  }
  const header = request.headers.get("Authorization") || "";
  const supplied = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!supplied || !(await secureEqual(supplied, env.PYXIS_ACCESS_TOKEN))) {
    throw new PublicError(401, "AI Studio authorization failed.");
  }
}

async function secureEqual(left, right) {
  const encoder = new TextEncoder();
  const [leftHash, rightHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(left)),
    crypto.subtle.digest("SHA-256", encoder.encode(right))
  ]);
  const leftBytes = new Uint8Array(leftHash);
  const rightBytes = new Uint8Array(rightHash);
  let difference = 0;
  for (let index = 0; index < leftBytes.length; index += 1) {
    difference |= leftBytes[index] ^ rightBytes[index];
  }
  return difference === 0;
}

async function applyRateLimit(request, env) {
  if (!env.AI_RATE_LIMITER?.limit) {
    throw new PublicError(503, "AI Studio rate limiting is not configured.");
  }
  const address = request.headers.get("CF-Connecting-IP") || "unknown";
  const result = await env.AI_RATE_LIMITER.limit({ key: `ai:${address}` });
  if (!result.success) {
    throw new PublicError(429, "Generation limit reached. Try again shortly.");
  }
}

function validateRequestHeaders(request) {
  const type = request.headers.get("Content-Type") || "";
  if (!type.toLowerCase().startsWith("multipart/form-data")) {
    throw new PublicError(415, "Upload must use multipart form data.");
  }
  const length = Number(request.headers.get("Content-Length") || 0);
  if (Number.isFinite(length) && length > MAX_REQUEST_BYTES) {
    throw new PublicError(413, "The selected photos are too large.");
  }
}

async function readGarments(form) {
  const matches = [];
  for (const [name, value] of form.entries()) {
    const field = /^garment_(\d+)$/.exec(name);
    if (field) matches.push({ index: Number(field[1]), value });
  }
  matches.sort((left, right) => left.index - right.index);
  if (matches.length > MAX_GARMENTS) {
    throw new PublicError(400, `Select no more than ${MAX_GARMENTS} garments.`);
  }
  for (let index = 0; index < matches.length; index += 1) {
    if (matches[index].index !== index + 1) {
      throw new PublicError(400, "Garment fields must be sequential and unique.");
    }
  }
  return Promise.all(matches.map((match) => validateImage(match.value)));
}

async function readImage(form, name) {
  const values = form.getAll(name);
  if (values.length === 0) {
    throw new PublicError(400, `Missing ${name} image.`);
  }
  if (values.length !== 1) {
    throw new PublicError(400, `Upload exactly one ${name} image.`);
  }
  return validateImage(values[0]);
}

async function validateImage(value) {
  if (typeof value === "string" || typeof value.arrayBuffer !== "function") {
    throw new PublicError(400, "An uploaded image is invalid.");
  }
  if (!SUPPORTED_TYPES.has(value.type)) {
    throw new PublicError(415, "Use JPEG, PNG, or WebP photos.");
  }
  if (value.size <= 0 || value.size > MAX_IMAGE_BYTES) {
    throw new PublicError(413, "Each photo must be 4 MB or smaller.");
  }

  const bytes = new Uint8Array(await value.arrayBuffer());
  if (!matchesSignature(bytes, value.type)) {
    throw new PublicError(415, "An uploaded file is not a valid image.");
  }
  return { dataURL: `data:${value.type};base64,${toBase64(bytes)}` };
}

function matchesSignature(bytes, type) {
  if (type === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (type === "image/png") {
    return bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47;
  }
  return String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
}

function toBase64(bytes) {
  let binary = "";
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunkSize));
  }
  return btoa(binary);
}

async function editImages(images, prompt, env, fetchImpl) {
  const body = {
    model: env.XAI_MODEL || "grok-imagine-image-quality",
    prompt
  };
  if (images.length === 1) {
    body.image = { type: "image_url", url: images[0] };
  } else {
    body.images = images.map((url) => ({ type: "image_url", url }));
  }

  const response = await fetchImpl(XAI_EDIT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.XAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
  if (!response.ok) {
    throw new PublicError(502, "The image provider could not complete this generation.");
  }
  const payload = await response.json();
  const result = payload?.data?.[0];
  if (typeof result?.url === "string") return result.url;
  if (typeof result?.b64_json === "string") return `data:image/jpeg;base64,${result.b64_json}`;
  throw new PublicError(502, "The image provider returned no image.");
}

async function fetchOutput(value, fetchImpl) {
  if (value.startsWith("data:image/")) {
    const match = /^data:(image\/(?:jpeg|png|webp));base64,(.+)$/.exec(value);
    if (!match) throw new PublicError(502, "The generated image was unreadable.");
    return new Response(base64ToBytes(match[2]), { headers: { "Content-Type": match[1] } });
  }

  const url = new URL(value);
  if (url.protocol !== "https:" || !(url.hostname === "x.ai" || url.hostname.endsWith(".x.ai"))) {
    throw new PublicError(502, "The image provider returned an invalid location.");
  }
  const response = await fetchImpl(url);
  const type = response.headers.get("Content-Type")?.split(";", 1)[0] || "";
  if (!response.ok || !SUPPORTED_TYPES.has(type)) {
    throw new PublicError(502, "The generated image could not be downloaded.");
  }
  return response;
}

function base64ToBytes(value) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff"
    }
  });
}
