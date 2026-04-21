package dev.kumoriya.exoplayer.nexus

import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * Mirror of Dart `NexusStreamDataFetcher`.
 *
 * Three-hop auth bootstrap:
 *   1. GET `/api/auth/session` on anime.nexus — warms up session cookies.
 *   2. POST `/api/anime/details/episode/view` on api.anime.nexus — tags
 *      the episode view, returns view cookies.
 *   3. GET `/api/anime/details/episode/stream` on api.anime.nexus — the
 *      actual payload: HLS master URL, video UUID, subtitles.
 *
 * Cookies from every hop accumulate in the shared [NexusCookieJar] so the
 * subsequent WS upgrade inherits them.
 */
internal class NexusStreamDataFetcher(private val http: OkHttpClient) {

    data class Subtitle(
        val src: String,
        val label: String,
        val srcLang: String?,
    )

    data class Result(
        val hlsUrl: String,
        val videoId: String,
        val subtitles: List<Subtitle>,
    )

    fun fetch(episodeId: String, fingerprint: String): Result {
        bootstrapAuthSession()
        bootstrapEpisodeView(episodeId = episodeId, fingerprint = fingerprint)

        var payload = requestStream(
            episodeId = episodeId,
            fingerprint = fingerprint,
        )
        if (payload == null) {
            // 403 recovery path: Dart replays the request after re-merging
            // cookies; OkHttp's cookie jar already absorbed the Set-Cookie
            // from the failed response, so a naked retry is enough here.
            payload = requestStream(
                episodeId = episodeId,
                fingerprint = fingerprint,
            )
        }
        if (payload == null) {
            throw NexusStreamDataException(
                "stream metadata endpoint rejected the request",
            )
        }

        val data = payload.optJSONObject("data")
            ?: throw NexusStreamDataException(
                "stream metadata response missing data object",
            )

        val hlsUrl = data.optString("hls").trim()
        if (hlsUrl.isEmpty()) {
            throw NexusStreamDataException(
                "stream metadata did not expose a valid HLS url",
            )
        }

        val videoId = extractVideoId(data, hlsUrl)
        if (videoId.isEmpty()) {
            throw NexusStreamDataException(
                "stream metadata did not expose a video id",
            )
        }

        val subs = parseSubtitles(data.optJSONArray("subtitles"))
        return Result(hlsUrl = hlsUrl, videoId = videoId, subtitles = subs)
    }

    private fun bootstrapAuthSession() {
        val req = Request.Builder()
            .url("${NexusConstants.MAIN_BASE}/api/auth/session")
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header("Accept", "application/json, text/plain, */*")
            .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
            .header("Referer", "${NexusConstants.MAIN_BASE}/")
            .header("sec-fetch-dest", "empty")
            .header("sec-fetch-mode", "cors")
            .header("sec-fetch-site", "same-origin")
            .build()
        http.newCall(req).execute().close()
    }

    private fun bootstrapEpisodeView(episodeId: String, fingerprint: String) {
        val body = JSONObject()
            .put("id", episodeId)
            .toString()
            .toRequestBody(JSON_MEDIA_TYPE)
        val req = Request.Builder()
            .url("${NexusConstants.API_BASE}/api/anime/details/episode/view")
            .post(body)
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header("Accept", "application/json, text/plain, */*")
            .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
            .header("Origin", NexusConstants.MAIN_BASE)
            .header("Referer", "${NexusConstants.MAIN_BASE}/")
            .header("sec-fetch-dest", "empty")
            .header("sec-fetch-mode", "cors")
            .header("sec-fetch-site", "same-site")
            .header("x-client-fingerprint", fingerprint)
            .header("x-fingerprint", fingerprint)
            .build()
        http.newCall(req).execute().close()
    }

    private fun requestStream(
        episodeId: String,
        fingerprint: String,
    ): JSONObject? {
        val url = "${NexusConstants.API_BASE}/api/anime/details/episode/stream" +
            "?id=$episodeId&fillers=true&recaps=true"
        val req = Request.Builder()
            .url(url)
            .header("User-Agent", NexusConstants.USER_AGENT)
            .header("Accept", "application/json, text/plain, */*")
            .header("Accept-Language", NexusConstants.ACCEPT_LANGUAGE)
            .header("Origin", NexusConstants.MAIN_BASE)
            .header("Referer", "${NexusConstants.MAIN_BASE}/")
            .header("sec-fetch-dest", "empty")
            .header("sec-fetch-mode", "cors")
            .header("sec-fetch-site", "same-site")
            .header("x-client-fingerprint", fingerprint)
            .header("x-fingerprint", fingerprint)
            .build()

        return http.newCall(req).execute().use { resp ->
            when (resp.code) {
                200 -> resp.body?.string()?.let { JSONObject(it) }
                403 -> null
                else -> throw NexusStreamDataException(
                    "stream metadata responded with status ${resp.code}",
                )
            }
        }
    }

    private fun extractVideoId(data: JSONObject, hlsUrl: String): String {
        data.optJSONObject("video")?.optString("id")?.trim()
            ?.takeIf { it.isNotEmpty() }?.let { return it }
        data.optJSONObject("video_meta")?.optString("id")?.trim()
            ?.takeIf { it.isNotEmpty() }?.let { return it }
        // Fallback: /api/anime/video/<id>/stream/video.m3u8
        val segments = hlsUrl.toHttpUrlOrNull()?.pathSegments.orEmpty()
        val idx = segments.indexOf("video")
        if (idx >= 0 && idx + 1 < segments.size) {
            val candidate = segments[idx + 1].trim()
            if (candidate.isNotEmpty() && candidate != "stream") return candidate
        }
        return ""
    }

    private fun parseSubtitles(raw: JSONArray?): List<Subtitle> {
        if (raw == null || raw.length() == 0) return emptyList()
        val out = ArrayList<Subtitle>(raw.length())
        for (i in 0 until raw.length()) {
            val obj = raw.optJSONObject(i) ?: continue
            val src = obj.optString("src").trim()
            if (src.isEmpty()) continue
            val label = obj.optString("label").trim().ifEmpty { "Subtitles" }
            val srcLang = obj.optString("srcLang").trim().ifEmpty { null }
            out.add(Subtitle(src = src, label = label, srcLang = srcLang))
        }
        return out
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json".toMediaType()
    }
}
