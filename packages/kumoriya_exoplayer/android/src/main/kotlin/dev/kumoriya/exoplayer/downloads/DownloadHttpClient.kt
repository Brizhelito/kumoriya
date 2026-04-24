package dev.kumoriya.exoplayer.downloads

import dev.kumoriya.exoplayer.http.KumoriyaHttpClient
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

/**
 * Thin download-specific wrapper over [KumoriyaHttpClient.shared].
 *
 * Adds per-request header injection and convenience methods for
 * range-resume GET requests used by [DirectDownloader] and
 * [HlsSegmentDownloader].
 */
internal object DownloadHttpClient {

    /** The shared [OkHttpClient] instance — same pool as the player. */
    val client: OkHttpClient get() = KumoriyaHttpClient.shared

    /**
     * Build a GET [Request] for [url] with [headers] applied via
     * [KumoriyaHttpClient.applyHeaders]. Optionally adds a `Range`
     * header for byte-range resume starting at [resumeOffset].
     */
    fun buildGet(
        url: String,
        headers: Map<String, String>,
        resumeOffset: Long = 0L,
    ): Request {
        val builder = Request.Builder().url(url).get()
        KumoriyaHttpClient.applyHeaders(builder, headers)
        if (resumeOffset > 0) {
            builder.header("Range", "bytes=$resumeOffset-")
        }
        return builder.build()
    }

    /**
     * Execute a GET request synchronously. Caller is responsible for
     * closing the [Response] (and its body).
     */
    fun execute(request: Request): Response = client.newCall(request).execute()
}
