import test from "node:test";
import assert from "node:assert/strict";
import { parseMasterManifest } from "../src/hlsParser.mjs";

test("parseMasterManifest extracts video and audio variants", () => {
  const manifest = `#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Japanese",URI="/anime/streams/show.mkv_5300-0.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080,AUDIO="aac"
/anime/streams/show.mkv_5300-1.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720
/video/720/0.m3u8
`;

  const parsed = parseMasterManifest(
    manifest,
    "https://cdn.example/master.m3u8",
  );

  assert.equal(parsed.audioEntries.length, 1);
  assert.equal(parsed.streamEntries.length, 2);
  assert.equal(parsed.audioEntries[0].metadata.variant, "5300");
  assert.equal(parsed.audioEntries[0].metadata.track, 0);
  assert.equal(parsed.streamEntries[0].qualityLabel, "1080");
  assert.equal(parsed.streamEntries[0].metadata.variant, "5300");
  assert.equal(parsed.streamEntries[0].metadata.track, 1);
  assert.equal(parsed.streamEntries[1].metadata.variant, "720");
});
