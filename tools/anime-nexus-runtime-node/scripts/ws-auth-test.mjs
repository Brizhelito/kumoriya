/**
 * Standalone WS auth test — tests the full flow:
 * 1. Create browser session (synthetic sid cookie)
 * 2. Scrape watch page (get attestRef + episodeId)
 * 3. Fetch stream data (get hlsUrl + videoId + cookies)
 * 4. Connect WebSocket and authenticate
 */
import {
  createBrowserSession,
  scrapeWatchPage,
  fetchStreamData,
} from "../src/animeNexusClient.mjs";
import { AnimeNexusSocketClient } from "../src/socketClient.mjs";

const watchUrl =
  process.argv[2] ??
  "https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/episode-10-c9b0cd86068190028be1";

console.log("=== WS Auth Test ===");
console.log("watchUrl:", watchUrl);

try {
  // Step 1: Browser session
  const session = createBrowserSession();
  console.log("\n[1] Browser session created");
  console.log("  fingerprint:", session.fingerprint);
  console.log("  cookieHeader:", session.cookieHeader);

  // Step 2: Scrape page
  console.log("\n[2] Scraping watch page...");
  const page = await scrapeWatchPage(watchUrl, session);
  console.log("  episodeId:", page.episodeId);
  console.log("  attestRef:", page.attestRef?.substring(0, 16) + "...");
  console.log("  cookieHeader:", page.cookieHeader);

  // Step 3: Fetch stream data
  console.log("\n[3] Fetching stream data...");
  const streamData = await fetchStreamData({
    episodeId: page.episodeId,
    session: { fingerprint: session.fingerprint, cookieHeader: page.cookieHeader },
  });
  console.log("  hlsUrl:", streamData.hlsUrl.toString());
  console.log("  videoId:", streamData.videoId);
  console.log("  cookieHeader:", streamData.cookieHeader);

  // Step 4: WebSocket connect
  console.log("\n[4] Connecting WebSocket...");
  const client = new AnimeNexusSocketClient({
    episodeId: page.episodeId,
    fingerprint: session.fingerprint,
    cookieHeader: streamData.cookieHeader,
    m3u8Url: streamData.hlsUrl.toString(),
    wsRef: page.attestRef,
  });

  console.log("  WS URL:", client.buildUrl());
  await client.connect();
  console.log("  ✅ AUTHENTICATED!");
  console.log("  session:", JSON.stringify(client.session));

  // Step 5: Get a manifest token to verify full flow
  console.log("\n[5] Getting initial manifest token...");
  const token = await client.getInitialManifestToken();
  console.log("  ✅ Token received:", token.token?.substring(0, 20) + "...");

  await client.close();
  console.log("\n=== SUCCESS ===");
} catch (error) {
  console.error("\n❌ FAILED:", error.message);
  process.exit(1);
}
