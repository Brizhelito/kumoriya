const DEFAULT_SECURITY_HEADERS = {
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "referrer-policy": "no-referrer",
  "x-xss-protection": "0",
};

// Headers that leak origin identity — strip them from every response.
const HEADERS_TO_STRIP = [
  "server",
  "x-compute-host",
  "x-compute-type",
  "x-request-id",
  "x-powered-by",
  "x-proxied-host",
  "x-proxied-path",
  "x-proxied-replica",
  "link",
  "via",
];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol !== "https:") {
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }

    const origin = env.ORIGIN_BASE_URL;
    if (!origin) {
      return new Response("ORIGIN_BASE_URL is not configured", { status: 500 });
    }

    const target = new URL(url.pathname + url.search, origin);
    const upstreamHeaders = new Headers(request.headers);

    const realIp = request.headers.get("CF-Connecting-IP");
    if (realIp) {
      upstreamHeaders.set("CF-Connecting-IP", realIp);
    }
    upstreamHeaders.set("X-Forwarded-Host", url.host);
    upstreamHeaders.set("X-Forwarded-Proto", "https");

    // ── WebSocket upgrade: proxy using Cloudflare's WebSocket API ──
    const upgradeHeader = request.headers.get("Upgrade") || "";
    if (upgradeHeader.toLowerCase() === "websocket") {
      const upstreamReq = new Request(target.toString(), {
        method: request.method,
        headers: upstreamHeaders,
      });
      return fetch(upstreamReq);
    }

    const upstreamReq = new Request(target.toString(), {
      method: request.method,
      headers: upstreamHeaders,
      body: request.body,
      redirect: "manual",
    });

    const upstreamRes = await fetch(upstreamReq);
    const responseHeaders = new Headers(upstreamRes.headers);

    // Scrub any header that reveals the upstream origin.
    for (const h of HEADERS_TO_STRIP) {
      responseHeaders.delete(h);
    }
    // Also strip any header prefixed with x-hf- (Hugging Face internals).
    for (const [key] of responseHeaders) {
      if (key.startsWith("x-hf-")) {
        responseHeaders.delete(key);
      }
    }

    responseHeaders.set("server", "kumoriya");
    responseHeaders.set("x-kumoriya-edge", "worker");
    for (const [k, v] of Object.entries(DEFAULT_SECURITY_HEADERS)) {
      responseHeaders.set(k, v);
    }

    return new Response(upstreamRes.body, {
      status: upstreamRes.status,
      headers: responseHeaders,
    });
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(pingHealth(env));
  },
};

async function pingHealth(env) {
  const origin = env.ORIGIN_BASE_URL;
  if (!origin) {
    return;
  }

  const healthUrl = new URL("/health", origin).toString();
  await fetch(healthUrl, {
    method: "GET",
    headers: {
      "user-agent": "kumoriya-keepalive-cron/1.0",
    },
  });
}
