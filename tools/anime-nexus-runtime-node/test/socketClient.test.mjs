import { EventEmitter } from "node:events";
import test from "node:test";
import assert from "node:assert/strict";
import { AnimeNexusSocketClient } from "../src/socketClient.mjs";

class FakeWebSocket extends EventEmitter {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;
  static instances = [];

  constructor(url, options) {
    super();
    this.url = url;
    this.options = options;
    this.readyState = FakeWebSocket.OPEN;
    this.sent = [];
    FakeWebSocket.instances.push(this);
  }

  send(frame) {
    this.sent.push(frame);
  }

  close() {
    this.readyState = FakeWebSocket.CLOSING;
    queueMicrotask(() => {
      this.readyState = FakeWebSocket.CLOSED;
      this.emit("close");
    });
  }

  terminate() {
    this.readyState = FakeWebSocket.CLOSED;
    queueMicrotask(() => this.emit("close"));
  }
}

function createClient(overrides = {}) {
  return new AnimeNexusSocketClient({
    episodeId: "episode-1",
    fingerprint: "fingerprint-1",
    cookieHeader: "sid=seed",
    m3u8Url: "https://cdn.example/master.m3u8",
    wsRef: "a".repeat(64),
    WebSocketImpl: FakeWebSocket,
    ackTimeoutMs: 50,
    connectTimeoutMs: 50,
    delayFn: async () => {},
    ...overrides,
  });
}

function lastSocket() {
  return FakeWebSocket.instances.at(-1);
}

function keepAlive() {
  const timer = setInterval(() => {}, 1000);
  return () => clearInterval(timer);
}

async function connectClient(client) {
  const connecting = client.connect();
  const socket = lastSocket();
  socket.emit("message", Buffer.from('0{"sid":"abc"}'));
  assert.equal(socket.sent.at(-1), "40/video,");
  socket.emit("message", Buffer.from("40/video,"));
  await new Promise((resolve) => setImmediate(resolve));
  assert.match(socket.sent.at(-1), /"auth"/);
  socket.emit(
    "message",
    Buffer.from(
      `42/video,${JSON.stringify(["connected", { sessionId: "session-1", authenticated: true }])}`,
    ),
  );
  await connecting;
  return socket;
}

test("socket client handshakes and exchanges token and progress frames", async () => {
  const release = keepAlive();
  FakeWebSocket.instances.length = 0;
  try {
    const client = createClient();
    const socket = await connectClient(client);

    const firstTokenPromise = client.getManifestToken(
      "/video/show_1080-0.m3u8",
      "episode-1",
    );
    await new Promise((resolve) => setImmediate(resolve));
    socket.emit(
      "message",
      Buffer.from('43/video,1[{"token":"tok-1","expires":1}]'),
    );
    const first = await firstTokenPromise;
    assert.equal(first.token, "tok-1");

    await client.sendProgress(7);
    assert.match(socket.sent.at(-1), /"progress"/);

    await client.close();
  } finally {
    release();
  }
});

test("socket client clears pending acks after timeout", async () => {
  const release = keepAlive();
  FakeWebSocket.instances.length = 0;
  try {
    const client = createClient({ ackTimeoutMs: 10 });
    await connectClient(client);

    const pendingToken = client.getSegmentToken({
      variant: "1080",
      segmentIndex: 0,
      track: 0,
      videoId: "episode-1",
    });
    await assert.rejects(pendingToken, /timed out/i);
    assert.equal(client.acks.size, 0);

    await client.close();
  } finally {
    release();
  }
});

test("socket client closes cleanly without reporting unexpected close", async () => {
  const release = keepAlive();
  FakeWebSocket.instances.length = 0;
  try {
    const client = createClient();
    await connectClient(client);
    await assert.doesNotReject(() => client.close());
  } finally {
    release();
  }
});

test("socket client tolerates close while websocket is still connecting", async () => {
  const release = keepAlive();
  FakeWebSocket.instances.length = 0;
  try {
    const client = createClient();
    const socket = new FakeWebSocket("wss://example.test", {});
    socket.readyState = FakeWebSocket.CONNECTING;
    socket.close = () => {
      throw new Error("close before connect");
    };
    socket.terminate = () => {
      throw new Error("terminate before connect");
    };
    client.socket = socket;

    await assert.doesNotReject(() => client.close());
  } finally {
    release();
  }
});
