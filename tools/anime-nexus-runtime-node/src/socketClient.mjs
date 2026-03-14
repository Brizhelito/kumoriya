import WebSocket from "ws";

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export class AnimeNexusSocketClient {
  constructor({
    episodeId,
    fingerprint,
    cookieHeader,
    m3u8Url,
    wsRef,
    WebSocketImpl = WebSocket,
    ackTimeoutMs = 10000,
    connectTimeoutMs = 10000,
    closeTimeoutMs = 5000,
    delayFn = delay,
  }) {
    this.episodeId = episodeId;
    this.fingerprint = fingerprint;
    this.cookieHeader = cookieHeader;
    this.m3u8Url = m3u8Url;
    this.wsRef = wsRef;
    this.WebSocketImpl = WebSocketImpl;
    this.ackTimeoutMs = ackTimeoutMs;
    this.connectTimeoutMs = connectTimeoutMs;
    this.closeTimeoutMs = closeTimeoutMs;
    this.delayFn = delayFn;
    this.socket = null;
    this.session = null;
    this.needsReconnect = false;
    this.closed = false;
    this.socketClosing = false;
    this.ackCounter = 0;
    this.acks = new Map();
    this.manifestRequestsByKey = new Map();
    this.manifestKeysByToken = new Map();
    this.latestManifestTokenByKey = new Map();
    this.prefetchedManifestTokenByKey = new Map();
    this.prefetchInFlight = new Set();
  }

  buildUrl() {
    const url = new URL("wss://prd-socket.anime.nexus/api/socket/");
    url.searchParams.set("videoId", this.episodeId);
    url.searchParams.set("fingerprint", this.fingerprint);
    url.searchParams.set("m3u8Url", this.m3u8Url);
    url.searchParams.set("EIO", "4");
    url.searchParams.set("transport", "websocket");
    return url.toString();
  }

  async connect() {
    const ready = deferred();
    const authed = deferred();
    this.socket = new this.WebSocketImpl(this.buildUrl(), {
      headers: {
        Origin: "https://anime.nexus",
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
        Cookie: this.cookieHeader,
      },
    });

    this.socket.on("message", (buffer) => {
      this.onFrame(buffer.toString(), ready, authed);
    });
    this.socket.on("error", (error) => {
      this.socketClosing = false;
      ready.reject(error);
      authed.reject(error);
      this.failAll(error);
    });
    this.socket.on("close", () => {
      const wasClosing = this.socketClosing || this.closed;
      this.socketClosing = false;
      if (wasClosing) {
        ready.resolve();
        authed.resolve();
        return;
      }
      const error = new Error("Anime Nexus WebSocket closed unexpectedly.");
      ready.reject(error);
      authed.reject(error);
      this.failAll(error);
    });

    await withTimeout(
      ready.promise,
      this.connectTimeoutMs,
      "Anime Nexus namespace connect timed out.",
    );
    this.send(
      `42/video,${JSON.stringify(["auth", { ref: this.wsRef, fingerprint: this.fingerprint }])}`,
    );
    await withTimeout(
      authed.promise,
      this.connectTimeoutMs,
      "Anime Nexus auth handshake timed out.",
    );
    this.needsReconnect = false;
  }

  async ensureReady({ forceReconnect = false } = {}) {
    if (this.closed)
      throw new Error("Anime Nexus WebSocket is already closed.");
    if (!forceReconnect && !this.needsReconnect && this.session) return;
    await this.reconnect(forceReconnect);
  }

  async reconnect(forceReconnect = false) {
    if (forceReconnect || this.socket) {
      await this.closeSocket();
    }
    this.session = null;
    await this.connect();
  }

  async refreshSession({ requestResetStream = false } = {}) {
    if (requestResetStream) {
      this.send(`42/video,${JSON.stringify(["reset-stream"])}`);
      await this.delayFn(200);
    }
    this.needsReconnect = true;
    await this.ensureReady({ forceReconnect: true });
  }

  async getSessionId() {
    await this.ensureReady();
    const sessionId = this.session?.sessionId?.trim() ?? "";
    if (!sessionId) throw new Error("Anime Nexus session id was empty.");
    return sessionId;
  }

  async getInitialManifestToken() {
    return this.getManifestTokenInternal({
      key: "__initial__",
      manifestPath: null,
      videoId: null,
    });
  }

  async getManifestToken(manifestPath, videoId) {
    return this.getManifestTokenInternal({
      key: manifestPath,
      manifestPath,
      videoId,
    });
  }

  async getManifestTokenInternal(request) {
    await this.ensureReady();
    const prefetched = this.prefetchedManifestTokenByKey.get(request.key);
    if (prefetched) {
      this.prefetchedManifestTokenByKey.delete(request.key);
      this.rememberManifestToken(request, prefetched);
      return prefetched;
    }
    const token = await this.getToken(toManifestParams(request, null));
    this.rememberManifestToken(request, token);
    return token;
  }

  async getSegmentToken({ variant, segmentIndex, track, videoId }) {
    return this.getToken({
      requestType: "segment",
      variant,
      segIdx: segmentIndex,
      track,
      videoId,
    });
  }

  async sendProgress(segmentIndex) {
    await this.ensureReady();
    this.send(
      `42/video,${JSON.stringify(["progress", { segIdx: segmentIndex }])}`,
    );
  }

  async getToken(params) {
    await this.ensureReady();
    const ackId = (this.ackCounter += 1);
    const promise = deferred();
    this.acks.set(ackId, promise);
    this.send(`42/video,${ackId}${JSON.stringify(["getToken", params])}`);
    try {
      const payload = await withTimeout(
        promise.promise,
        this.ackTimeoutMs,
        "Anime Nexus getToken timed out.",
      );
      if (payload.error) {
        this.needsReconnect = true;
        throw new Error(
          payload.code ? `${payload.error} (${payload.code})` : payload.error,
        );
      }
      if (!payload.token) {
        throw new Error("Anime Nexus token response did not include a token.");
      }
      return payload;
    } finally {
      this.acks.delete(ackId);
    }
  }

  rememberManifestToken(request, token) {
    const previous = this.latestManifestTokenByKey.get(request.key);
    if (previous) this.manifestKeysByToken.delete(previous);
    this.manifestRequestsByKey.set(request.key, request);
    this.latestManifestTokenByKey.set(request.key, token.token);
    this.manifestKeysByToken.set(token.token, request.key);
  }

  scheduleManifestPrefetch(prevToken) {
    const key = this.manifestKeysByToken.get(prevToken);
    if (!key) return;
    const request = this.manifestRequestsByKey.get(key);
    if (!request || this.prefetchInFlight.has(key)) return;
    this.prefetchInFlight.add(key);
    this.getToken(toManifestParams(request, prevToken))
      .then((token) => {
        this.prefetchedManifestTokenByKey.set(key, token);
        this.manifestKeysByToken.set(token.token, key);
      })
      .catch(() => {})
      .finally(() => {
        this.prefetchInFlight.delete(key);
      });
  }

  onFrame(message, ready, authed) {
    if (message.startsWith("0{")) {
      this.send("40/video,");
      return;
    }
    if (message === "2") {
      this.send("3");
      return;
    }
    if (message.startsWith("40/video,")) {
      ready.resolve();
      return;
    }
    if (message.startsWith("42/video,")) {
      this.handleEvent(message.slice("42/video,".length), authed);
      return;
    }
    if (message.startsWith("43/video,")) {
      this.handleAck(message.slice("43/video,".length));
    }
  }

  handleEvent(payload, authed) {
    try {
      const [event, data] = JSON.parse(payload);
      if (event === "connected") {
        this.session = {
          sessionId: String(data.sessionId ?? ""),
          authenticated: data.authenticated === true,
          sessionExpiry: Number(data.sessionExpiry ?? 0),
        };
        authed.resolve();
        return;
      }
      if (event === "getToken" && data?.requestType === "manifest") {
        const prevToken = String(data.prevToken ?? "").trim();
        if (prevToken) this.scheduleManifestPrefetch(prevToken);
        return;
      }
      if (event === "reset-challenge") {
        this.needsReconnect = true;
        return;
      }
      if (event === "authentication-error") {
        if (this.session?.authenticated) return;
        const error = new Error(
          `Anime Nexus WebSocket auth failed: ${data?.message ?? "Authentication failed."}`,
        );
        this.needsReconnect = true;
        authed.reject(error);
        this.failAll(error);
      }
    } catch {
      return;
    }
  }

  handleAck(payload) {
    const bracketIndex = payload.indexOf("[");
    if (bracketIndex <= 0) return;
    const ackId = Number(payload.slice(0, bracketIndex));
    const deferredAck = this.acks.get(ackId);
    if (!deferredAck) return;
    try {
      const [map] = JSON.parse(payload.slice(bracketIndex));
      deferredAck.resolve(map);
    } catch (error) {
      deferredAck.reject(error);
    }
  }

  send(frame) {
    this.socket?.send(frame);
  }

  failAll(error) {
    for (const deferredAck of this.acks.values()) {
      deferredAck.reject(error);
    }
    this.acks.clear();
  }

  async closeSocket() {
    const socket = this.socket;
    this.socket = null;
    if (!socket) return;
    if (socket.readyState === this.WebSocketImpl.CLOSED) {
      this.socketClosing = false;
      return;
    }
    this.socketClosing = true;
    await withTimeout(
      new Promise((resolve) => {
        socket.once("close", resolve);
        if (socket.readyState === this.WebSocketImpl.CLOSING) return;
        try {
          if (
            socket.readyState === this.WebSocketImpl.CONNECTING &&
            typeof socket.terminate === "function"
          ) {
            socket.terminate();
            return;
          }
          socket.close();
        } catch {
          queueMicrotask(resolve);
        }
      }),
      this.closeTimeoutMs,
      "Anime Nexus socket close timed out.",
    ).catch(() => {});
    this.socketClosing = false;
  }

  async close() {
    this.closed = true;
    this.needsReconnect = false;
    await this.closeSocket();
  }
}

function toManifestParams(request, previousToken) {
  if (!request.manifestPath) {
    return { requestType: "manifest", prevToken: null };
  }
  if (previousToken) {
    return { requestType: "manifest", prevToken: previousToken };
  }
  return {
    requestType: "manifest",
    manifestUrl: request.manifestPath,
    videoId: request.videoId,
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

async function withTimeout(promise, ms, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(message)), ms);
        timer.unref?.();
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
