import http from "node:http";
import test from "node:test";
import assert from "node:assert/strict";
import {
  fetchBytes,
  fetchText,
  mergeCookieHeaders,
  scrapeWatchPage,
} from "../src/animeNexusClient.mjs";

function startServer(handler) {
  const server = http.createServer(handler);
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function serverUrl(server, path = "/") {
  const { port } = server.address();
  return `http://127.0.0.1:${port}${path}`;
}

test("mergeCookieHeaders keeps latest value per cookie name", () => {
  const merged = mergeCookieHeaders(
    "sid=old; Path=/; HttpOnly",
    ["foo=1; Path=/", "sid=new; Secure"],
    null,
  );

  assert.equal(merged, "sid=new; foo=1");
});

test("scrapeWatchPage extracts attestRef, episodeId, and merged cookies", async () => {
  const server = await startServer((req, res) => {
    res.writeHead(200, {
      "content-type": "text/html",
      "set-cookie": ["viewer=abc; Path=/", "session=xyz; Path=/"],
    });
    res.end(
      '<script>window.__x={attestRef:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}</script>',
    );
  });

  try {
    const result = await scrapeWatchPage(
      serverUrl(server, "/watch/episode-123/slug"),
      { cookieHeader: "sid=seed" },
      { timeoutMs: 500 },
    );

    assert.equal(result.episodeId, "episode-123");
    assert.equal(result.attestRef, "a".repeat(64));
    assert.equal(result.cookieHeader, "sid=seed; viewer=abc; session=xyz");
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("fetchText aborts on slow upstreams", async () => {
  const server = await startServer((req, res) => {
    setTimeout(() => {
      res.writeHead(200, { "content-type": "text/plain" });
      res.end("late");
    }, 100);
  });

  try {
    await assert.rejects(
      () => fetchText(serverUrl(server), {}, { timeoutMs: 20 }),
      /timed out/i,
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("fetchBytes returns binary payloads", async () => {
  const body = Buffer.from([0, 1, 2, 3, 255]);
  const server = await startServer((req, res) => {
    res.writeHead(200, { "content-type": "application/octet-stream" });
    res.end(body);
  });

  try {
    const response = await fetchBytes(
      serverUrl(server),
      {},
      { timeoutMs: 500 },
    );
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, body);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
