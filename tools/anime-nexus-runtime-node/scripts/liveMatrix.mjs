import { startAnimeNexusNodeRuntime } from "../src/runtimeServer.mjs";

const defaultWatchUrls = [
  "https://anime.nexus/watch/019cb301-d4de-7052-b26a-0f9625a09a38/episode-1-0704963ad12400b916bf",
  "https://anime.nexus/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043/episode-10-15183f0a8751f2cffefa",
];

function pickWatchUrls() {
  const args = process.argv
    .slice(2)
    .map((value) => value.trim())
    .filter(Boolean);
  return args.length > 0 ? args : defaultWatchUrls;
}

async function fetchTextWithTimeout(url, timeoutMs = 30000) {
  const response = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
  return {
    response,
    text: await response.text(),
  };
}

function parseMaster(masterText) {
  const lines = masterText.split(/\r?\n/).filter(Boolean);
  const audioVariantUrls = [
    ...masterText.matchAll(
      /URI=\"(http:\/\/127\.0\.0\.1:[^"]+\/variant\/[^"]+)\"/g,
    ),
  ].map((match) => match[1]);
  return {
    variantUrls: lines.filter(
      (line) =>
        line.startsWith("http://127.0.0.1") && line.includes("/variant/"),
    ),
    audioVariantUrls,
  };
}

function parseVariant(variantText) {
  const lines = variantText.split(/\r?\n/).filter(Boolean);
  const segmentUrls = lines.filter(
    (line) => line.startsWith("http://127.0.0.1") && line.includes("/segment/"),
  );
  return {
    initUrl: /URI=\"([^\"]+)\"/.exec(variantText)?.[1] ?? null,
    segmentUrls,
  };
}

function pickInterestingSegments(segmentUrls) {
  if (segmentUrls.length === 0) return [];
  const indexes = new Set([0, Math.min(10, segmentUrls.length - 1)]);
  if (segmentUrls.length > 32) {
    indexes.add(Math.min(89, segmentUrls.length - 1));
  }
  return [...indexes].map((index) => segmentUrls[index]).filter(Boolean);
}

async function checkVariant(variantUrl) {
  const variant = await fetchTextWithTimeout(variantUrl, 25000);
  const parsed = parseVariant(variant.text);
  const summary = {
    variantStatus: variant.response.status,
    initStatus: null,
    initBytes: null,
    segmentChecks: [],
  };

  if (parsed.initUrl) {
    const initResponse = await fetch(parsed.initUrl, {
      signal: AbortSignal.timeout(25000),
    });
    summary.initStatus = initResponse.status;
    summary.initBytes = Number(initResponse.headers.get("content-length") ?? 0);
    await initResponse.arrayBuffer();
  }

  for (const segmentUrl of pickInterestingSegments(parsed.segmentUrls)) {
    const segmentResponse = await fetch(segmentUrl, {
      signal: AbortSignal.timeout(30000),
    });
    summary.segmentChecks.push({
      status: segmentResponse.status,
      bytes: Number(segmentResponse.headers.get("content-length") ?? 0),
      path: new URL(segmentUrl).pathname,
    });
    await segmentResponse.arrayBuffer();
  }

  return summary;
}

async function checkWatch(runtime, watchUrl) {
  const summary = {
    watchUrl,
    resolve: null,
    qualities: [],
    error: null,
  };

  try {
    const resolveResponse = await fetch(`${runtime.baseUrl()}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ watchUrl }),
      signal: AbortSignal.timeout(90000),
    });
    const payload = await resolveResponse.json();
    summary.resolve = {
      status: resolveResponse.status,
      playbackId: payload.playbackId,
      episodeId: payload.episodeId,
      videoId: payload.videoId,
      streamCount: payload.streams?.length ?? 0,
    };

    for (const stream of (payload.streams ?? []).slice(0, 1)) {
      const quality = { qualityLabel: stream.qualityLabel };
      try {
        const master = await fetchTextWithTimeout(stream.url, 25000);
        quality.masterStatus = master.response.status;
        const masterParsed = parseMaster(master.text);
        const videoVariantUrl = masterParsed.variantUrls[0];
        if (!videoVariantUrl) {
          quality.error = "No variant URL found in local master manifest.";
          summary.qualities.push(quality);
          continue;
        }

        const video = await checkVariant(videoVariantUrl);
        quality.variantStatus = video.variantStatus;
        quality.initStatus = video.initStatus;
        quality.initBytes = video.initBytes;
        quality.segmentChecks = video.segmentChecks;

        const audioVariantUrl = masterParsed.audioVariantUrls[0];
        if (audioVariantUrl) {
          const audio = await checkVariant(audioVariantUrl);
          quality.audioVariantStatus = audio.variantStatus;
          quality.audioInitStatus = audio.initStatus;
          quality.audioInitBytes = audio.initBytes;
          quality.audioSegmentChecks = audio.segmentChecks;
        }
      } catch (error) {
        quality.error = error instanceof Error ? error.message : String(error);
      }
      summary.qualities.push(quality);
    }
  } catch (error) {
    summary.error = error instanceof Error ? error.message : String(error);
  }

  return summary;
}

const runtime = await startAnimeNexusNodeRuntime(
  Number(process.env.ANIME_NEXUS_NODE_PORT ?? 0),
);
let exitCode = 0;

try {
  const summaries = [];
  for (const watchUrl of pickWatchUrls()) {
    summaries.push(await checkWatch(runtime, watchUrl));
  }
  console.log(JSON.stringify(summaries, null, 2));
} catch (error) {
  exitCode = 1;
  console.error(error instanceof Error ? error.stack : String(error));
} finally {
  await Promise.race([
    runtime.stop(),
    new Promise((resolve) => setTimeout(resolve, 5000)),
  ]);
  process.exit(exitCode);
}
