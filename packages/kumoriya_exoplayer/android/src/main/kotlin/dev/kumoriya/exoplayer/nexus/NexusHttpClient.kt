package dev.kumoriya.exoplayer.nexus

import dev.kumoriya.exoplayer.http.KumoriyaHttpClient
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Per-session OkHttp client factory for anime.nexus playback.
 *
 * Derives from [KumoriyaHttpClient.shared] via `newBuilder()` so the
 * connection pool, TLS sessions, DNS cache, timeouts, and redirect
 * policy are reused — only the session-specific [cookieJar] and
 * WebSocket [pingInterval] are overridden.
 */
internal object NexusHttpClient {
    fun build(cookieJar: NexusCookieJar): OkHttpClient {
        return KumoriyaHttpClient.shared.newBuilder()
            .cookieJar(cookieJar)
            // Long-lived WebSocket connections need a keep-alive ping;
            // the shared client does not set one because regular HTTP
            // requests don't need it.
            .pingInterval(20, TimeUnit.SECONDS)
            .build()
    }
}
