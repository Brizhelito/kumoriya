import test from "node:test";
import assert from "node:assert/strict";
import { AnimeNexusRuntimeServer } from "../src/runtimeServer.mjs";

function buildMasterManifest() {
  return `#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="group_1080",NAME="Japanese",URI="https://edge-one.test/anime/streams/show.mkv_5300-0.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080,AUDIO="group_1080"
https://edge-one.test/anime/streams/show.mkv_5300-1.m3u8
`;
}

function buildVariantManifest(variant, track, segmentCount = 100) {
  const lines = [
    "#EXTM3U",
    "#EXT-X-VERSION:7",
    "#EXT-X-TARGETDURATION:4",
    `#EXT-X-MAP:URI="/anime/streams/show.mkv_${variant}_init-${track}.mp4"`,
  ];
  for (let index = 0; index < segmentCount; index += 1) {
    lines.push("#EXTINF:4.000000,");
    lines.push(
      `/anime/streams/show.mkv_${variant}_${String(index).padStart(4, "0")}-${track}.m4s`,
    );
  }
  return lines.join("\n");
}

function createWorker() {
  return {
    connected: 0,
    closed: 0,
    manifestRequests: [],
    segmentRequests: [],
    progressCalls: [],
    refreshCalls: [],
    async connect() {
      this.connected += 1;
    },
    async close() {
      this.closed += 1;
    },
    async refreshSession(options) {
      this.refreshCalls.push(options);
    },
    async getSessionId() {
      return "session-1";
    },
    async getManifestToken(path, videoId) {
      this.manifestRequests.push({ path, videoId });
      return { token: `manifest:${path}` };
    },
    async getSegmentToken(params) {
      this.segmentRequests.push(params);
      return {
        token: `segment:${params.variant}:${params.track}:${params.segmentIndex}`,
      };
    },
    async sendProgress(segmentIndex) {
      this.progressCalls.push(segmentIndex);
    },
  };
}

async function readText(url) {
  const response = await fetch(url);
  return {
    status: response.status,
    text: await response.text(),
  };
}

test("runtime resolves, rewrites manifests, falls back hosts, and reports progress on track 0", async () => {
  const worker = createWorker();
  const variantBodies = new Map([
    ["/anime/streams/show.mkv_5300-1.m3u8", buildVariantManifest("5300", 1)],
    ["/anime/streams/show.mkv_5300-0.m3u8", buildVariantManifest("5300", 0)],
  ]);
  const fetchTextRequests = [];
  const fetchByteRequests = [];
  const server = new AnimeNexusRuntimeServer({
    playbackIdFactory: () => "playback-1",
    createBrowserSession: () => ({
      fingerprint: "fingerprint-1",
      cookieHeader: "sid=seed",
    }),
    scrapeWatchPage: async () => ({
      episodeId: "episode-1",
      attestRef: "a".repeat(64),
      cookieHeader: "viewer=1",
    }),
    fetchStreamData: async () => ({
      hlsUrl: new URL("https://master.test/master.m3u8"),
      videoId: "video-1",
      cookieHeader: "sid=seed; viewer=1",
    }),
    fetchCandidateHosts: async () => ["edge-one.test", "edge-two.test"],
    fetchText: async (url) => {
      const current = new URL(url);
      fetchTextRequests.push(current.toString());
      if (current.hostname === "master.test") {
        return {
          status: 200,
          url: current.toString(),
          text: buildMasterManifest(),
          headers: new Headers(),
        };
      }
      const body = variantBodies.get(current.pathname);
      if (!body) {
        return {
          status: 404,
          url: current.toString(),
          text: "missing",
          headers: new Headers(),
        };
      }
      if (current.hostname === "edge-one.test") {
        return {
          status: 503,
          url: current.toString(),
          text: "retry",
          headers: new Headers(),
        };
      }
      return {
        status: 200,
        url: current.toString(),
        text: body,
        headers: new Headers(),
      };
    },
    fetchBytes: async (url, headers) => {
      const current = new URL(url);
      fetchByteRequests.push({ url: current.toString(), headers });
      if (current.hostname === "edge-one.test") {
        return {
          status: 503,
          url: current.toString(),
          body: Buffer.alloc(0),
          headers: new Headers(),
        };
      }
      return {
        status: 200,
        url: current.toString(),
        body: Buffer.from(current.pathname),
        headers: new Headers({ "content-type": "video/mp4" }),
      };
    },
    workerFactory: () => worker,
  });

  await server.start(0);
  try {
    const resolveResponse = await fetch(`${server.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        watchUrl: "https://anime.nexus/watch/episode-1/slug",
      }),
    });
    assert.equal(resolveResponse.status, 200);
    const payload = await resolveResponse.json();
    assert.equal(payload.playbackId, "playback-1");
    assert.equal(payload.streams.length, 1);

    const master = await readText(payload.streams[0].url);
    assert.equal(master.status, 200);
    assert.match(master.text, /\/variant\/5300\/1\.m3u8/);
    assert.match(master.text, /\/variant\/5300\/0\.m3u8/);

    const variantUrl = master.text
      .split(/\r?\n/)
      .find(
        (line) =>
          line.startsWith("http://127.0.0.1") && line.includes("/variant/"),
      );
    const variant = await readText(variantUrl);
    assert.equal(variant.status, 200);
    assert.match(variant.text, /\/init\/5300\/1\.mp4/);
    assert.match(variant.text, /\/segment\/5300\/1\/89\.m4s/);

    const initUrl = /URI=\"([^\"]+)\"/.exec(variant.text)?.[1];
    const segmentUrls = variant.text
      .split(/\r?\n/)
      .filter((line) => line.includes("/segment/"));
    const audioVariantUrl = /URI=\"([^\"]+)\"/.exec(master.text)?.[1] ?? null;
    const audioVariant = await readText(audioVariantUrl);
    assert.equal(audioVariant.status, 200);
    const audioSegmentUrls = audioVariant.text
      .split(/\r?\n/)
      .filter((line) => line.includes("/segment/"));

    const init = await fetch(initUrl);
    assert.equal(init.status, 200);

    const segment89 = await fetch(segmentUrls[89]);
    const segment10 = await fetch(audioSegmentUrls[10]);
    const segment90 = await fetch(audioSegmentUrls[90]);
    assert.equal(segment89.status, 200);
    assert.equal(segment10.status, 200);
    assert.equal(segment90.status, 200);

    assert.deepEqual(worker.progressCalls, [10, 90]);
    assert.ok(
      worker.segmentRequests.every(
        (request) => request.videoId === "episode-1",
      ),
    );
    assert.ok(
      worker.segmentRequests.some(
        (request) =>
          request.variant === "5300" &&
          request.track === 1 &&
          request.segmentIndex === 89,
      ),
    );
    assert.ok(
      worker.segmentRequests.some(
        (request) =>
          request.variant === "5300" &&
          request.track === 0 &&
          request.segmentIndex === 90,
      ),
    );
    assert.ok(
      fetchTextRequests.some((entry) => entry.includes("edge-one.test")),
    );
    assert.ok(
      fetchByteRequests.some((entry) => entry.url.includes("edge-two.test")),
    );
    const segmentFetch = fetchByteRequests.find((entry) =>
      entry.url.includes("/anime/streams/show.mkv_5300_0089-1.m4s"),
    );
    assert.ok(segmentFetch);
    const segmentFetchUrl = new URL(segmentFetch.url);
    assert.equal(segmentFetchUrl.searchParams.get("requestType"), "segment");
    assert.equal(
      segmentFetchUrl.searchParams.get("segmentPath"),
      "/anime/streams/show.mkv_5300_0089-1.m4s",
    );
  } finally {
    await server.stop();
  }
});

test("runtime rejects invalid resolve payloads and expires sessions", async () => {
  let now = 0;
  const workers = [];
  const server = new AnimeNexusRuntimeServer({
    now: () => now,
    sessionTtlMs: 50,
    playbackIdFactory: () => "playback-ttl",
    createBrowserSession: () => ({
      fingerprint: "fingerprint-1",
      cookieHeader: "sid=seed",
    }),
    scrapeWatchPage: async () => ({
      episodeId: "episode-ttl",
      attestRef: "b".repeat(64),
      cookieHeader: "viewer=1",
    }),
    fetchStreamData: async () => ({
      hlsUrl: new URL("https://master.test/master.m3u8"),
      videoId: "video-ttl",
      cookieHeader: "sid=seed; viewer=1",
    }),
    fetchCandidateHosts: async () => ["edge-two.test"],
    fetchText: async (url) => {
      const current = new URL(url);
      if (current.hostname === "master.test") {
        return {
          status: 200,
          url: current.toString(),
          text: buildMasterManifest(),
          headers: new Headers(),
        };
      }
      return {
        status: 200,
        url: current.toString(),
        text: buildVariantManifest("1080", 0, 2),
        headers: new Headers(),
      };
    },
    fetchBytes: async (url) => ({
      status: 200,
      url: String(url),
      body: Buffer.from("ok"),
      headers: new Headers({ "content-type": "video/mp4" }),
    }),
    workerFactory: () => {
      const worker = createWorker();
      workers.push(worker);
      return worker;
    },
  });

  await server.start(0);
  try {
    const badJson = await fetch(`${server.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{bad json",
    });
    assert.equal(badJson.status, 400);

    const missingUrl = await fetch(`${server.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({}),
    });
    assert.equal(missingUrl.status, 400);

    const resolved = await fetch(`${server.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        watchUrl: "https://anime.nexus/watch/episode-ttl/slug",
      }),
    });
    const payload = await resolved.json();
    now += 100;

    const expired = await fetch(payload.streams[0].url);
    assert.equal(expired.status, 410);
    assert.equal(workers[0].closed, 1);
  } finally {
    await server.stop();
  }
});

test("runtime serves slow concurrent seek-like segment requests", async () => {
  const worker = createWorker();
  const server = new AnimeNexusRuntimeServer({
    playbackIdFactory: () => "playback-seek",
    createBrowserSession: () => ({
      fingerprint: "fingerprint-1",
      cookieHeader: "sid=seed",
    }),
    scrapeWatchPage: async () => ({
      episodeId: "episode-seek",
      attestRef: "c".repeat(64),
      cookieHeader: "viewer=1",
    }),
    fetchStreamData: async () => ({
      hlsUrl: new URL("https://master.test/master.m3u8"),
      videoId: "video-seek",
      cookieHeader: "sid=seed; viewer=1",
    }),
    fetchCandidateHosts: async () => ["edge-one.test"],
    fetchText: async (url) => {
      const current = new URL(url);
      if (current.hostname === "master.test") {
        return {
          status: 200,
          url: current.toString(),
          text: buildMasterManifest(),
          headers: new Headers(),
        };
      }
      return {
        status: 200,
        url: current.toString(),
        text: buildVariantManifest(
          "5300",
          current.pathname.endsWith("-0.m3u8") ? 0 : 1,
          4,
        ),
        headers: new Headers(),
      };
    },
    fetchBytes: async (url) => {
      await new Promise((resolve) => setTimeout(resolve, 25));
      return {
        status: 200,
        url: String(url),
        body: Buffer.from(`bytes:${new URL(url).pathname}`),
        headers: new Headers({ "content-type": "video/mp4" }),
      };
    },
    workerFactory: () => worker,
  });

  await server.start(0);
  try {
    const resolved = await fetch(`${server.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        watchUrl: "https://anime.nexus/watch/episode-seek/slug",
      }),
    });
    const payload = await resolved.json();
    const master = await readText(payload.streams[0].url);
    const variantUrl =
      master.text
        .split(/\r?\n/)
        .find(
          (line) =>
            line.startsWith("http://127.0.0.1") &&
            line.includes("/variant/5300/0.m3u8"),
        ) ?? /URI=\"([^\"]+)\"/.exec(master.text)?.[1];
    const variant = await readText(variantUrl);
    const segmentUrls = variant.text
      .split(/\r?\n/)
      .filter((line) => line.includes("/segment/"));

    const responses = await Promise.all([
      fetch(segmentUrls[2]),
      fetch(segmentUrls[0]),
      fetch(segmentUrls[1]),
    ]);

    assert.deepEqual(
      responses.map((response) => response.status),
      [200, 200, 200],
    );
    assert.deepEqual(worker.progressCalls, [2]);
  } finally {
    await server.stop();
  }
});
