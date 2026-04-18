const DEFAULT_SECURITY_HEADERS = {
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "referrer-policy": "no-referrer",
  "x-xss-protection": "0",
};

// ── Rate limiting (R5) ─────────────────────────────────────────────────────
// Paths that receive the STRICT limiter (15/min/IP). Everything else goes
// through the DEFAULT limiter (120/min/IP). WebSocket upgrades and health
// checks bypass both — sockets are long-lived and /health is low-volume.
const STRICT_PATHS = [
  "/api/v1/party",           // POST create-room + invite lookup (prefix match)
  "/api/v1/auth/login",
  "/api/v1/auth/register",
  "/api/v1/auth/passkey",    // passkey flow (register/login challenges)
];

// User-Agents we reject outright (common scanners / benchmark tools).
const UA_BLOCKLIST = [
  "masscan", "nmap", "zgrab", "nikto", "sqlmap",
  "wpscan", "hydra", "curl/7.0", "libwww-perl",
];

/** True when the request path matches any strict prefix. */
function isStrictPath(pathname) {
  return STRICT_PATHS.some((p) => pathname === p || pathname.startsWith(p + "/"));
}

/**
 * Apply the correct rate limiter for this request. Returns the 429
 * response when blocked, or null when the request is allowed.
 */
async function enforceRateLimit(env, request, url) {
  // Exempt the keepalive cron path and all non-API traffic. `/health`
  // is hit by the scheduled worker and must never 429.
  if (url.pathname === "/health") return null;

  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const limiter = isStrictPath(url.pathname) ? env.RL_STRICT : env.RL_DEFAULT;
  if (!limiter) return null; // binding missing in dev — fail open.

  const { success } = await limiter.limit({ key: ip });
  if (success) return null;

  return new Response(
    JSON.stringify({ error: "rate_limited", retryAfterSec: 60 }),
    {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": "60",
        ...DEFAULT_SECURITY_HEADERS,
      },
    },
  );
}

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

    // ── Abuse gating (R5) ──────────────────────────────────────────────
    // Order matters: cheap UA check first, then the rate limiter (it
    // performs an external RPC). WebSocket upgrades skip the limiter —
    // sockets live for hours and only cost 1 request at upgrade time.
    const upgradeHeader = request.headers.get("Upgrade") || "";
    const isWsUpgrade = upgradeHeader.toLowerCase() === "websocket";

    if (!isWsUpgrade) {
      const ua = (request.headers.get("User-Agent") ?? "").toLowerCase();
      if (ua && UA_BLOCKLIST.some((needle) => ua.includes(needle))) {
        return new Response("Blocked", {
          status: 403,
          headers: { ...DEFAULT_SECURITY_HEADERS },
        });
      }

      const limited = await enforceRateLimit(env, request, url);
      if (limited) return limited;
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
    if (isWsUpgrade) {
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
