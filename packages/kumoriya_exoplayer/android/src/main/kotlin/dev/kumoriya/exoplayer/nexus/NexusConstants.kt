package dev.kumoriya.exoplayer.nexus

/**
 * Mirror of `kumoriya_resolver_anime_nexus/utils/nexus_constants.dart`.
 *
 * These values are the contract against anime.nexus and the api/us1.cdn
 * backends. Keep them synced with the Dart resolver until the Dart side
 * shrinks down to a thin shim (Fase 2 closure).
 */
internal object NexusConstants {
    const val MAIN_BASE = "https://anime.nexus"
    const val API_BASE = "https://api.anime.nexus"
    const val CDN_BASE = "https://us1.cdn.nexus"
    const val WS_HOST = "prd-socket.anime.nexus"

    /**
     * User-Agent faked as desktop Chrome — anime.nexus gates requests behind
     * browser-ish signals. The same string is used for HTTP + WebSocket
     * upgrades so fingerprinting stays consistent.
     */
    const val USER_AGENT =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/146.0.0.0 Safari/537.36"

    const val ACCEPT_LANGUAGE = "es-419,es;q=0.9,en;q=0.8"
}
