import { startAnimeNexusNodeRuntime } from "../src/runtimeServer.mjs";

const watchUrl =
  process.argv[2] ??
  "https://anime.nexus/watch/019cb301-d4de-7052-b26a-0f9625a09a38/episode-1-0704963ad12400b916bf";
const runtime = await startAnimeNexusNodeRuntime(43127);

try {
  const resolveResponse = await fetch(`${runtime.baseUrl()}/resolve`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ watchUrl }),
  });
  const resolvePayload = await resolveResponse.json();
  console.log(JSON.stringify(resolvePayload, null, 2));

  const first = resolvePayload.streams?.[0]?.url;
  if (!first) {
    throw new Error("No streams returned by node runtime.");
  }

  const master = await fetch(first);
  console.log("master.status", master.status);
  console.log((await master.text()).slice(0, 400));
} finally {
  await runtime.stop();
}
