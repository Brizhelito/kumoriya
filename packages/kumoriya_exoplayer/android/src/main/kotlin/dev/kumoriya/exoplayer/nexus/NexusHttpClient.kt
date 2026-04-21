package dev.kumoriya.exoplayer.nexus

import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Shared OkHttp client factory for a nexus playback session.
 *
 * One HTTP stack powers everything: page scrape, stream metadata fetch,
 * CDN manifest/segment fetches and WebSocket upgrade. That way TLS
 * sessions, DNS cache and connection pools are reused across the session
 * — no warm-up cost between phases.
 */
internal object NexusHttpClient {
    fun build(cookieJar: NexusCookieJar): OkHttpClient {
        return OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .followRedirects(true)
            .followSslRedirects(true)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            // Long-lived streams (WebSocket + manifest + segments) demand
            // generous pools; the default of 5 stalls HLS playback because
            // Media3 fans out parallel segment fetches.
            .pingInterval(20, TimeUnit.SECONDS)
            .build()
    }
}
