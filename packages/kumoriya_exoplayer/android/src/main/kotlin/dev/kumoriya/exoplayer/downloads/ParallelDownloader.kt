package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.coroutineContext

/**
 * Segmented parallel downloader with per-chunk resume.
 *
 * Strategy:
 * 1. Probe the URL with a single `Range: bytes=0-0` GET. If the server
 *    replies 206 with a `Content-Range: bytes 0-0/TOTAL` header, the
 *    resource is range-capable and we know its total size.
 * 2. Divide `[0, total)` into N chunks (N depends on the active network
 *    type — see [pickWorkerCount]). Persist the plan to `{file}.chunks.json`
 *    so a pause/cancel can resume each chunk from its last known offset.
 * 3. Launch N coroutines; each issues a `Range: bytes={start+done}-{end}`
 *    GET and streams into a shared [RandomAccessFile] via absolute-position
 *    writes (thread-safe on JDK [java.nio.channels.FileChannel]).
 * 4. Progress/manifest are flushed on a throttle so we don't thrash the
 *    event channel or the SD card.
 *
 * If the server does NOT support Range (probe returns 200 / no
 * Content-Range), fall back to the single-connection [DirectDownloader].
 */
internal object ParallelDownloader {

    private const val TAG = "ParallelDownloader"

    /** Don't bother splitting tiny files — overhead dwarfs the benefit. */
    private const val MIN_TOTAL_FOR_PARALLEL = 2L * 1024 * 1024 // 2 MiB

    /** Per-chunk read buffer. Same as the direct path. */
    private const val BUFFER_SIZE = 64 * 1024

    /** Progress/manifest flush throttle. */
    private const val FLUSH_INTERVAL_MS = 500L

    // ── Entry point ─────────────────────────────────────────────────────

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

        val finalFile = File(animeDir, params.fileName)
        val partialFile = File(animeDir, "${params.fileName}.partial")
        val manifestFile = File(animeDir, "${params.fileName}.chunks.json")

        // Fresh re-enqueue: wipe any stray final file. A .partial + manifest
        // pair is kept — that's the resume case.
        if (finalFile.exists() && !manifestFile.exists()) {
            Log.w(TAG, "${params.taskId}: overwriting existing ${finalFile.name}")
            finalFile.delete()
        }

        // Resume path: load the manifest and reuse its chunk plan.
        val resumed = loadManifest(manifestFile)
        val plan: ChunkPlan = if (resumed != null && resumed.url == params.url) {
            Log.i(
                TAG,
                "${params.taskId}: resuming with ${resumed.chunks.size} chunks, " +
                    "${resumed.chunks.sumOf { it.done }}/${resumed.total} bytes",
            )
            resumed
        } else {
            // Fresh start — probe total + Range support.
            val probe = probe(params)
            if (probe == null || !probe.supportsRange || probe.total <= 0) {
                Log.i(
                    TAG,
                    "${params.taskId}: server doesn't support Range " +
                        "(probe=$probe) — falling back to single connection",
                )
                DirectDownloader.download(params, eventSink)
                return
            }
            if (probe.total < MIN_TOTAL_FOR_PARALLEL) {
                Log.i(
                    TAG,
                    "${params.taskId}: small file (${probe.total}B) — " +
                        "using single connection",
                )
                DirectDownloader.download(params, eventSink)
                return
            }
            val workers = pickWorkerCount(context)
            Log.i(
                TAG,
                "${params.taskId}: parallel mode — total=${probe.total}B, " +
                    "workers=$workers",
            )
            val chunks = splitRanges(probe.total, workers)
            val fresh = ChunkPlan(url = params.url, total = probe.total, chunks = chunks)
            saveManifest(manifestFile, fresh)
            fresh
        }

        // Preallocate the target file so absolute-position writes don't
        // need to extend the file. Also avoids fragmentation on ext4.
        RandomAccessFile(partialFile, "rw").use { raf ->
            if (raf.length() < plan.total) raf.setLength(plan.total)
        }

        Log.i(
            TAG,
            "${params.taskId}: start → url=${params.url} partial=${partialFile.name}",
        )

        runWorkers(params, plan, partialFile, manifestFile, eventSink)

        // All workers finished → finalize.
        if (!partialFile.renameTo(finalFile)) {
            throw DownloadIOException(
                "Failed to rename ${partialFile.name} → ${finalFile.name}",
            )
        }
        manifestFile.delete()

        val size = finalFile.length()
        eventSink.emitProgress(params.taskId, size, size)
        eventSink.emitStatus(
            params.taskId,
            DownloadStatus.COMPLETED,
            filePath = finalFile.absolutePath,
            totalBytes = size,
        )
        Log.i(TAG, "${params.taskId}: completed → ${finalFile.absolutePath}")
    }

    // ── Worker orchestration ────────────────────────────────────────────

    private suspend fun runWorkers(
        params: DownloadParams,
        plan: ChunkPlan,
        partialFile: File,
        manifestFile: File,
        eventSink: DownloadEventSink,
    ) {
        // Shared RAF for positional writes. FileChannel.write(buf, pos) is
        // thread-safe for non-overlapping ranges.
        val raf = RandomAccessFile(partialFile, "rw")
        val channel = raf.channel

        val downloadedBytes = AtomicLong(plan.chunks.sumOf { it.done })
        val totalBytes = plan.total
        val manifestMutex = Mutex()
        val intervalStart = AtomicLong(System.currentTimeMillis())
        val intervalBytes = AtomicLong(0L)
        val lastEmitMs = AtomicLong(0L)
        val lastManifestFlushMs = AtomicLong(System.currentTimeMillis())

        try {
            coroutineScope {
                val jobs = plan.chunks.mapIndexed { index, chunk ->
                    async(Dispatchers.IO) {
                        downloadChunk(
                            params = params,
                            chunk = chunk,
                            chunkIndex = index,
                            plan = plan,
                            channel = channel,
                            manifestFile = manifestFile,
                            manifestMutex = manifestMutex,
                            downloadedBytes = downloadedBytes,
                            intervalBytes = intervalBytes,
                            intervalStart = intervalStart,
                            lastEmitMs = lastEmitMs,
                            lastManifestFlushMs = lastManifestFlushMs,
                            totalBytes = totalBytes,
                            eventSink = eventSink,
                        )
                    }
                }
                jobs.awaitAll()
            }
            // Final manifest flush + progress emit before caller renames.
            manifestMutex.withLock { saveManifest(manifestFile, plan) }
            channel.force(true)
        } finally {
            try { channel.close() } catch (_: Exception) {}
            try { raf.close() } catch (_: Exception) {}
            // On cancellation, leave .partial + manifest intact so resume
            // can pick up where we stopped.
            if (coroutineContext[Job]?.isCancelled == true) {
                manifestMutex.withLock { saveManifest(manifestFile, plan) }
            }
        }
    }

    private suspend fun downloadChunk(
        params: DownloadParams,
        chunk: Chunk,
        chunkIndex: Int,
        plan: ChunkPlan,
        channel: java.nio.channels.FileChannel,
        manifestFile: File,
        manifestMutex: Mutex,
        downloadedBytes: AtomicLong,
        intervalBytes: AtomicLong,
        intervalStart: AtomicLong,
        lastEmitMs: AtomicLong,
        lastManifestFlushMs: AtomicLong,
        totalBytes: Long,
        eventSink: DownloadEventSink,
    ) {
        if (chunk.done >= chunk.size) return // already complete

        val rangeStart = chunk.start + chunk.done
        val rangeEnd = chunk.end // inclusive
        val request = DownloadHttpClient.buildGet(
            url = params.url,
            headers = params.headers,
        ).newBuilder()
            .header("Range", "bytes=$rangeStart-$rangeEnd")
            .build()

        val call = DownloadHttpClient.client.newCall(request)
        coroutineContext[Job]?.invokeOnCompletion { cause ->
            if (cause != null) call.cancel()
        }

        val response = call.execute()
        response.use { resp ->
            if (resp.code != 206) {
                throw DownloadHttpException(
                    resp.code,
                    "Worker $chunkIndex expected 206, got ${resp.code}",
                )
            }
            val ct = resp.header("Content-Type").orEmpty()
            if (ct.startsWith("text/", ignoreCase = true) ||
                ct.contains("html", ignoreCase = true)
            ) {
                // Stale signed URL — caller should invalidate the partial.
                throw DownloadHttpException(
                    resp.code,
                    "Expired/invalid URL (Content-Type=$ct)",
                )
            }
            val body = resp.body
                ?: throw DownloadHttpException(resp.code, "Empty body")

            val buffer = ByteArray(BUFFER_SIZE)
            var writePos = rangeStart
            val source = body.source()

            while (true) {
                coroutineContext.ensureActive()

                val read = source.read(buffer, 0, BUFFER_SIZE)
                if (read == -1) break

                val bb = ByteBuffer.wrap(buffer, 0, read)
                var written = 0
                while (written < read) {
                    written += channel.write(bb, writePos + written)
                }

                writePos += read
                chunk.done += read
                downloadedBytes.addAndGet(read.toLong())
                intervalBytes.addAndGet(read.toLong())

                // Throttled progress + manifest flush. Using AtomicLong CAS
                // so at most one worker emits per tick.
                val now = System.currentTimeMillis()
                val lastEmit = lastEmitMs.get()
                if (now - lastEmit >= FLUSH_INTERVAL_MS &&
                    lastEmitMs.compareAndSet(lastEmit, now)
                ) {
                    val startMs = intervalStart.get()
                    val ib = intervalBytes.getAndSet(0L)
                    intervalStart.set(now)
                    val elapsed = (now - startMs).coerceAtLeast(1)
                    val bps = (ib * 1000L) / elapsed
                    eventSink.emitProgress(
                        params.taskId,
                        downloadedBytes.get(),
                        totalBytes,
                        bps,
                    )
                }

                val lastManifest = lastManifestFlushMs.get()
                if (now - lastManifest >= FLUSH_INTERVAL_MS &&
                    lastManifestFlushMs.compareAndSet(lastManifest, now)
                ) {
                    withContext(Dispatchers.IO) {
                        manifestMutex.withLock { saveManifest(manifestFile, plan) }
                    }
                }
            }
        }
    }

    // ── Probe ───────────────────────────────────────────────────────────

    private data class Probe(val supportsRange: Boolean, val total: Long)

    private suspend fun probe(params: DownloadParams): Probe? = withContext(Dispatchers.IO) {
        try {
            val req = DownloadHttpClient.buildGet(
                url = params.url,
                headers = params.headers,
            ).newBuilder()
                .header("Range", "bytes=0-0")
                .build()
            DownloadHttpClient.client.newCall(req).execute().use { resp ->
                if (resp.code != 206) return@withContext Probe(false, 0L)
                val cr = resp.header("Content-Range") ?: return@withContext Probe(false, 0L)
                // Content-Range: bytes 0-0/12345678
                val total = cr.substringAfter('/').trim().toLongOrNull()
                    ?: return@withContext Probe(false, 0L)
                Probe(true, total)
            }
        } catch (e: Exception) {
            Log.w(TAG, "${params.taskId}: probe failed: ${e.message}")
            null
        }
    }

    // ── Chunk planning ──────────────────────────────────────────────────

    private fun splitRanges(total: Long, workers: Int): MutableList<Chunk> {
        val chunks = mutableListOf<Chunk>()
        val size = total / workers
        var offset = 0L
        for (i in 0 until workers) {
            val start = offset
            val end = if (i == workers - 1) total - 1 else offset + size - 1
            chunks.add(Chunk(start = start, end = end, done = 0L))
            offset = end + 1
        }
        return chunks
    }

    /** Exposed for other downloaders (HLS, etc.) that share the same heuristic. */
    fun workerCountFor(context: Context): Int = pickWorkerCount(context)

    /**
     * Pick a worker count adapted to the active network. WiFi gets the full
     * 8-way fan-out; cellular LTE/5G gets 4; anything slower drops to 2.
     * Defaults to 4 when we can't query connectivity.
     */
    private fun pickWorkerCount(context: Context): Int {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager ?: return 4
        val network = cm.activeNetwork ?: return 4
        val caps = cm.getNetworkCapabilities(network) ?: return 4
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 8
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 8
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                // Rough proxy for 4G+/5G: these usually report >= 10 Mbps.
                val kbps = caps.linkDownstreamBandwidthKbps
                when {
                    kbps >= 10_000 -> 4
                    kbps >= 2_000 -> 2
                    else -> 1
                }
            }
            else -> 4
        }
    }

    // ── Manifest ────────────────────────────────────────────────────────

    private data class Chunk(val start: Long, val end: Long, var done: Long) {
        val size: Long get() = (end - start + 1)
    }

    private data class ChunkPlan(
        val url: String,
        val total: Long,
        val chunks: MutableList<Chunk>,
    )

    private fun loadManifest(file: File): ChunkPlan? {
        if (!file.exists()) return null
        return try {
            val json = JSONObject(file.readText())
            val total = json.getLong("total")
            val url = json.getString("url")
            val arr = json.getJSONArray("chunks")
            val chunks = mutableListOf<Chunk>()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                chunks.add(
                    Chunk(
                        start = o.getLong("start"),
                        end = o.getLong("end"),
                        done = o.getLong("done"),
                    ),
                )
            }
            ChunkPlan(url = url, total = total, chunks = chunks)
        } catch (e: Exception) {
            Log.w(TAG, "manifest load failed: ${e.message}")
            null
        }
    }

    private fun saveManifest(file: File, plan: ChunkPlan) {
        try {
            val arr = JSONArray()
            for (c in plan.chunks) {
                arr.put(
                    JSONObject()
                        .put("start", c.start)
                        .put("end", c.end)
                        .put("done", c.done),
                )
            }
            val json = JSONObject()
                .put("url", plan.url)
                .put("total", plan.total)
                .put("chunks", arr)
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.toString())
            if (!tmp.renameTo(file)) {
                tmp.delete()
            }
        } catch (e: Exception) {
            Log.w(TAG, "manifest save failed: ${e.message}")
        }
    }
}
