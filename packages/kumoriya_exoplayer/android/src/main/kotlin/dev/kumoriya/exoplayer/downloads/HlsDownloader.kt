package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.coroutineContext

/**
 * HLS (m3u8) download pipeline — Phase A.
 *
 * Flow:
 * 1. Fetch master playlist. If multivariant, pick the highest-bandwidth
 *    variant (or the one matching [DownloadParams.qualityLabel]).
 * 2. Fetch the media playlist and enumerate segments.
 * 3. Download all segments in parallel (bandwidth-aware permit count,
 *    same sizing as [ParallelDownloader]).
 * 4. Concatenate segments in order into a `.partial` file.
 * 5. Rename to final `<name>.ts` (Phase B will remux to `.mp4`).
 *
 * Resume is per-segment: a downloaded segment file in the tmp dir whose
 * size matches `Content-Length` is skipped on the next run. No byte-range
 * resume within a single segment — segments are small (~6s) so the cost
 * of re-downloading one is negligible.
 *
 * AES-128 segment encryption is **not** handled in Phase A. If the media
 * playlist declares `#EXT-X-KEY:METHOD=AES-128`, the download fails fast
 * with a clear error; anime.nexus / JKAnime HLS streams we target are
 * unencrypted.
 */
@UnstableApi
internal object HlsDownloader {

    private const val TAG = "HlsDownloader"
    private const val BUFFER_SIZE = 64 * 1024

    suspend fun download(
        context: Context,
        params: DownloadParams,
        eventSink: DownloadEventSink,
    ) {
        val animeDir = File(
            params.targetDir,
            StorageLayout.sanitize(params.animeTitle),
        )
        if (!animeDir.exists()) animeDir.mkdirs()

        val tmpDir = StorageLayout.tmpTaskDir(context, params.taskId)
        val segmentsDir = File(tmpDir, "segments")
        segmentsDir.mkdirs()

        // 1-2. Resolve master → variant → media playlist.
        val resolved = resolveMediaPlaylist(params)
        val media = resolved.playlist
        val segments = media.segments
        if (segments.isEmpty()) {
            throw DownloadIOException("HLS playlist has no segments")
        }

        // CMAF / fMP4 streams (AnimeAV1's Zilla CDN, etc.) declare an init
        // segment via #EXT-X-MAP that holds the `ftyp` + `moov` boxes.
        // Media segments only carry `moof` + `mdat`, so the init segment
        // MUST be prepended to the concatenated file or no extractor can
        // recognise the container — Transformer fails with
        // "UnrecognizedInputFormatException: NoDeclaredBrand" and the user
        // sees "Asset loader error". The Dart engine already handles this;
        // the Kotlin pipeline didn't until now.
        val initSeg = segments.firstOrNull { it.initializationSegment != null }
            ?.initializationSegment
        val isFmp4 = initSeg != null

        // Output is always `.mp4`. Both pipelines write to a tmp
        // concat file first, then transmux into the final `.mp4`:
        //   - fMP4 input  → concat init+segments verbatim, then run
        //     Mp4Transmuxer (Media3 FragmentedMp4Extractor →
        //     Mp4Muxer) to produce a flat MP4 with proper sample
        //     index tables (stco/stsc/stsz/stts/ctts) and preserved
        //     edit lists. Skips Transformer/ExoPlayer entirely so
        //     it's noticeably faster than the player-driven path.
        //   - MPEG-TS    → concat into tmp/concat.ts then run
        //     HlsRemuxer (Transformer + InAppMp4Muxer). Required
        //     because no player consumes raw MPEG-TS as `.mp4`.
        // The `params.remuxToMp4` toggle is intentionally ignored.
        val base = params.fileName.substringBeforeLast('.')
        val finalFile = File(animeDir, "$base.mp4")
        if (finalFile.exists()) {
            Log.w(TAG, "${params.taskId}: overwriting existing ${finalFile.name}")
            finalFile.delete()
        }
        // Concat target lives in tmp; transmux/remux reads then we wipe tmp.
        val concatTarget = File(tmpDir, if (isFmp4) "concat.mp4" else "concat.ts")
        // Build an encryption-key cache. HLS AES-128 streams declare
        // `#EXT-X-KEY:METHOD=AES-128,URI="..."` either once per playlist or
        // per group of segments; the parser attaches the effective
        // `fullSegmentEncryptionKeyUri` + optional `encryptionIV` to every
        // segment that key applies to. We fetch each distinct key URI once
        // and reuse the 16 bytes across segments.
        val keyCache = HashMap<String, ByteArray>()
        for (seg in segments) {
            val uri = seg.fullSegmentEncryptionKeyUri ?: continue
            if (keyCache.containsKey(uri)) continue
            val absolute = resolveUri(media.baseUri, uri)
            keyCache[uri] = fetchKeyBytes(absolute, params.headers)
        }
        if (keyCache.isNotEmpty()) {
            Log.i(
                TAG,
                "${params.taskId}: AES-128 enabled (${keyCache.size} unique key(s))",
            )
        }

        // Precompute total size from the variant bitrate × duration.
        // AVERAGE-BANDWIDTH (Format.averageBitrate) is more accurate than
        // BANDWIDTH (Format.bitrate, usually the peak); fall back to the
        // peak when the average wasn't declared. Units: bitrate is bps,
        // durationUs is µs, so bytes = bps * durUs / 8_000_000.
        val estimatedTotalBytes = run {
            val br = resolved.bitrateBps
            if (br <= 0 || media.durationUs <= 0) 0L
            else (br * media.durationUs) / 8_000_000L
        }

        Log.i(
            TAG,
            "${params.taskId}: ${segments.size} segments, " +
                "duration=${media.durationUs / 1_000_000}s, " +
                "estimatedSize=${estimatedTotalBytes}B (bitrate=${resolved.bitrateBps}bps)",
        )

        // 2b. Download the fMP4 init segment first if present. Cached in
        // segmentsDir so a resumed task doesn't re-fetch it. Honours the
        // optional EXT-X-MAP BYTERANGE attribute via a Range header.
        val initFile: File? = if (initSeg != null) {
            val f = File(segmentsDir, "init.mp4")
            if (!f.exists() || f.length() == 0L) {
                val initUrl = resolveUri(media.baseUri, initSeg.url)
                fetchInitSegment(
                    url = initUrl,
                    headers = params.headers,
                    outFile = f,
                    byteRangeOffset = initSeg.byteRangeOffset,
                    byteRangeLength = initSeg.byteRangeLength,
                )
                Log.i(
                    TAG,
                    "${params.taskId}: fMP4 init downloaded ${f.length()}B from $initUrl",
                )
            }
            f
        } else null

        // 3. Parallel segment download with bandwidth-aware permit count.
        val workers = ParallelDownloader.workerCountFor(context)
        val permits = Semaphore(workers)

        val totalSegments = segments.size
        val completedSegments = AtomicInteger(
            segments.withIndex().count { (i, _) -> segmentFile(segmentsDir, i).exists() },
        )
        val downloadedBytes = AtomicLong(0L)
        val intervalBytes = AtomicLong(0L)
        var intervalStart = System.currentTimeMillis()
        var lastEmit = 0L

        coroutineScope {
            val jobs = segments.mapIndexed { index, seg ->
                async(Dispatchers.IO) {
                    permits.withPermit {
                        coroutineContext.ensureActive()
                        val file = segmentFile(segmentsDir, index)
                        if (file.exists() && file.length() > 0) {
                            // Already downloaded on a prior run.
                            downloadedBytes.addAndGet(file.length())
                        } else {
                            val url = resolveUri(media.baseUri, seg.url)
                            // AES-128: build key+IV for the segment, if any.
                            // IV defaults to the big-endian media sequence
                            // number when not declared explicitly.
                            val keyBytes = seg.fullSegmentEncryptionKeyUri
                                ?.let(keyCache::get)
                            val ivBytes = if (keyBytes != null) {
                                seg.encryptionIV?.let(::parseHexIv)
                                    ?: defaultIvForSequence(
                                        media.mediaSequence + index,
                                    )
                            } else {
                                null
                            }
                            val bytes = fetchSegment(
                                url = url,
                                headers = params.headers,
                                outFile = file,
                                key = keyBytes,
                                iv = ivBytes,
                            )
                            downloadedBytes.addAndGet(bytes)
                            intervalBytes.addAndGet(bytes)
                        }
                        val done = completedSegments.incrementAndGet()

                        val now = System.currentTimeMillis()
                        if (now - lastEmit >= 500L) {
                            val elapsed = (now - intervalStart).coerceAtLeast(1)
                            val bps = (intervalBytes.getAndSet(0L) * 1000L) / elapsed
                            intervalStart = now
                            lastEmit = now
                            // If the master declared a bitrate, use a fixed
                            // bitrate×duration estimate — shown from the very
                            // first progress tick. Otherwise fall back to
                            // extrapolating from the current average segment.
                            //
                            // Both inputs are estimates and can end up BELOW
                            // the real byte count (bitrate declarations are
                            // commonly 10-20% off, and the per-segment
                            // extrapolation early on is noisy). Guard with
                            // coerceAtLeast so we never publish a total that
                            // would make the UI render >100% — the label on
                            // the downloads page divides directly without
                            // clamping and the persisted row survives app
                            // restarts with whatever we last emitted.
                            val downloadedNow = downloadedBytes.get()
                            val estTotal = if (estimatedTotalBytes > 0) {
                                estimatedTotalBytes
                            } else {
                                estimateTotal(downloadedNow, done, totalSegments)
                            }
                            val total = estTotal.coerceAtLeast(downloadedNow)
                            eventSink.emitProgress(
                                params.taskId,
                                downloadedNow,
                                total,
                                bps,
                            )
                        }
                    }
                }
            }
            jobs.awaitAll()
        }

        // 4. Concat init (fMP4 only) + segments in playlist order
        //    verbatim. We do NOT strip or patch anything here — the
        //    transmux step in 5a (Mp4Transmuxer) reads the raw fMP4
        //    via Media3's FragmentedMp4Extractor which knows how to
        //    handle multiple per-segment styp/sidx + tfdt continuity
        //    + edit lists. Manual surgery here is what made A/V drift
        //    in earlier revisions.
        Log.i(
            TAG,
            "${params.taskId}: concatenating ${segments.size} segments " +
                "(fmp4=$isFmp4, target=${concatTarget.name})",
        )
        concatTarget.parentFile?.mkdirs()
        FileOutputStream(concatTarget, false).use { out ->
            val buf = ByteArray(BUFFER_SIZE)
            initFile?.inputStream()?.use { ins ->
                while (true) {
                    val read = ins.read(buf)
                    if (read == -1) break
                    out.write(buf, 0, read)
                }
            }
            for (i in segments.indices) {
                coroutineContext.ensureActive()
                segmentFile(segmentsDir, i).inputStream().use { ins ->
                    while (true) {
                        val read = ins.read(buf)
                        if (read == -1) break
                        out.write(buf, 0, read)
                    }
                }
            }
            out.fd.sync()
        }

        // Snap progress to the full estimated size so the UI reaches 100%
        // cleanly right before the REMUXING state kicks in. Without this,
        // the bar freezes at the last sampled value (usually ~95-98%) and
        // then the status chip flips to "Procesando…" while the bar looks
        // mid-progress.
        if (estimatedTotalBytes > 0) {
            eventSink.emitProgress(
                params.taskId,
                estimatedTotalBytes,
                estimatedTotalBytes,
            )
        }

        if (isFmp4) {
            // 5a. fMP4 transmux to flat MP4 via Mp4Transmuxer.
            //     Pure extractor → muxer pipe, no decode/encode, no
            //     ExoPlayer player loop. Output has stco/stsc/stsz/
            //     stts indexes, preserved edit lists (AAC priming),
            //     and tfdt-continuous A/V sync — i.e. plays correctly
            //     in mpv / ExoPlayer / VLC / system player.
            eventSink.emitStatus(params.taskId, DownloadStatus.REMUXING)
            val t0 = System.currentTimeMillis()
            Mp4Transmuxer.transmux(
                input = concatTarget,
                output = finalFile,
                taskId = params.taskId,
            )
            Log.i(
                TAG,
                "${params.taskId}: fMP4 transmux completed in ${System.currentTimeMillis() - t0}ms",
            )
            tmpDir.deleteRecursively()
        } else {
            // 5b. MPEG-TS: wrap into MP4 via Media3 Transformer (transmux
            //     only — no re-encode). Uses InAppMp4Muxer for speed.
            HlsRemuxer.remux(
                context = context,
                taskId = params.taskId,
                input = concatTarget,
                output = finalFile,
                eventSink = eventSink,
            )
            tmpDir.deleteRecursively()
        }

        val size = finalFile.length()
        eventSink.emitProgress(params.taskId, size, size)
        eventSink.emitStatus(
            params.taskId,
            DownloadStatus.COMPLETED,
            filePath = finalFile.absolutePath,
            totalBytes = size,
        )
        Log.i(TAG, "${params.taskId}: completed \u2192 ${finalFile.absolutePath}")
    }

    // ── Playlist resolution ─────────────────────────────────────────────

    /** Result of the master → variant → media resolve chain. */
    private data class ResolvedPlaylist(
        val playlist: HlsMediaPlaylist,
        /** Picked variant bitrate in bits/s, or 0 when unknown. */
        val bitrateBps: Long,
    )

    private suspend fun resolveMediaPlaylist(params: DownloadParams): ResolvedPlaylist {
        val masterUri = android.net.Uri.parse(params.url)
        val parser = HlsPlaylistParser()
        val masterBody = fetchText(params.url, params.headers)
        val parsed = parser.parse(masterUri, masterBody.byteInputStream())

        return when (parsed) {
            // Direct media playlist — no bitrate metadata available.
            is HlsMediaPlaylist -> ResolvedPlaylist(parsed, bitrateBps = 0L)
            is HlsMultivariantPlaylist -> {
                val variant = pickVariant(parsed, params.qualityLabel)
                // AVERAGE-BANDWIDTH is more accurate than BANDWIDTH.
                val br = when {
                    variant.format.averageBitrate > 0 -> variant.format.averageBitrate.toLong()
                    variant.format.bitrate > 0 -> variant.format.bitrate.toLong()
                    else -> 0L
                }
                Log.i(
                    TAG,
                    "${params.taskId}: multivariant \u2192 picked " +
                        "${br}bps ${variant.format.width}x${variant.format.height}",
                )
                val variantUri = variant.url
                val variantBody = fetchText(variantUri.toString(), params.headers)
                when (val p = parser.parse(variantUri, variantBody.byteInputStream())) {
                    is HlsMediaPlaylist -> ResolvedPlaylist(p, bitrateBps = br)
                    else -> throw DownloadIOException(
                        "Expected media playlist at ${variantUri}, got ${p.javaClass.simpleName}",
                    )
                }
            }
            else -> throw DownloadIOException(
                "Unknown HLS playlist type: ${parsed.javaClass.simpleName}",
            )
        }
    }

    private fun pickVariant(
        playlist: HlsMultivariantPlaylist,
        qualityLabel: String?,
    ): HlsMultivariantPlaylist.Variant {
        val variants = playlist.variants
        if (variants.isEmpty()) error("Multivariant playlist with no variants")

        // Try exact quality match by vertical resolution (e.g. "1080p" \u2192 1080).
        if (qualityLabel != null) {
            val target = Regex("(\\d{3,4})").find(qualityLabel)?.groupValues?.get(1)?.toIntOrNull()
            if (target != null) {
                variants.firstOrNull { it.format.height == target }?.let { return it }
            }
        }
        // Fallback: highest bandwidth.
        return variants.maxBy { it.format.bitrate.coerceAtLeast(0) }
    }

    // ── HTTP helpers ────────────────────────────────────────────────────

    private suspend fun fetchText(url: String, headers: Map<String, String>): String =
        withContext(Dispatchers.IO) {
            val req = DownloadHttpClient.buildGet(url, headers)
            DownloadHttpClient.client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) {
                    throw DownloadHttpException(resp.code, "HTTP ${resp.code} for $url")
                }
                resp.body?.string() ?: throw DownloadHttpException(resp.code, "Empty body")
            }
        }

    private suspend fun fetchSegment(
        url: String,
        headers: Map<String, String>,
        outFile: File,
        key: ByteArray?,
        iv: ByteArray?,
    ): Long {
        val req = DownloadHttpClient.buildGet(url, headers)
        val call = DownloadHttpClient.client.newCall(req)
        coroutineContext[Job]?.invokeOnCompletion { cause ->
            if (cause != null) call.cancel()
        }
        val response = call.execute()
        response.use { resp ->
            if (!resp.isSuccessful) {
                throw DownloadHttpException(resp.code, "HTTP ${resp.code} for segment $url")
            }
            val body = resp.body ?: throw DownloadHttpException(resp.code, "Empty segment body")
            val tmp = File(outFile.parentFile, "${outFile.name}.partial")
            var written = 0L
            // When AES-128 is in effect, wrap the body in a CipherInputStream
            // so decryption happens on the fly — no extra buffering pass.
            val rawStream = body.byteStream()
            val stream = if (key != null && iv != null) {
                val cipher = javax.crypto.Cipher.getInstance("AES/CBC/PKCS5Padding")
                cipher.init(
                    javax.crypto.Cipher.DECRYPT_MODE,
                    javax.crypto.spec.SecretKeySpec(key, "AES"),
                    javax.crypto.spec.IvParameterSpec(iv),
                )
                javax.crypto.CipherInputStream(rawStream, cipher)
            } else {
                rawStream
            }
            FileOutputStream(tmp, false).use { out ->
                val buf = ByteArray(BUFFER_SIZE)
                stream.use { ins ->
                    while (true) {
                        coroutineContext.ensureActive()
                        val read = ins.read(buf)
                        if (read == -1) break
                        out.write(buf, 0, read)
                        written += read
                    }
                }
            }
            if (!tmp.renameTo(outFile)) {
                tmp.delete()
                throw DownloadIOException("Failed to finalize segment ${outFile.name}")
            }
            return written
        }
    }

    /**
     * Fetch the fMP4 init segment referenced by `#EXT-X-MAP`. When the
     * playlist supplies a `BYTERANGE` attribute (init bundled into a
     * sidecar), translates it into a `Range` HTTP header; otherwise
     * downloads the full URL.
     */
    private suspend fun fetchInitSegment(
        url: String,
        headers: Map<String, String>,
        outFile: File,
        byteRangeOffset: Long,
        byteRangeLength: Long,
    ): Long = withContext(Dispatchers.IO) {
        val extraHeaders = if (byteRangeLength > 0) {
            val end = byteRangeOffset + byteRangeLength - 1
            headers + ("Range" to "bytes=$byteRangeOffset-$end")
        } else {
            headers
        }
        val req = DownloadHttpClient.buildGet(url, extraHeaders)
        DownloadHttpClient.client.newCall(req).execute().use { resp ->
            // 200 = full body, 206 = honoured Range — both valid.
            if (resp.code != 200 && resp.code != 206) {
                throw DownloadHttpException(
                    resp.code,
                    "HTTP ${resp.code} for init segment $url",
                )
            }
            val body = resp.body
                ?: throw DownloadHttpException(resp.code, "Empty init body")
            val tmp = File(outFile.parentFile, "${outFile.name}.partial")
            var written = 0L
            FileOutputStream(tmp, false).use { out ->
                body.byteStream().use { ins ->
                    val buf = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val read = ins.read(buf)
                        if (read == -1) break
                        out.write(buf, 0, read)
                        written += read
                    }
                }
            }
            if (!tmp.renameTo(outFile)) {
                tmp.delete()
                throw DownloadIOException(
                    "Failed to finalize init segment ${outFile.name}",
                )
            }
            written
        }
    }

    /** Fetch the raw 16-byte AES key referenced by `#EXT-X-KEY`. */
    private suspend fun fetchKeyBytes(url: String, headers: Map<String, String>): ByteArray =
        withContext(Dispatchers.IO) {
            val req = DownloadHttpClient.buildGet(url, headers)
            DownloadHttpClient.client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) {
                    throw DownloadHttpException(resp.code, "HTTP ${resp.code} for key $url")
                }
                val bytes = resp.body?.bytes()
                    ?: throw DownloadHttpException(resp.code, "Empty key body")
                if (bytes.size != 16) {
                    throw DownloadIOException(
                        "Expected 16-byte AES key, got ${bytes.size}B at $url",
                    )
                }
                bytes
            }
        }

    /** Parse a hex IV, tolerating the optional `0x` prefix. */
    private fun parseHexIv(hex: String): ByteArray {
        val clean = hex.removePrefix("0x").removePrefix("0X")
        if (clean.length != 32) {
            throw DownloadIOException("Invalid HLS IV length: ${clean.length}")
        }
        val out = ByteArray(16)
        for (i in 0 until 16) {
            out[i] = clean.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }

    /**
     * Default IV per HLS spec when `#EXT-X-KEY` omits IV: 16-byte
     * big-endian representation of the segment's media sequence number.
     */
    private fun defaultIvForSequence(sequence: Long): ByteArray {
        val iv = ByteArray(16)
        for (i in 0 until 8) {
            iv[15 - i] = ((sequence shr (i * 8)) and 0xFF).toByte()
        }
        return iv
    }

    // ── Utilities ───────────────────────────────────────────────────────

    private fun segmentFile(dir: File, index: Int): File =
        File(dir, "seg_%06d.ts".format(index))

    private fun resolveUri(base: String, relative: String): String {
        val asUri = android.net.Uri.parse(relative)
        if (asUri.isAbsolute) return relative
        // Resolve relative URIs against the playlist's base using java.net.URI,
        // which handles `../` and absolute-path references correctly.
        val baseJu = java.net.URI.create(base)
        return baseJu.resolve(relative).toString()
    }

    /**
     * Before all segments finish we don't know the true total byte size;
     * extrapolate from the current average segment size to feed the UI a
     * reasonable running estimate.
     */
    private fun estimateTotal(currentBytes: Long, done: Int, total: Int): Long {
        if (done <= 0) return 0L
        val avg = currentBytes / done.coerceAtLeast(1)
        return avg * total
    }
}
