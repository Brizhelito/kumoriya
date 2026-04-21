package dev.kumoriya.exoplayer.nexus

import android.net.Uri
import android.util.Log
import androidx.media3.datasource.BaseDataSource
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSourceException
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.io.InputStream

/**
 * Media3 [DataSource] that replaces the Dart loopback proxy.
 *
 * For each fetch Media3 issues we classify the URI via
 * [NexusPlaybackSession.classify] and:
 *  - MASTER manifests are fetched unsigned with browser headers.
 *  - VARIANT manifests acquire a `manifest` token from the WS and append
 *    `?token=…&requestType=manifest&sessionId=…` before the OkHttp GET.
 *  - SEGMENT / init files acquire a `segment` token via the WS using the
 *    `(variant, segmentIndex, track)` triplet extracted from the path.
 *
 * Everything Media3 needs — manifest parsing, ABR, seek windowing,
 * prefetch, retry — stays inside Media3. This DataSource is purely the
 * signing + HTTP layer.
 */
internal class NexusDataSource(
    private val session: NexusPlaybackSession,
) : BaseDataSource(/* isNetwork = */ true) {

    private var responseBody: okhttp3.ResponseBody? = null
    private var bodyStream: InputStream? = null
    private var currentUri: Uri? = null
    private var bytesRead: Long = 0
    private var bytesToRead: Long = 0
    private var opened = false

    override fun open(dataSpec: DataSpec): Long {
        transferInitializing(dataSpec)
        currentUri = dataSpec.uri

        val kind = session.classify(dataSpec.uri)
        Log.d(
            LOG_TAG,
            "open kind=$kind uri=${dataSpec.uri} pos=${dataSpec.position} " +
                "len=${dataSpec.length}",
        )

        // Retry budget: at most one edge rotation per open() call so we
        // can never turn a legitimate 403 into a spin.
        var rotationsLeft = 1
        while (true) {
            val signedUri = try {
                signForCurrentEdge(kind, dataSpec.uri)
            } catch (t: Throwable) {
                Log.e(LOG_TAG, "signing failed uri=${dataSpec.uri}", t)
                throw HttpDataSource.HttpDataSourceException.createForIOException(
                    IOException("Nexus signing failed: ${t.message}", t),
                    dataSpec,
                    HttpDataSource.HttpDataSourceException.TYPE_OPEN,
                )
            }

            val headers = when (kind) {
                NexusPlaybackSession.UrlKind.MASTER ->
                    session.browserFetchHeaders()
                else -> session.cdnRequestHeaders()
            }

            val requestBuilder = Request.Builder().url(signedUri.toString())
            for ((k, v) in headers) {
                requestBuilder.header(k, v)
            }
            val positionRange = buildRangeHeader(dataSpec)
            if (positionRange != null) {
                requestBuilder.header("Range", positionRange)
            }

            if (kind != NexusPlaybackSession.UrlKind.MASTER) {
                val httpUrl = signedUri.toString().toHttpUrlOrNull()
                val cookieHeader =
                    httpUrl?.let { session.cookieJar.asCookieHeader(it) }
                Log.d(
                    LOG_TAG,
                    "fetch kind=$kind signed=$signedUri " +
                        "cookies=${cookieHeader ?: "(none)"} " +
                        "headers=${headers.keys}",
                )
            }
            val response: Response = try {
                session.http.newCall(requestBuilder.build()).execute()
            } catch (e: IOException) {
                // InterruptedIOException is expected during ABR switches
                // and when ExoPlayer cancels a loader — log at INFO so it
                // does not look like a failure mode to anyone reading
                // logcat.
                if (e is java.io.InterruptedIOException) {
                    Log.i(LOG_TAG, "fetch cancelled uri=$signedUri kind=$kind")
                } else {
                    Log.e(
                        LOG_TAG,
                        "fetch IO failure uri=$signedUri kind=$kind",
                        e,
                    )
                }
                throw HttpDataSource.HttpDataSourceException.createForIOException(
                    e,
                    dataSpec,
                    HttpDataSource.HttpDataSourceException.TYPE_OPEN,
                )
            }

            if (!response.isSuccessful) {
                val code = response.code
                val body = try {
                    response.body?.string().orEmpty()
                } catch (_: Throwable) { "" }
                val headerSummary = INTERESTING_RESPONSE_HEADERS
                    .mapNotNull { name ->
                        val v = response.header(name) ?: return@mapNotNull null
                        "$name=$v"
                    }
                    .joinToString(", ")
                val bodySnippet = body.take(300)
                    .replace('\n', ' ').replace('\r', ' ')
                response.close()
                Log.e(
                    LOG_TAG,
                    "fetch HTTP $code kind=$kind uri=$signedUri body=$bodySnippet",
                )
                session.onDebugLog?.invoke(
                    "[anime-nexus.cdn] HTTP $code kind=$kind uri=$signedUri " +
                        "resp-headers={$headerSummary} body=$bodySnippet",
                )

                // Rotate edge + retry when the CDN claims the token is
                // invalid: tokens are globally valid, so a rejection here
                // means the WAF fingerprinted the edge/IP pair. Master
                // manifests live on api.anime.nexus and are not served
                // by the CDN fleet, so there is no edge to rotate to.
                val isTokenRejection = code == 403 &&
                    body.contains("Token validation failed", ignoreCase = true)
                if (isTokenRejection &&
                    kind != NexusPlaybackSession.UrlKind.MASTER
                ) {
                    val rejectedEdge = signedUri.host.orEmpty()
                    val burned = session.recordTokenRejection(rejectedEdge)
                    // Two distinct edges rejecting the same-shaped token
                    // error means the client IP is globally flagged.
                    // Fail fast with a typed error so the UI can surface
                    // 'try VPN' instead of spinning through 16 edges.
                    if (session.isLikelyWafBlocked()) {
                        session.onDebugLog?.invoke(
                            "[anime-nexus.cdn] waf-blocked " +
                                "burned-edges=$burned — aborting rotation",
                        )
                        throw HttpDataSource.HttpDataSourceException
                            .createForIOException(
                                IOException(
                                    NexusBlockedByWafException(
                                        "CDN WAF rejected tokens on " +
                                            "$burned edges; IP likely banned",
                                    ),
                                ),
                                dataSpec,
                                HttpDataSource.HttpDataSourceException.TYPE_OPEN,
                            )
                    }
                    if (rotationsLeft > 0 &&
                        session.rotateEdge(
                            "HTTP $code on $kind uri=${dataSpec.uri}",
                        )
                    ) {
                        rotationsLeft--
                        continue
                    }
                }

                throw HttpDataSource.InvalidResponseCodeException(
                    code,
                    response.message,
                    /* cause = */ null,
                    response.headers.toMultimap(),
                    dataSpec,
                    /* responseBody = */ body.toByteArray(),
                )
            }

            val body = response.body ?: run {
                response.close()
                throw HttpDataSource.HttpDataSourceException.createForIOException(
                    IOException("empty body for ${signedUri}"),
                    dataSpec,
                    HttpDataSource.HttpDataSourceException.TYPE_OPEN,
                )
            }
            responseBody = body
            bodyStream = body.byteStream()
            val reportedLength = body.contentLength()
            bytesToRead = if (dataSpec.length != C_LENGTH_UNSET) {
                dataSpec.length
            } else if (reportedLength >= 0) {
                reportedLength
            } else {
                C_LENGTH_UNSET
            }
            bytesRead = 0
            opened = true
            transferStarted(dataSpec)
            return bytesToRead
        }
    }

    private fun signForCurrentEdge(
        kind: NexusPlaybackSession.UrlKind,
        uri: Uri,
    ): Uri = when (kind) {
        NexusPlaybackSession.UrlKind.MASTER -> uri
        NexusPlaybackSession.UrlKind.VARIANT_MANIFEST ->
            signVariant(session.rewriteToEdge(uri))
        NexusPlaybackSession.UrlKind.INIT ->
            signInit(session.rewriteToEdge(uri))
        NexusPlaybackSession.UrlKind.SEGMENT ->
            signSegment(session.rewriteToEdge(uri))
        NexusPlaybackSession.UrlKind.UNKNOWN ->
            throw NexusTransportException("Unclassified nexus URL: $uri")
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        val stream = bodyStream
            ?: throw DataSourceException(
                IOException("Nexus DataSource read before open"),
                DataSourceException.POSITION_OUT_OF_RANGE,
            )

        val remaining = if (bytesToRead == C_LENGTH_UNSET) {
            length
        } else {
            val left = bytesToRead - bytesRead
            if (left <= 0L) return C_RESULT_END_OF_INPUT
            minOf(length.toLong(), left).toInt()
        }

        val n = try {
            stream.read(buffer, offset, remaining)
        } catch (e: IOException) {
            throw HttpDataSource.HttpDataSourceException.createForIOException(
                e,
                DataSpec.Builder()
                    .setUri(currentUri ?: Uri.EMPTY)
                    .build(),
                HttpDataSource.HttpDataSourceException.TYPE_READ,
            )
        }
        if (n == -1) return C_RESULT_END_OF_INPUT
        bytesRead += n
        bytesTransferred(n)
        return n
    }

    override fun getUri(): Uri? = currentUri

    override fun close() {
        val stream = bodyStream
        bodyStream = null
        val body = responseBody
        responseBody = null
        currentUri = null
        bytesRead = 0
        bytesToRead = 0
        val wasOpen = opened
        opened = false
        try {
            stream?.close()
        } catch (_: IOException) {
            // swallow: nothing actionable once close is under way.
        }
        body?.close()
        if (wasOpen) {
            transferEnded()
        }
    }

    // ── Signing helpers ──────────────────────────────────────────────

    private fun signVariant(uri: Uri): Uri {
        // Variant manifests use a manifest token and advertise themselves
        // via requestType=manifest — mirroring the Dart _signedManifestUrl.
        val token = session.getManifestToken(uri.path.orEmpty())
        return uri.buildUpon()
            .clearQuery()
            .appendQueryParameter("token", token.token)
            .appendQueryParameter("requestType", "manifest")
            .appendQueryParameter("sessionId", session.sessionId)
            .build()
    }

    private fun signInit(uri: Uri): Uri {
        // Init segments (fMP4) are signed with a MANIFEST token but fetched
        // as a `segment` requestType — exactly what the Dart proxy does in
        // _fetchManifestProtectedBytes for `<base>_<variant>_init-<track>.mp4`.
        val token = session.getManifestToken(uri.path.orEmpty())
        return uri.buildUpon()
            .clearQuery()
            .appendQueryParameter("token", token.token)
            .appendQueryParameter("requestType", "segment")
            .appendQueryParameter("sessionId", session.sessionId)
            .build()
    }

    private fun signSegment(uri: Uri): Uri {
        val path = uri.path.orEmpty()
        val match = SEGMENT_RE.find(path)
            ?: throw NexusTransportException(
                "segment path does not match nexus layout: $path",
            )
        val variant = match.groupValues[1]
        val segmentIndex = match.groupValues[2].toInt()
        val track = match.groupValues[3].toInt()
        val token = session.getSegmentToken(
            variant = variant,
            segmentIndex = segmentIndex,
            track = track,
        )
        return uri.buildUpon()
            .clearQuery()
            .appendQueryParameter("token", token.token)
            .appendQueryParameter("requestType", "segment")
            .appendQueryParameter("sessionId", session.sessionId)
            .build()
    }

    private fun buildRangeHeader(dataSpec: DataSpec): String? {
        if (dataSpec.position == 0L && dataSpec.length == C_LENGTH_UNSET) {
            return null
        }
        val end = if (dataSpec.length == C_LENGTH_UNSET) {
            ""
        } else {
            (dataSpec.position + dataSpec.length - 1).toString()
        }
        return "bytes=${dataSpec.position}-$end"
    }

    companion object {
        private const val LOG_TAG = "NexusDataSource"
        private const val C_LENGTH_UNSET: Long = -1L
        private const val C_RESULT_END_OF_INPUT: Int = -1
        // Segment path layout: <base>_<variant>_<NNNN>-<track>.m4s
        //   e.g. ...mkv_1600_0175-1.m4s  → variant=1600 seg=175 track=1
        // Media3 always requests .m4s for media segments and .mp4 only for
        // init (routed to signInit), so we do not need to match .mp4 here.
        private val SEGMENT_RE = Regex(
            """_([0-9]+)_([0-9]{4})-([0-9]+)\.m4s$""",
            RegexOption.IGNORE_CASE,
        )
        // Keep this list tight: we want just enough to fingerprint whether
        // the 4xx/5xx is Cloudflare bot-challenge, the Nexus backend, or a
        // bare nginx from an edge host that does not serve this variant.
        private val INTERESTING_RESPONSE_HEADERS = listOf(
            "content-type",
            "server",
            "cf-ray",
            "cf-cache-status",
            "x-cache",
            "x-amz-cf-id",
            "via",
            "x-nexus-edge",
            "x-nexus-variant",
            "www-authenticate",
        )
    }
}

internal class NexusDataSourceFactory(
    private val session: NexusPlaybackSession,
) : DataSource.Factory {
    override fun createDataSource(): DataSource = NexusDataSource(session)
}
