// Raffronto on Cloudflare: the static app (public/, copied from the project root) plus the share-by-link API.
// The browser encrypts the two documents and the view state before uploading them; the key lives only
// in the link fragment (#s=<id>.<key>), which browsers never send to the server. Here we only see ciphertext.
//
// POST /api/share            raw body (application/octet-stream) -> 201 {"id": "...", "expires": <unix>}
// GET  /api/share?id=<id>    -> the stored bytes, header X-Expires: <unix>
//
// Blobs live in R2 under blobs/<id> with their expiry in the custom metadata; an R2 lifecycle rule deletes
// them after 7 days (no cron). Rate counters live under rate/<sha256 of the address>.

interface Env {
	SHARES: R2Bucket;
	ASSETS: Fetcher;
}

const TTL = 7 * 86400;
const MAX_FILE = 10_000_000; // per document (checked by the browser, which knows the sizes)
const MAX_BODY = 2 * MAX_FILE + 65_536; // two documents + view state + encryption overhead
const MAX_STORAGE = 2_000_000_000; // all shares together
const RATE_MAX = 20; // new links per address...
const RATE_WINDOW = 3600; // ...per hour

const BASE_HEADERS = {
	"Cache-Control": "no-store",
	"X-Content-Type-Options": "nosniff",
	"X-Robots-Tag": "noindex",
	"Referrer-Policy": "no-referrer",
	// only ciphertext travels here, so any page (the desktop app too) may use it
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Expose-Headers": "X-Expires",
};

const now = () => Math.floor(Date.now() / 1000);

function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { ...BASE_HEADERS, "Content-Type": "application/json; charset=utf-8", ...headers },
	});
}

const fail = (status: number, error: string, headers: Record<string, string> = {}) => json(status, { error }, headers);

const hex = (bytes: ArrayBuffer | Uint8Array) =>
	[...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");

// the body, never more than MAX_BODY + 1 bytes
async function readCapped(body: ReadableStream<Uint8Array> | null): Promise<Uint8Array> {
	if (!body) return new Uint8Array();
	const chunks: Uint8Array[] = [];
	let size = 0;
	const reader = body.getReader();
	for (;;) {
		const { done, value } = await reader.read();
		if (done) break;
		chunks.push(value);
		size += value.byteLength;
		if (size > MAX_BODY) {
			await reader.cancel();
			break;
		}
	}
	const out = new Uint8Array(size);
	let at = 0;
	for (const c of chunks) {
		out.set(c, at);
		at += c.byteLength;
	}
	return out;
}

// true when this address may create another link; counts the attempt
async function allowed(env: Env, ip: string): Promise<boolean> {
	const key = "rate/" + hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode("raffronto|" + ip)));
	const t = now();
	const stored = await env.SHARES.get(key);
	const hits = ((stored ? await stored.json<unknown[]>().catch(() => []) : []) as unknown[]).filter(
		(h): h is number => typeof h === "number" && h > t - RATE_WINDOW,
	);
	const ok = hits.length < RATE_MAX;
	if (ok) hits.push(t);
	await env.SHARES.put(key, JSON.stringify(hits));
	return ok;
}

// bytes held by links that have not expired yet
async function used(env: Env): Promise<number> {
	let total = 0;
	let cursor: string | undefined;
	const t = now();
	do {
		const page = await env.SHARES.list({ prefix: "blobs/", cursor, include: ["customMetadata"] });
		for (const o of page.objects) if (Number(o.customMetadata?.expires) > t) total += o.size;
		cursor = page.truncated ? page.cursor : undefined;
	} while (cursor);
	return total;
}

async function share(req: Request, env: Env): Promise<Response> {
	const url = new URL(req.url);
	if (req.method === "OPTIONS") {
		return new Response(null, {
			status: 204,
			headers: {
				...BASE_HEADERS,
				"Access-Control-Allow-Methods": "GET, POST",
				"Access-Control-Allow-Headers": "Content-Type",
				"Access-Control-Max-Age": "86400",
			},
		});
	}

	if (req.method === "GET") {
		const id = url.searchParams.get("id");
		if (!id || !/^[0-9a-f]{32}$/.test(id)) return fail(400, "invalid id");
		const obj = await env.SHARES.get("blobs/" + id);
		if (!obj) return fail(404, "not found");
		const expires = Number(obj.customMetadata?.expires);
		if (!(expires > now())) return fail(410, "expired");
		return new Response(obj.body, {
			headers: {
				...BASE_HEADERS,
				"Content-Type": "application/octet-stream",
				"Content-Length": String(obj.size),
				"X-Expires": String(expires),
			},
		});
	}

	if (req.method !== "POST") return fail(405, "method not allowed", { Allow: "GET, POST" });
	const type = (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase();
	if (type !== "application/octet-stream") return fail(415, "expected application/octet-stream");
	const length = Number(req.headers.get("Content-Length") ?? -1);
	if (length > MAX_BODY) return fail(413, "too large");
	if (length === 0) return fail(400, "empty body");
	if (!(await allowed(env, req.headers.get("CF-Connecting-IP") ?? ""))) {
		return fail(429, "too many links, try again later", { "Retry-After": String(RATE_WINDOW) });
	}
	const body = await readCapped(req.body);
	if (body.byteLength > MAX_BODY) return fail(413, "too large");
	if (body.byteLength === 0) return fail(400, "empty body");
	if ((await used(env)) + body.byteLength > MAX_STORAGE) return fail(507, "storage full");

	const id = hex(crypto.getRandomValues(new Uint8Array(16)));
	const expires = now() + TTL;
	await env.SHARES.put("blobs/" + id, body, {
		httpMetadata: { contentType: "application/octet-stream" },
		customMetadata: { expires: String(expires) },
	});
	return json(201, { id, expires });
}

export default {
	async fetch(req, env) {
		if (new URL(req.url).pathname === "/api/share") return share(req, env);
		return fail(404, "not found");
	},
} satisfies ExportedHandler<Env>;
