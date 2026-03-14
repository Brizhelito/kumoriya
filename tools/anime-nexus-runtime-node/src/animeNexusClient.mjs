import crypto from "node:crypto";

export const NEXUS = {
  mainBase: "https://anime.nexus",
  apiBase: "https://api.anime.nexus",
  cdnBase: "https://video-cdn.anime.nexus",
  userAgent:
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
};

const DEFAULT_HTTP_TIMEOUT_MS = parseTimeout(
  process.env.ANIME_NEXUS_HTTP_TIMEOUT_MS,
  15000,
);
const DEFAULT_CDN_TIMEOUT_MS = parseTimeout(
  process.env.ANIME_NEXUS_CDN_TIMEOUT_MS,
  30000,
);

function randomHex(bytes) {
  return crypto.randomBytes(bytes).toString("hex");
}

function parseTimeout(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function composeAbortSignal(signal, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  timer.unref?.();

  if (signal) {
    if (signal.aborted) {
      controller.abort(signal.reason);
    } else {
      signal.addEventListener("abort", () => controller.abort(signal.reason), {
        once: true,
      });
    }
  }

  return {
    signal: controller.signal,
    dispose() {
      clearTimeout(timer);
    },
  };
}

async function fetchWithTimeout(url, init = {}, options = {}) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const timeoutMs = parseTimeout(options.timeoutMs, DEFAULT_HTTP_TIMEOUT_MS);
  const { signal, dispose } = composeAbortSignal(init.signal, timeoutMs);

  try {
    return await fetchImpl(url, { ...init, signal });
  } catch (error) {
    if (signal.aborted && !init.signal?.aborted) {
      throw new Error(
        `Anime Nexus request timed out after ${timeoutMs}ms: ${url}`,
      );
    }
    throw error;
  } finally {
    dispose();
  }
}

export function createBrowserSession() {
  return {
    fingerprint: crypto.randomUUID(),
    cookieHeader: `sid=${randomHex(16)}`,
  };
}

export function mergeCookieHeaders(...headers) {
  const cookies = new Map();
  for (const header of headers.flat()) {
    if (!header) continue;
    const values = Array.isArray(header) ? header : [header];
    for (const value of values) {
      const parts = String(value).split(/;\s*/);
      const first = parts[0]?.trim();
      if (!first) continue;
      const separator = first.indexOf("=");
      if (separator <= 0) continue;
      cookies.set(first.slice(0, separator), first.slice(separator + 1));
    }
  }
  if (cookies.size === 0) return null;
  return [...cookies.entries()]
    .map(([key, value]) => `${key}=${value}`)
    .join("; ");
}

function getSetCookie(headers) {
  if (typeof headers.getSetCookie === "function") {
    return headers.getSetCookie();
  }
  const single = headers.get("set-cookie");
  return single ? [single] : [];
}

function browserFetchHeaders(nexus = NEXUS) {
  return {
    "User-Agent": nexus.userAgent,
    Accept: "*/*",
    "Accept-Language": "es-419,es;q=0.9,en;q=0.8",
    Origin: nexus.mainBase,
    Referer: `${nexus.mainBase}/`,
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "cross-site",
  };
}

export async function scrapeWatchPage(watchUrl, session, options = {}) {
  const nexus = options.nexus ?? NEXUS;
  const response = await fetchWithTimeout(
    watchUrl,
    {
      headers: {
        ...browserFetchHeaders(nexus),
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "sec-fetch-dest": "document",
        "sec-fetch-mode": "navigate",
        "sec-fetch-site": "none",
        Cookie: session.cookieHeader,
      },
    },
    options,
  );
  const html = (await response.text()).trim();
  if (!html) {
    throw new Error("Anime Nexus watch page returned empty HTML.");
  }
  const attestRef = /attestRef:\"([0-9a-f]{64})\"/i.exec(html)?.[1] ?? null;
  if (!attestRef) {
    throw new Error("Anime Nexus watch page did not expose attestRef.");
  }
  const url = new URL(watchUrl);
  const segments = url.pathname.split("/").filter(Boolean);
  const watchIndex = segments.indexOf("watch");
  const episodeId = watchIndex >= 0 ? segments[watchIndex + 1] : null;
  if (!episodeId) {
    throw new Error("Anime Nexus watch url did not expose an episode id.");
  }
  return {
    episodeId,
    attestRef,
    cookieHeader: mergeCookieHeaders(
      session.cookieHeader,
      getSetCookie(response.headers),
    ),
  };
}

async function bootstrapAuthSession(cookieHeader, options = {}) {
  const nexus = options.nexus ?? NEXUS;
  const response = await fetchWithTimeout(
    `${nexus.mainBase}/api/auth/session`,
    {
      headers: {
        ...browserFetchHeaders(nexus),
        Accept: "application/json, text/plain, */*",
        "sec-fetch-site": "same-origin",
        Cookie: cookieHeader,
      },
    },
    options,
  );
  return getSetCookie(response.headers);
}

async function bootstrapEpisodeView(
  { episodeId, cookieHeader, fingerprint },
  options = {},
) {
  const nexus = options.nexus ?? NEXUS;
  const response = await fetchWithTimeout(
    `${nexus.apiBase}/api/anime/details/episode/view`,
    {
      method: "POST",
      headers: {
        ...browserFetchHeaders(nexus),
        Accept: "application/json, text/plain, */*",
        "Content-Type": "application/json",
        "sec-fetch-site": "same-site",
        "x-client-fingerprint": fingerprint,
        "x-fingerprint": fingerprint,
        Cookie: cookieHeader,
      },
      body: JSON.stringify({ id: episodeId }),
    },
    options,
  );
  return getSetCookie(response.headers);
}

function extractVideoId(data, hlsUrl) {
  const nested = [data?.video?.id, data?.video_meta?.id].find(
    (value) => typeof value === "string" && value.trim(),
  );
  if (nested) return nested.trim();
  const url = new URL(hlsUrl);
  const parts = url.pathname.split("/").filter(Boolean);
  const videoIndex = parts.indexOf("video");
  if (videoIndex >= 0 && parts[videoIndex + 1]) {
    return parts[videoIndex + 1];
  }
  return "";
}

export async function fetchStreamData({ episodeId, session }, options = {}) {
  const nexus = options.nexus ?? NEXUS;
  let cookieHeader = session.cookieHeader;
  cookieHeader = mergeCookieHeaders(
    cookieHeader,
    await bootstrapAuthSession(cookieHeader, options),
  );
  cookieHeader = mergeCookieHeaders(
    cookieHeader,
    await bootstrapEpisodeView(
      { episodeId, cookieHeader, fingerprint: session.fingerprint },
      options,
    ),
  );

  const makeRequest = (cookies) =>
    fetchWithTimeout(
      `${nexus.apiBase}/api/anime/details/episode/stream?id=${encodeURIComponent(episodeId)}&fillers=true&recaps=true`,
      {
        headers: {
          ...browserFetchHeaders(nexus),
          Accept: "application/json, text/plain, */*",
          "sec-fetch-site": "same-site",
          "x-client-fingerprint": session.fingerprint,
          "x-fingerprint": session.fingerprint,
          Cookie: cookies,
        },
      },
      options,
    );

  let response = await makeRequest(cookieHeader);
  if (response.status === 403) {
    cookieHeader = mergeCookieHeaders(
      cookieHeader,
      getSetCookie(response.headers),
    );
    response = await makeRequest(cookieHeader);
  }
  if (response.status !== 200) {
    throw new Error(
      `Anime Nexus stream metadata responded with status ${response.status}.`,
    );
  }
  const payload = await response.json();
  const data = payload?.data;
  const hls = data?.hls?.trim?.() ?? "";
  if (!hls) {
    throw new Error(
      "Anime Nexus stream metadata did not expose a valid HLS url.",
    );
  }
  return {
    hlsUrl: new URL(hls),
    videoId: extractVideoId(data, hls),
    cookieHeader: mergeCookieHeaders(
      cookieHeader,
      getSetCookie(response.headers),
    ),
  };
}

export async function fetchCandidateHosts(fallbackHost, options = {}) {
  const edgesUrl = options.edgesUrl ?? "https://us1.cdn.nexus/api/edges";
  try {
    const response = await fetchWithTimeout(
      edgesUrl,
      {
        headers: browserFetchHeaders(options.nexus ?? NEXUS),
      },
      options,
    );
    if (!response.ok) {
      return [fallbackHost];
    }
    const payload = await response.json();
    const hosts = new Set([fallbackHost]);
    for (const entry of payload?.edges ?? []) {
      const host = String(entry?.host ?? "").trim();
      if (host) hosts.add(host);
    }
    return [...hosts];
  } catch {
    return [fallbackHost];
  }
}

export function cdnRequestHeaders(
  { fingerprint, sessionId, videoUuid },
  options = {},
) {
  return {
    ...browserFetchHeaders(options.nexus ?? NEXUS),
    "x-client-fingerprint": fingerprint,
    "x-fingerprint": fingerprint,
    "x-session-id": sessionId,
    "x-video-uuid": videoUuid,
  };
}

export async function fetchText(url, headers, options = {}) {
  const response = await fetchWithTimeout(
    url,
    { headers },
    {
      ...options,
      timeoutMs: parseTimeout(options.timeoutMs, DEFAULT_CDN_TIMEOUT_MS),
    },
  );
  return {
    status: response.status,
    url: response.url,
    text: await response.text(),
    headers: response.headers,
  };
}

export async function fetchBytes(url, headers, options = {}) {
  const response = await fetchWithTimeout(
    url,
    { headers },
    {
      ...options,
      timeoutMs: parseTimeout(options.timeoutMs, DEFAULT_CDN_TIMEOUT_MS),
    },
  );
  return {
    status: response.status,
    url: response.url,
    body: Buffer.from(await response.arrayBuffer()),
    headers: response.headers,
  };
}
