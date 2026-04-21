package dev.kumoriya.exoplayer.nexus

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * Native port of `NexusWsClient` — Socket.IO v4 (Engine.IO 4) over a single
 * OkHttp WebSocket.
 *
 * Handles the `/video` namespace used by anime.nexus to issue signed
 * manifest/segment tokens on demand. Tokens expire in ~5 minutes so every
 * CDN fetch needs a round-trip here first; throughput of the WS call path
 * is the dominant factor in cold playback latency — hence it lives in
 * Kotlin instead of a Dart isolate.
 *
 * Frame grammar (from the Dart reference):
 *   `0{…}`          Engine.IO OPEN → reply `40/video,` to join namespace.
 *   `2`             ping     → reply `3` (pong).
 *   `40/video,`     namespace connected ack.
 *   `42/video,N[…]` event `N` with optional ack id (integer prefix).
 *   `43/video,N[…]` ack response for event id N.
 */
internal class NexusWsClient(
    private val http: OkHttpClient,
    private val episodeId: String,
    private val fingerprint: String,
    private val m3u8Url: String,
    private val onDebugLog: ((String) -> Unit)? = null,
) {
    private val ackCounter = AtomicInteger(0)
    private val pendingAcks =
        ConcurrentHashMap<Int, CompletableDeferred<JSONObject>>()
    // Last token emitted for a given manifestPath (keyed by path or
    // sentinel `__initial__`) — used to chain `prevToken` on the next
    // getManifestToken call, matching the Dart reference implementation.
    private val lastManifestToken = ConcurrentHashMap<String, String>()
    private var initialManifestToken: String? = null
    private val socketRef = AtomicReference<WebSocket?>(null)
    private val sessionRef = AtomicReference<Session?>(null)
    private var namespaceAck: CompletableDeferred<Unit>? = null
    private var authAck: CompletableDeferred<Unit>? = null
    private var closed = false

    data class Session(
        val sessionId: String,
        val authenticated: Boolean,
        val sessionExpiry: Long,
    )

    val session: Session?
        get() = sessionRef.get()

    /**
     * Establish WS connection, join `/video` namespace and perform the auth
     * handshake using [attestRef] scraped earlier from the watch page.
     */
    suspend fun connect(attestRef: String) {
        if (closed) throw NexusWsException("WS client is closed")

        val ready = CompletableDeferred<Unit>()
        val authed = CompletableDeferred<Unit>()
        namespaceAck = ready
        authAck = authed

        val url = buildUrl()
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header("Origin", NexusConstants.MAIN_BASE)
            .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
            .build()

        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                log("ws-open code=${response.code}")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleFrame(text, webSocket, ready = ready, authed = authed)
            }

            override fun onFailure(
                webSocket: WebSocket,
                t: Throwable,
                response: Response?,
            ) {
                val err = NexusWsException(
                    "WS failure: ${t.message ?: t.javaClass.simpleName}",
                    t,
                )
                if (!ready.isCompleted) ready.completeExceptionally(err)
                if (!authed.isCompleted) authed.completeExceptionally(err)
                failAllPending(err)
            }

            override fun onClosed(
                webSocket: WebSocket,
                code: Int,
                reason: String,
            ) {
                val err = NexusWsException(
                    "WS closed code=$code reason=$reason",
                )
                if (!ready.isCompleted) ready.completeExceptionally(err)
                if (!authed.isCompleted) authed.completeExceptionally(err)
                failAllPending(err)
            }
        }

        val webSocket = http.newWebSocket(request, listener)
        socketRef.set(webSocket)

        try {
            withTimeout(10_000) { ready.await() }
        } catch (e: TimeoutCancellationException) {
            throw NexusWsException("namespace connect timed out", e)
        }

        webSocket.send(
            """42/video,["auth",{"ref":"$attestRef","fingerprint":"$fingerprint"}]""",
        )

        try {
            withTimeout(10_000) { authed.await() }
        } catch (e: TimeoutCancellationException) {
            throw NexusWsException("auth handshake timed out", e)
        }
    }

    suspend fun getInitialManifestToken(): NexusStreamToken {
        val token = getToken(
            JSONObject()
                .put("requestType", "manifest")
                .put("prevToken", JSONObject.NULL),
        )
        initialManifestToken = token.token
        return token
    }

    suspend fun getManifestToken(
        manifestPath: String,
        videoId: String,
    ): NexusStreamToken {
        val token = getToken(
            JSONObject()
                .put("requestType", "manifest")
                .put("manifestUrl", manifestPath)
                .put("videoId", videoId),
        )
        lastManifestToken[manifestPath] = token.token
        return token
    }

    suspend fun getSegmentToken(
        variant: String,
        segmentIndex: Int,
        track: Int,
        videoId: String,
    ): NexusStreamToken =
        getToken(
            JSONObject()
                .put("requestType", "segment")
                .put("variant", variant)
                .put("segIdx", segmentIndex)
                .put("track", track)
                .put("videoId", videoId),
        )

    fun sendProgress(segmentIndex: Int) {
        val socket = socketRef.get() ?: return
        val payload = JSONArray()
            .put("progress")
            .put(JSONObject().put("segIdx", segmentIndex))
        socket.send("42/video,$payload")
    }

    fun close() {
        if (closed) return
        closed = true
        failAllPending(NexusWsException("WS client closed by caller"))
        socketRef.getAndSet(null)?.close(1000, "client close")
    }

    // ── Internals ────────────────────────────────────────────────────

    private suspend fun getToken(params: JSONObject): NexusStreamToken {
        if (closed) throw NexusWsException("WS client is closed")
        val socket = socketRef.get()
            ?: throw NexusWsException("WS is not connected")

        val ackId = ackCounter.getAndIncrement()
        val deferred = CompletableDeferred<JSONObject>()
        pendingAcks[ackId] = deferred

        val frame = buildString {
            append("42/video,")
            append(ackId)
            append("[\"getToken\",")
            append(params.toString())
            append(']')
        }
        log("[ws-send] $frame")
        socket.send(frame)

        val payload = try {
            withTimeout(10_000) { deferred.await() }
        } catch (e: TimeoutCancellationException) {
            pendingAcks.remove(ackId)
            throw NexusWsException("getToken ackId=$ackId timed out", e)
        }
        log("[ws-ack] ackId=$ackId payload=$payload")
        if (payload.has("error") && !payload.isNull("error")) {
            val err = payload.optString("error").trim()
                .ifEmpty { "getToken failed" }
            throw NexusWsException(err)
        }
        val token = NexusStreamToken.fromJson(payload)
        if (token.token.isBlank()) {
            throw NexusWsException("getToken returned empty token")
        }
        return token
    }

    private fun handleFrame(
        message: String,
        socket: WebSocket,
        ready: CompletableDeferred<Unit>,
        authed: CompletableDeferred<Unit>,
    ) {
        when {
            message.startsWith("0{") -> {
                // Engine.IO OPEN → reply `40/video,` to join namespace.
                socket.send("40/video,")
            }

            message == "2" -> {
                socket.send("3") // PONG
            }

            message.startsWith("40/video,") -> {
                if (!ready.isCompleted) ready.complete(Unit)
            }

            message.startsWith("42/video,") -> {
                handleEvent(message.substring("42/video,".length), authed)
            }

            message.startsWith("43/video,") -> {
                handleAck(message.substring("43/video,".length))
            }
        }
    }

    private fun handleEvent(
        payload: String,
        authed: CompletableDeferred<Unit>,
    ) {
        val parsed = try {
            JSONArray(payload)
        } catch (_: Throwable) {
            return
        }
        if (parsed.length() < 2) return
        val event = parsed.optString(0).trim()
        val data = parsed.optJSONObject(1) ?: return

        when (event) {
            "connected" -> {
                val session = Session(
                    sessionId = data.optString("sessionId").trim(),
                    authenticated = data.optBoolean("authenticated", false),
                    sessionExpiry = data.optLong("sessionExpiry", 0L),
                )
                sessionRef.set(session)
                log(
                    "ws-connected sessionId=${session.sessionId} " +
                        "authenticated=${session.authenticated} " +
                        "sessionExpiry=${session.sessionExpiry}",
                )
                if (!authed.isCompleted) authed.complete(Unit)
            }

            "authentication-error" -> {
                val message = data.optString("message").trim()
                    .ifEmpty { "authentication failed" }
                val err = NexusWsException("WS auth failed: $message")
                if (!authed.isCompleted) authed.completeExceptionally(err)
                failAllPending(err)
            }

            "reset-challenge" -> {
                // Recorded only; segment fetches will rebuild the session
                // when the next token round-trip fails.
                log("reset-challenge received")
            }

            else -> {
                log("event-unhandled event=$event data=$data")
                // Other server-pushed events (getToken/prevToken prefetch)
                // are not needed for correctness in the native pipeline:
                // Media3 refetches tokens on demand and we do not keep a
                // per-manifest prefetch cache.
            }
        }
    }

    private fun handleAck(raw: String) {
        val bracket = raw.indexOf('[')
        if (bracket <= 0) return
        val ackId = raw.substring(0, bracket).toIntOrNull() ?: return
        val completer = pendingAcks.remove(ackId) ?: return
        try {
            val list = JSONArray(raw.substring(bracket))
            val map = list.optJSONObject(0) ?: run {
                completer.completeExceptionally(
                    NexusWsException("ack $ackId missing payload object"),
                )
                return
            }
            if (map.has("error") && !map.isNull("error")) {
                val err = map.optString("error").trim()
                    .ifEmpty { "ack failed" }
                completer.completeExceptionally(NexusWsException(err))
                return
            }
            completer.complete(map)
        } catch (t: Throwable) {
            completer.completeExceptionally(t)
        }
    }

    private fun failAllPending(err: Throwable) {
        val snapshot = pendingAcks.toMap()
        pendingAcks.clear()
        for (d in snapshot.values) {
            if (!d.isCompleted) d.completeExceptionally(err)
        }
    }

    private fun buildUrl(): String {
        val params = mapOf(
            "videoId" to episodeId,
            "fingerprint" to fingerprint,
            "m3u8Url" to m3u8Url,
            "EIO" to "4",
            "transport" to "websocket",
        )
        val query = params.entries.joinToString("&") { (k, v) ->
            "$k=${URLEncoder.encode(v, "UTF-8")}"
        }
        return "wss://${NexusConstants.WS_HOST}/api/socket/?$query"
    }

    private fun log(message: String) {
        onDebugLog?.invoke("[anime-nexus.ws] $message")
    }
}
