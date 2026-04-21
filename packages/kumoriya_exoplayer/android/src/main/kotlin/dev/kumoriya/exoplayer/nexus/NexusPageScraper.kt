package dev.kumoriya.exoplayer.nexus

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Mirror of Dart `NexusPageScraper`.
 *
 * Reads the public watch page HTML and pulls out the two values needed for
 * the rest of the session:
 *  - `episodeId` — UUIDv4, also present in the URL path as a fallback.
 *  - `attestRef` — 64-char hex attestation, the `ref` passed to the WS
 *     auth handshake. Without it the WS auth returns
 *     `Authentication failed`.
 *
 * The call also primes the cookie jar with whatever `Set-Cookie` headers
 * the watch page returns (Cloudflare + `sid` refresh + locale).
 */
internal class NexusPageScraper(private val http: OkHttpClient) {

    data class Result(val episodeId: String, val attestRef: String)

    fun scrape(watchUrl: String): Result {
        val httpUrl = watchUrl.toHttpUrl()
        val req = Request.Builder()
            .url(httpUrl)
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header(
                "Accept",
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            )
            .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
            .header("Origin", NexusConstants.MAIN_BASE)
            .header("Referer", "${NexusConstants.MAIN_BASE}/")
            .header("sec-fetch-dest", "document")
            .header("sec-fetch-mode", "navigate")
            .header("sec-fetch-site", "none")
            .build()

        val html = http.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) {
                throw NexusScrapeException(
                    "watch page returned status=${resp.code}",
                )
            }
            resp.body?.string().orEmpty()
        }

        if (html.isBlank()) {
            throw NexusScrapeException("watch page returned empty HTML")
        }

        val episodeId = episodeIdFromUrl(watchUrl)
            ?: EPISODE_ID_RE.find(html)?.groupValues?.getOrNull(1)
            ?: throw NexusScrapeException(
                "watch page did not expose an episode id",
            )

        val attestRef = ATTEST_REF_RE.find(html)?.groupValues?.getOrNull(1)
            ?: throw NexusScrapeException(
                "watch page did not expose attestRef",
            )

        return Result(episodeId = episodeId, attestRef = attestRef)
    }

    private fun episodeIdFromUrl(url: String): String? {
        val http = url.toHttpUrl()
        val segments = http.pathSegments
        val idx = segments.indexOf("watch")
        if (idx < 0 || idx + 1 >= segments.size) return null
        val candidate = segments[idx + 1].lowercase()
        return if (UUID_RE.matches(candidate)) candidate else null
    }

    companion object {
        private val UUID_RE =
            Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        private val ATTEST_REF_RE = Regex("""attestRef:"([0-9a-f]{64})"""")
        // Kotlin raw strings still interpolate `$…`; escape it via
        // `${'$'}` so the regex sees a literal dollar sign.
        private val EPISODE_ID_RE =
            Regex("""episode:${'$'}R\[\d+\]=\{id:"([0-9a-f-]{36})"""")
    }
}
