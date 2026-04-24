package dev.kumoriya.exoplayer.http

import androidx.media3.datasource.okhttp.OkHttpDataSource
import okhttp3.ConnectionPool
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * Process-wide shared [OkHttpClient] for both playback and downloads.
 *
 * **Playback** consumes it through [asMedia3Factory] which returns an
 * [OkHttpDataSource.Factory] wired with the correct UA and headers.
 *
 * **Downloads** (future Fase 2+) will use [shared] directly for raw
 * OkHttp GET requests with Range resume.
 *
 * The [NexusHttpClient][dev.kumoriya.exoplayer.nexus.NexusHttpClient]
 * derives its per-session client from [shared] via `newBuilder()` so
 * TLS sessions, DNS cache and the connection pool are reused.
 */
object KumoriyaHttpClient {

    /**
     * Literal string `video_player_android` hard-codes when the caller
     * doesn't pass a User-Agent header. Tested against every source in
     * the Player Flow Playground — anything that worked with the legacy
     * `video_player`-backed engine still works with this UA.
     *
     * Resolvers are free to override by including `User-Agent` in their
     * headers; see [extractUserAgent].
     */
    const val DEFAULT_USER_AGENT: String = "ExoPlayer"

    /**
     * Singleton client. Connection pool is sized for HLS playback where
     * Media3 fans out parallel segment fetches across multiple hosts.
     */
    val shared: OkHttpClient = OkHttpClient.Builder()
        .connectionPool(ConnectionPool(20, 5, TimeUnit.MINUTES))
        .followRedirects(true)
        .followSslRedirects(true)
        .retryOnConnectionFailure(true)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    // ── Header helpers ──────────────────────────────────────────────

    /**
     * Case-insensitive extraction of a `User-Agent` entry from [headers].
     * Returns the custom value when present, [DEFAULT_USER_AGENT] otherwise.
     */
    fun extractUserAgent(headers: Map<String, String>): String {
        return headers.entries.firstOrNull {
            it.key.equals("User-Agent", ignoreCase = true)
        }?.value ?: DEFAULT_USER_AGENT
    }

    /**
     * Returns [headers] without any `User-Agent` key (case-insensitive).
     * Intended for [OkHttpDataSource.Factory.setDefaultRequestProperties]
     * because Media3 overrides request-property UA with the factory's own
     * `userAgent` field.
     */
    fun headersWithoutUserAgent(headers: Map<String, String>): Map<String, String> {
        return headers.filterKeys { !it.equals("User-Agent", ignoreCase = true) }
    }

    /**
     * Apply [headers] onto an OkHttp [Request.Builder], extracting
     * `User-Agent` with case-insensitive match and setting it separately.
     * All remaining headers are applied as `header(k, v)`.
     */
    fun applyHeaders(
        builder: Request.Builder,
        headers: Map<String, String>,
    ): Request.Builder {
        val ua = extractUserAgent(headers)
        builder.header("User-Agent", ua)
        for ((k, v) in headers) {
            if (!k.equals("User-Agent", ignoreCase = true)) {
                builder.header(k, v)
            }
        }
        return builder
    }

    // ── Media3 factory ──────────────────────────────────────────────

    /**
     * Build an [OkHttpDataSource.Factory] configured with [userAgent]
     * and [headers] for use by Media3 [MediaSource] factories.
     *
     * Cross-protocol redirects (http→https and back) are enabled
     * permanently because every HLS master→variant flip we ship
     * depends on it.
     */
    fun asMedia3Factory(
        headers: Map<String, String> = emptyMap(),
        userAgent: String = DEFAULT_USER_AGENT,
    ): OkHttpDataSource.Factory {
        return OkHttpDataSource.Factory(shared)
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(headersWithoutUserAgent(headers))
    }
}
