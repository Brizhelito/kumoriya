package dev.kumoriya.exoplayer.nexus

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

/**
 * Picks the CDN edge that can serve signed manifests/segments fastest.
 *
 * The anime.nexus SPA queries `https://anime.nexus/api/cdn/health`, then
 * pings each healthy edge's `/ping` endpoint, and reuses the lowest-RTT
 * host across all variant/segment requests.  We do the same — falling back
 * gracefully when the probe fails so a slow network does not brick playback.
 *
 * The chosen host is cached process-wide for [CACHE_TTL_MS] so concurrent
 * playback sessions share one edge.
 */
internal object NexusEdgeSelector {
    private const val HEALTH_URL = "https://anime.nexus/api/cdn/health"
    private const val CACHE_TTL_MS = 10 * 60 * 1000L
    private const val PING_TIMEOUT_MS = 1500L
    private const val LOG_TAG = "NexusEdgeSelector"

    private data class Cached(val selection: Selection, val fetchedAt: Long)

    /**
     * Result of [selectRanked]: a primary host plus further candidates
     * ranked by RTT (when pingable) or health score (when we had to fall
     * back). The caller walks the list on recoverable errors (e.g. 403
     * "Token validation failed" from a WAF-gated edge).
     */
    data class Selection(
        val primary: String,
        val fallbacks: List<String>,
    )

    @Volatile private var cached: Cached? = null

    /**
     * Returns the best edge host (e.g. `us5.cdn.nexus`). Synchronous — run
     * this during session bootstrap, not on the Media3 loader thread.
     *
     * If the health probe or every ping times out, falls back to the edge
     * with the highest healthScore + lowest load from the health response.
     * If even that fails, returns the [fallbackHost].
     */
    suspend fun select(
        http: OkHttpClient,
        fallbackHost: String,
        log: (String) -> Unit = {},
    ): String = selectRanked(http, fallbackHost, log).primary

    /**
     * Like [select] but returns the primary together with every other
     * reachable edge ranked by RTT. Used by the playback session to
     * rotate away from a host when the WAF rejects tokens for IP
     * reputation reasons while the rest of the edge fleet is happy.
     */
    suspend fun selectRanked(
        http: OkHttpClient,
        fallbackHost: String,
        log: (String) -> Unit = {},
    ): Selection {
        cached?.let {
            if (System.currentTimeMillis() - it.fetchedAt < CACHE_TTL_MS) {
                log("[edge-selector] cache-hit host=${it.selection.primary}")
                return it.selection
            }
        }

        val health = runCatching { fetchHealth(http) }.getOrNull()
        if (health == null || health.edges.isEmpty()) {
            log("[edge-selector] health-fetch-failed using=$fallbackHost")
            return Selection(primary = fallbackHost, fallbacks = emptyList())
        }

        val byHost = health.nodes.associateBy { it.host }
        val pingable = health.edges.filter { edge ->
            val node = byHost[edge.host]
            node == null || node.healthy
        }
        if (pingable.isEmpty()) {
            log("[edge-selector] no-healthy-edges using=$fallbackHost")
            return Selection(primary = fallbackHost, fallbacks = emptyList())
        }

        val ranked = rankByPing(http, pingable, log)
        val selection = if (ranked.isNotEmpty()) {
            Selection(primary = ranked.first(), fallbacks = ranked.drop(1))
        } else {
            val byScore = health.nodes.filter { it.healthy }
                .sortedWith(
                    compareByDescending<NodeInfo> { it.healthScore }
                        .thenBy { it.load },
                )
                .map { it.host }
                .distinct()
            if (byScore.isEmpty()) {
                Selection(primary = fallbackHost, fallbacks = emptyList())
            } else {
                Selection(
                    primary = byScore.first(),
                    fallbacks = byScore.drop(1),
                )
            }
        }
        log(
            "[edge-selector] chose host=${selection.primary} " +
                "fallbacks=${selection.fallbacks}",
        )
        cached = Cached(
            selection = selection,
            fetchedAt = System.currentTimeMillis(),
        )
        return selection
    }

    /** Invalidate the cached edge selection, e.g. on repeated 403s. */
    fun invalidateCache() {
        cached = null
    }

    private suspend fun fetchHealth(http: OkHttpClient): HealthResponse =
        withContext(Dispatchers.IO) {
            val req = Request.Builder()
                .url(HEALTH_URL)
                .header("User-Agent", NexusConstants.USER_AGENT)
                .header("Accept", "application/json, text/plain, */*")
                .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
                .header("Origin", NexusConstants.MAIN_BASE)
                .header("Referer", "${NexusConstants.MAIN_BASE}/")
                .build()
            http.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) {
                    error("health endpoint responded status=${resp.code}")
                }
                val body = resp.body?.string().orEmpty()
                HealthResponse.fromJson(JSONObject(body))
            }
        }

    private suspend fun rankByPing(
        http: OkHttpClient,
        edges: List<EdgeInfo>,
        log: (String) -> Unit,
    ): List<String> = coroutineScope {
        val timings = edges.map { edge ->
            async(Dispatchers.IO) { edge to ping(http, edge) }
        }.awaitAll()

        val ranked = timings.mapNotNull { (edge, rtt) ->
            if (rtt == null) null else edge to rtt
        }.sortedBy { it.second }

        if (ranked.isEmpty()) {
            log("[edge-selector] no-edge-answered-ping")
            return@coroutineScope emptyList()
        }
        for ((edge, rtt) in ranked.take(3)) {
            log("[edge-selector] ping edge=${edge.host} rtt=${rtt}ms")
        }
        ranked.map { it.first.host }.distinct()
    }

    private suspend fun ping(
        http: OkHttpClient,
        edge: EdgeInfo,
    ): Long? = withTimeoutOrNull(PING_TIMEOUT_MS) {
        val start = System.currentTimeMillis()
        val req = Request.Builder()
            .url(edge.pingUrl)
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header("Origin", NexusConstants.MAIN_BASE)
            .header("Referer", "${NexusConstants.MAIN_BASE}/")
            .build()
        runCatching {
            http.newCall(req).execute().use { resp ->
                if (resp.isSuccessful || resp.code == 204) {
                    System.currentTimeMillis() - start
                } else {
                    null
                }
            }
        }.getOrNull()
    }

    private data class HealthResponse(
        val nodes: List<NodeInfo>,
        val edges: List<EdgeInfo>,
    ) {
        companion object {
            fun fromJson(json: JSONObject): HealthResponse {
                val nodes = json.optJSONArray("nodes")?.let { arr ->
                    (0 until arr.length()).mapNotNull {
                        arr.optJSONObject(it)?.let(NodeInfo::fromJson)
                    }
                }.orEmpty()
                val edges = json.optJSONArray("edges")?.let { arr ->
                    (0 until arr.length()).mapNotNull {
                        arr.optJSONObject(it)?.let(EdgeInfo::fromJson)
                    }
                }.orEmpty()
                return HealthResponse(nodes = nodes, edges = edges)
            }
        }
    }

    private data class NodeInfo(
        val host: String,
        val healthy: Boolean,
        val healthScore: Int,
        val load: Double,
    ) {
        companion object {
            fun fromJson(obj: JSONObject): NodeInfo? {
                val meta = obj.optJSONObject("metadata")
                val host = meta?.optString("host").orEmpty().trim()
                    .ifEmpty { return null }
                return NodeInfo(
                    host = host,
                    healthy = obj.optString("status")
                        .equals("healthy", ignoreCase = true),
                    healthScore = obj.optInt("healthScore", 0),
                    load = obj.optDouble("load", 1.0),
                )
            }
        }
    }

    private data class EdgeInfo(
        val id: String,
        val host: String,
        val pingUrl: String,
    ) {
        companion object {
            fun fromJson(obj: JSONObject): EdgeInfo? {
                val host = obj.optString("host").trim().ifEmpty { return null }
                val pingUrl = obj.optString("ping_url").trim()
                    .ifEmpty { "https://$host/ping" }
                return EdgeInfo(
                    id = obj.optString("id").trim(),
                    host = host,
                    pingUrl = pingUrl,
                )
            }
        }
    }
}
