import http from "node:http";
import crypto from "node:crypto";
import { parseMasterManifest } from "./hlsParser.mjs";
import {
  cdnRequestHeaders,
  createBrowserSession,
  fetchBytes,
  fetchCandidateHosts,
  fetchStreamData,
  fetchText,
  mergeCookieHeaders,
  scrapeWatchPage,
} from "./animeNexusClient.mjs";
import { AnimeNexusSocketClient } from "./socketClient.mjs";

const DEFAULT_SESSION_TTL_MS = 15 * 60 * 1000;
const DEFAULT_MAX_SESSIONS = 24;
const DEFAULT_WORKER_CLOSE_TIMEOUT_MS = 5000;

class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

function parseIntSuffix(value, suffix) {
  return Number(String(value).replace(suffix, ""));
}

function text(
  res,
  statusCode,
  body,
  contentType = "text/plain; charset=utf-8",
) {
  res.writeHead(statusCode, { "content-type": contentType });
  res.end(body);
}

function manifest(res, body) {
  text(res, 200, body, "application/vnd.apple.mpegurl");
}

function binary(res, statusCode, body, headers) {
  res.writeHead(statusCode, {
    "content-type": headers.get("content-type") ?? "application/octet-stream",
    "content-length": String(body.length),
  });
  res.end(body);
}

function orderedHosts(session, preferredHost) {
  const active = preferredHost || session.edgeHost;
  if (!active) return session.candidateHosts;
  return [active, ...session.candidateHosts.filter((host) => host !== active)];
}

function signedUrl(
  host,
  path,
  token,
  sessionId,
  requestType,
  extraSearchParams = null,
) {
  const url = new URL(`https://${host}${path}`);
  url.searchParams.set("token", token);
  url.searchParams.set("requestType", requestType);
  url.searchParams.set("sessionId", sessionId);
  if (extraSearchParams) {
    for (const [key, value] of Object.entries(extraSearchParams)) {
      if (value === undefined || value === null || value === "") continue;
      url.searchParams.set(key, value);
    }
  }
  return url;
}

function parseMapPath(line, baseUrl) {
  const match = /URI=\"([^\"]+)\"/.exec(line);
  if (!match) throw new Error(`Missing map URI in ${line}`);
  return new URL(match[1], baseUrl).pathname;
}

function parseSegmentIndex(path) {
  const match = /_(\d+)-\d+\.(?:m4s|ts)$/i.exec(path);
  return match ? Number(match[1]) : 0;
}

function parseVariantFromMediaPath(path) {
  const match = /_(\d+)(?:_init)?_(?:\d+|[a-z]+)-\d+\.(?:mp4|m4s|ts)$/i.exec(
    path,
  );
  return match ? match[1] : null;
}

function parseTrackFromMediaPath(path) {
  const match =
    /_(?:\d+)(?:_init)?_(?:\d+|[a-z]+)-(\d+)\.(?:mp4|m4s|ts)$/i.exec(path);
  return match ? Number(match[1]) : null;
}

function replaceMediaUri(line, replacement) {
  return line.replace(/URI=\"[^\"]+\"/, `URI=\"${replacement}\"`);
}

function formatError(error) {
  if (!error) return "unknown error";
  return error instanceof Error ? error.message : String(error);
}

function normalizeWatchUrl(value) {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(400, "Missing watchUrl.");
  }

  let url;
  try {
    url = new URL(value);
  } catch {
    throw new HttpError(400, "watchUrl must be a valid URL.");
  }

  if (!/^https?:$/.test(url.protocol)) {
    throw new HttpError(400, "watchUrl must use http or https.");
  }
  if (!url.pathname.includes("/watch/")) {
    throw new HttpError(
      400,
      "watchUrl must point to an Anime Nexus watch page.",
    );
  }

  return url.toString();
}

function withTimeout(promise, ms) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(
        () => reject(new Error(`Operation timed out after ${ms}ms.`)),
        ms,
      );
      timer.unref?.();
    }),
  ]).finally(() => clearTimeout(timer));
}

async function safeCloseWorker(session, timeoutMs) {
  try {
    await withTimeout(session.worker.close(), timeoutMs);
  } catch {
    // Best-effort shutdown.
  }
}

export class AnimeNexusRuntimeServer {
  constructor(options = {}) {
    this.sessions = new Map();
    this.server = null;
    this.now = options.now ?? (() => Date.now());
    this.sessionTtlMs = options.sessionTtlMs ?? DEFAULT_SESSION_TTL_MS;
    this.maxSessions = options.maxSessions ?? DEFAULT_MAX_SESSIONS;
    this.workerCloseTimeoutMs =
      options.workerCloseTimeoutMs ?? DEFAULT_WORKER_CLOSE_TIMEOUT_MS;
    this.playbackIdFactory =
      options.playbackIdFactory ??
      (() => crypto.randomBytes(12).toString("hex"));
    this.createBrowserSession =
      options.createBrowserSession ?? createBrowserSession;
    this.fetchBytes = options.fetchBytes ?? fetchBytes;
    this.fetchCandidateHosts =
      options.fetchCandidateHosts ?? fetchCandidateHosts;
    this.fetchStreamData = options.fetchStreamData ?? fetchStreamData;
    this.fetchText = options.fetchText ?? fetchText;
    this.scrapeWatchPage = options.scrapeWatchPage ?? scrapeWatchPage;
    this.cdnRequestHeaders = options.cdnRequestHeaders ?? cdnRequestHeaders;
    this.workerFactory =
      options.workerFactory ?? ((config) => new AnimeNexusSocketClient(config));
  }

  async start(port = 43127) {
    if (this.server) return this.server;
    this.server = http.createServer((req, res) => {
      this.handle(req, res).catch((error) => {
        if (error instanceof HttpError) {
          text(res, error.statusCode, error.message);
          return;
        }
        text(
          res,
          500,
          `Anime Nexus node runtime failure: ${error.stack ?? error}`,
        );
      });
    });
    await new Promise((resolve) =>
      this.server.listen(port, "127.0.0.1", resolve),
    );
    return this.server;
  }

  async stop() {
    await Promise.all(
      [...this.sessions.values()].map((session) =>
        safeCloseWorker(session, this.workerCloseTimeoutMs),
      ),
    );
    this.sessions.clear();
    if (!this.server) return;
    await new Promise((resolve) => this.server.close(resolve));
    this.server = null;
  }

  baseUrl() {
    const address = this.server.address();
    return `http://127.0.0.1:${address.port}`;
  }

  async resolve(watchUrl) {
    await this.evictExpiredSessions();
    const playbackId = this.playbackIdFactory();
    const session = await this.buildSession({
      watchUrl: normalizeWatchUrl(watchUrl),
      playbackId,
    });
    this.storeSession(playbackId, session);

    await this.validateSession(session);

    const sortedStreams = [...session.masterManifest.streamEntries].sort(
      (a, b) => Number(b.qualityLabel) - Number(a.qualityLabel),
    );
    const streams = [];
    for (const stream of sortedStreams) {
      try {
        await this.primeStream(session, stream);
        streams.push({
          qualityLabel: stream.qualityLabel,
          url: `${this.baseUrl()}/anime-nexus/${playbackId}/master/${stream.metadata.variant}/${stream.metadata.track}.m3u8`,
        });
      } catch {
        // Skip unprimeable qualities.
      }
    }

    return {
      playbackId,
      episodeId: session.episodeId,
      videoId: session.videoId,
      streams,
    };
  }

  async buildSession({ watchUrl, playbackId }) {
    let browserSession = this.createBrowserSession();
    const page = await this.scrapeWatchPage(watchUrl, browserSession);
    browserSession = {
      ...browserSession,
      cookieHeader: mergeCookieHeaders(
        browserSession.cookieHeader,
        page.cookieHeader,
      ),
    };
    const streamData = await this.fetchStreamData({
      episodeId: page.episodeId,
      session: browserSession,
    });
    const master = await this.fetchText(streamData.hlsUrl, {
      "User-Agent": "Mozilla/5.0",
      Accept: "*/*",
      "Accept-Language": "es-419,es;q=0.9,en;q=0.8",
      Origin: "https://anime.nexus",
      Referer: "https://anime.nexus/",
    });
    if (!master.text.startsWith("#EXTM3U")) {
      throw new Error("Anime Nexus master manifest was empty or invalid.");
    }
    const masterManifest = parseMasterManifest(master.text, master.url);
    if (masterManifest.streamEntries.length === 0) {
      throw new Error(
        "Anime Nexus master manifest did not expose video streams.",
      );
    }
    const fallbackHost = masterManifest.streamEntries[0].uri.host;
    const candidateHosts = await this.fetchCandidateHosts(fallbackHost);
    const worker = this.workerFactory({
      episodeId: page.episodeId,
      fingerprint: browserSession.fingerprint,
      cookieHeader: streamData.cookieHeader,
      m3u8Url: streamData.hlsUrl.toString(),
      wsRef: page.attestRef,
    });
    await worker.connect();

    return {
      playbackId,
      watchUrl,
      episodeId: page.episodeId,
      videoId: streamData.videoId,
      fingerprint: browserSession.fingerprint,
      candidateHosts,
      masterManifest,
      worker,
      edgeHost: null,
      sessionId: null,
      variantManifestCache: new Map(),
      lastProgressSegmentIndex: -1,
      createdAt: this.now(),
      lastAccessAt: this.now(),
    };
  }

  async rebuildSession(session) {
    const rebuilt = await this.buildSession({
      watchUrl: session.watchUrl,
      playbackId: session.playbackId,
    });
    await safeCloseWorker(session, this.workerCloseTimeoutMs);
    session.watchUrl = rebuilt.watchUrl;
    session.episodeId = rebuilt.episodeId;
    session.videoId = rebuilt.videoId;
    session.fingerprint = rebuilt.fingerprint;
    session.candidateHosts = rebuilt.candidateHosts;
    session.masterManifest = rebuilt.masterManifest;
    session.worker = rebuilt.worker;
    session.edgeHost = rebuilt.edgeHost;
    session.sessionId = rebuilt.sessionId;
    session.variantManifestCache = rebuilt.variantManifestCache;
    session.lastProgressSegmentIndex = rebuilt.lastProgressSegmentIndex;
    session.createdAt = rebuilt.createdAt;
    session.lastAccessAt = rebuilt.lastAccessAt;
  }

  async recoverSession(session, hard = false) {
    try {
      await session.worker.refreshSession({ requestResetStream: hard });
      session.sessionId = null;
      session.edgeHost = null;
    } catch {
      await this.rebuildSession(session);
    }
  }

  async validateSession(session) {
    await this.ensureSessionId(session);
    const primary = session.masterManifest.streamEntries[0];
    if (primary.audioGroupId) {
      const audio = session.masterManifest.audioEntries.find(
        (entry) => entry.groupId === primary.audioGroupId,
      );
      if (audio) {
        await session.worker.getManifestToken(
          audio.uri.pathname,
          session.episodeId,
        );
      }
    }
    await session.worker.getManifestToken(
      primary.uri.pathname,
      session.episodeId,
    );
  }

  matchingAudio(session, stream) {
    if (!stream.audioGroupId) return [];
    return session.masterManifest.audioEntries.filter(
      (entry) => entry.groupId === stream.audioGroupId,
    );
  }

  async primeStream(session, stream) {
    const audio = this.matchingAudio(session, stream);
    await Promise.all([
      this.loadVariantManifest(
        session,
        stream.metadata.variant,
        stream.metadata.track,
      ),
      ...audio.map((entry) =>
        this.loadVariantManifest(
          session,
          entry.metadata.variant,
          entry.metadata.track,
        ),
      ),
    ]);
  }

  async ensureSessionId(session) {
    if (session.sessionId) return session.sessionId;
    session.sessionId = await session.worker.getSessionId();
    return session.sessionId;
  }

  findVideoStream(session, variant, track) {
    return (
      session.masterManifest.streamEntries.find(
        (entry) =>
          entry.metadata.variant === variant && entry.metadata.track === track,
      ) ?? null
    );
  }

  findAudioStream(session, variant, track) {
    return (
      session.masterManifest.audioEntries.find(
        (entry) =>
          entry.metadata.variant === variant && entry.metadata.track === track,
      ) ?? null
    );
  }

  async loadVariantManifest(session, variant, track) {
    const cacheKey = `${variant}:${track}`;
    if (session.variantManifestCache.has(cacheKey)) {
      return session.variantManifestCache.get(cacheKey);
    }
    const loader = this.doLoadVariantManifest(session, variant, track).catch(
      (error) => {
        session.variantManifestCache.delete(cacheKey);
        throw error;
      },
    );
    session.variantManifestCache.set(cacheKey, loader);
    return loader;
  }

  async doLoadVariantManifest(session, variant, track) {
    const videoEntry = this.findVideoStream(session, variant, track);
    const audioEntry = this.findAudioStream(session, variant, track);
    const manifestPath = videoEntry?.uri.pathname ?? audioEntry?.uri.pathname;
    const preferredHost = videoEntry?.uri.host ?? audioEntry?.uri.host ?? null;
    if (!manifestPath) {
      throw new Error(
        `Unknown Anime Nexus variant manifest: ${variant}/${track}`,
      );
    }
    const fetched = await this.fetchSignedManifest(
      session,
      manifestPath,
      preferredHost,
    );
    const rewritten = [];
    const baseUrl = new URL(fetched.url);
    for (const rawLine of fetched.body.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (line.startsWith("#EXT-X-MAP:")) {
        const path = parseMapPath(line, baseUrl);
        rewritten.push(
          replaceMediaUri(
            line,
            `${this.baseUrl()}/anime-nexus/${session.playbackId}/init/${variant}/${track}.mp4?path=${encodeURIComponent(path)}`,
          ),
        );
        continue;
      }
      if (!line || line.startsWith("#")) {
        rewritten.push(rawLine);
        continue;
      }
      const segmentPath = new URL(line, baseUrl).pathname;
      const segmentIndex = parseSegmentIndex(segmentPath);
      rewritten.push(
        `${this.baseUrl()}/anime-nexus/${session.playbackId}/segment/${variant}/${track}/${segmentIndex}.m4s?path=${encodeURIComponent(segmentPath)}`,
      );
    }
    return { body: rewritten.join("\n"), url: fetched.url };
  }

  async fetchSignedManifest(session, manifestPath, preferredHost = null) {
    let lastError = null;
    for (let attempt = 0; attempt < 4; attempt += 1) {
      if (attempt > 0) {
        await this.recoverSession(session, attempt > 1);
      }
      try {
        const sessionId = await this.ensureSessionId(session);
        const token = await session.worker.getManifestToken(
          manifestPath,
          session.episodeId,
        );
        for (const host of orderedHosts(session, preferredHost)) {
          try {
            const url = signedUrl(
              host,
              manifestPath,
              token.token,
              sessionId,
              "manifest",
            );
            const response = await this.fetchText(
              url,
              this.cdnRequestHeaders({
                fingerprint: session.fingerprint,
                sessionId,
                videoUuid: session.episodeId,
              }),
            );
            if (
              response.status === 200 &&
              response.text.startsWith("#EXTM3U")
            ) {
              session.edgeHost = host;
              return { body: response.text, url: response.url };
            }
            lastError = `${response.status} ${response.url}`;
          } catch (error) {
            lastError = error;
          }
        }
      } catch (error) {
        lastError = error;
      }
    }
    throw new Error(
      `Anime Nexus manifest request failed: ${formatError(lastError ?? manifestPath)}`,
    );
  }

  async fetchManifestProtectedBytes(session, path) {
    let last = null;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      if (attempt > 0) {
        await this.recoverSession(session, attempt > 1);
      }
      try {
        const sessionId = await this.ensureSessionId(session);
        const token = await session.worker.getManifestToken(
          path,
          session.episodeId,
        );
        for (const host of orderedHosts(session)) {
          try {
            const url = signedUrl(
              host,
              path,
              token.token,
              sessionId,
              "manifest",
            );
            const response = await this.fetchBytes(
              url,
              this.cdnRequestHeaders({
                fingerprint: session.fingerprint,
                sessionId,
                videoUuid: session.episodeId,
              }),
            );
            if (response.status === 200) {
              session.edgeHost = host;
              return response;
            }
            last = response;
          } catch (error) {
            last = error;
          }
        }
      } catch (error) {
        last = error;
      }
    }
    if (last instanceof Error) throw last;
    return last;
  }

  async fetchSegmentWithRetry(session, variant, track, segmentIndex, path) {
    let last = null;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      if (attempt > 0) {
        await this.recoverSession(session, attempt > 1);
      }
      try {
        const sessionId = await this.ensureSessionId(session);
        const token = await session.worker.getSegmentToken({
          variant,
          segmentIndex,
          track,
          videoId: session.episodeId,
        });
        for (const host of orderedHosts(session)) {
          try {
            const url = signedUrl(
              host,
              path,
              token.token,
              sessionId,
              "segment",
              { segmentPath: path },
            );
            const response = await this.fetchBytes(
              url,
              this.cdnRequestHeaders({
                fingerprint: session.fingerprint,
                sessionId,
                videoUuid: session.episodeId,
              }),
            );
            if (response.status === 200) {
              session.edgeHost = host;
              await this.reportProgress(session, track, segmentIndex);
              return response;
            }
            last = response;
          } catch (error) {
            last = error;
          }
        }
      } catch (error) {
        last = error;
      }
    }
    if (last instanceof Error) throw last;
    return last;
  }

  storeSession(playbackId, session) {
    session.createdAt = this.now();
    session.lastAccessAt = session.createdAt;
    this.sessions.set(playbackId, session);

    while (this.sessions.size > this.maxSessions) {
      const oldestEntry = [...this.sessions.entries()].sort(
        (a, b) => a[1].lastAccessAt - b[1].lastAccessAt,
      )[0];
      if (!oldestEntry) break;
      const [oldPlaybackId, oldSession] = oldestEntry;
      this.deleteSession(oldPlaybackId, oldSession).catch(() => {});
    }
  }

  touchSession(session) {
    session.lastAccessAt = this.now();
  }

  isExpired(session) {
    return this.now() - session.lastAccessAt > this.sessionTtlMs;
  }

  async deleteSession(playbackId, session) {
    this.sessions.delete(playbackId);
    await safeCloseWorker(session, this.workerCloseTimeoutMs);
  }

  async evictExpiredSessions() {
    const expired = [...this.sessions.entries()].filter(([, session]) =>
      this.isExpired(session),
    );
    await Promise.all(
      expired.map(([playbackId, session]) =>
        this.deleteSession(playbackId, session),
      ),
    );
  }

  async reportProgress(session, track, segmentIndex) {
    if (track !== 0) return;
    if (segmentIndex <= session.lastProgressSegmentIndex) return;
    session.lastProgressSegmentIndex = segmentIndex;
    try {
      await session.worker.sendProgress(segmentIndex);
    } catch {
      // Segment delivery is more important than advisory progress.
    }
  }

  async handle(req, res) {
    await this.evictExpiredSessions();
    const url = new URL(req.url, this.baseUrl());
    if (req.method === "GET" && url.pathname === "/health") {
      text(res, 200, "ok");
      return;
    }
    if (req.method === "POST" && url.pathname === "/resolve") {
      const body = await readJson(req);
      const result = await this.resolve(body.watchUrl);
      text(res, 200, JSON.stringify(result), "application/json");
      return;
    }

    const parts = url.pathname.split("/").filter(Boolean);
    if (parts[0] !== "anime-nexus" || parts.length < 5) {
      text(res, 404, "Not found");
      return;
    }
    const session = this.sessions.get(parts[1]);
    if (!session) {
      text(res, 410, "Playback session expired");
      return;
    }
    if (this.isExpired(session)) {
      await this.deleteSession(parts[1], session);
      text(res, 410, "Playback session expired");
      return;
    }
    this.touchSession(session);

    const route = parts[2];
    const variant = parts[3];
    if (route === "master") {
      const track = parseIntSuffix(parts[4], ".m3u8");
      const stream = this.findVideoStream(session, variant, track);
      if (!stream) {
        text(res, 404, "Unknown quality stream");
        return;
      }
      const audio = this.matchingAudio(session, stream);
      const lines = ["#EXTM3U"];
      for (const entry of audio) {
        lines.push(
          replaceMediaUri(
            entry.originalLine,
            `${this.baseUrl()}/anime-nexus/${session.playbackId}/variant/${entry.metadata.variant}/${entry.metadata.track}.m3u8`,
          ),
        );
      }
      lines.push(stream.infoLine);
      lines.push(
        `${this.baseUrl()}/anime-nexus/${session.playbackId}/variant/${stream.metadata.variant}/${stream.metadata.track}.m3u8`,
      );
      manifest(res, lines.join("\n"));
      return;
    }
    if (route === "variant") {
      const track = parseIntSuffix(parts[4], ".m3u8");
      const fetched = await this.loadVariantManifest(session, variant, track);
      manifest(res, fetched.body);
      return;
    }
    if (route === "init") {
      const path = url.searchParams.get("path");
      if (!path) {
        text(res, 400, "Missing init path");
        return;
      }
      const response = await this.fetchManifestProtectedBytes(session, path);
      binary(
        res,
        response?.status ?? 502,
        response?.body ?? Buffer.alloc(0),
        response?.headers ?? new Headers(),
      );
      return;
    }
    if (route === "segment") {
      const track = Number(parts[4]);
      const segmentIndex = parseIntSuffix(parts[5], ".m4s");
      const path = url.searchParams.get("path");
      if (!path) {
        text(res, 400, "Missing segment path");
        return;
      }
      const effectiveVariant = parseVariantFromMediaPath(path) ?? variant;
      const effectiveTrack = parseTrackFromMediaPath(path) ?? track;
      const response = await this.fetchSegmentWithRetry(
        session,
        effectiveVariant,
        effectiveTrack,
        segmentIndex,
        path,
      );
      binary(
        res,
        response?.status ?? 502,
        response?.body ?? Buffer.alloc(0),
        response?.headers ?? new Headers(),
      );
      return;
    }
    text(res, 404, "Unknown route");
  }
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    throw new HttpError(400, "Request body must be valid JSON.");
  }
}

export async function startAnimeNexusNodeRuntime(port = 43127) {
  const server = new AnimeNexusRuntimeServer();
  await server.start(port);
  return server;
}

const entryArg = process.argv[1];
if (entryArg) {
  const entryUrl = new URL(`file://${entryArg.replace(/\\/g, "/")}`);
  if (import.meta.url === entryUrl.href) {
    const port = Number(process.env.ANIME_NEXUS_NODE_PORT ?? 43127);
    const server = await startAnimeNexusNodeRuntime(port);
    console.log(`Anime Nexus node runtime listening on ${server.baseUrl()}`);
  }
}
