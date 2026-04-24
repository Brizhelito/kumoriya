package dev.kumoriya.exoplayer.downloads

import android.util.Log
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.coroutineContext

/**
 * Downloads a direct (non-HLS) file via OkHttp with byte-range resume.
 *
 * Flow:
 * 1. Stream to `{targetDir}/{animeTitle}/{fileName}.partial`.
 * 2. If `.partial` already exists → send `Range: bytes={len}-` for resume.
 * 3. On completion → rename `.partial` → final name.
 * 4. No tmp dir, no remux.
 *
 * This is a **suspend function** — cancellation is cooperative via
 * [ensureActive] checks in the read loop.
 */
internal object DirectDownloader {

    private const val TAG = "DirectDownloader"
    private const val BUFFER_SIZE = 64 * 1024 // 64 KiB
    private const val PROGRESS_THROTTLE_MS = 500L

    /**
     * Run the download to completion. Throws on HTTP error or IO failure.
     * Cancellation propagates via [coroutineContext] checks.
     */
    suspend fun download(
        params: DownloadParams,
        eventSink: DownloadEventSink,
    ) {
        Log.i(
            TAG,
            "${params.taskId}: start download → targetDir=${params.targetDir} " +
                "anime='${params.animeTitle}' file='${params.fileName}' " +
                "url=${params.url}",
        )

        val animeDir = File(
            params.targetDir,
            StorageLayout.sanitize(params.animeTitle),
        )
        if (!animeDir.exists()) animeDir.mkdirs()

        val finalFile = File(animeDir, params.fileName)
        val partialFile = File(animeDir, "${params.fileName}.partial")

        // If a leftover final file exists from a previous aborted attempt,
        // remove it — the user explicitly re-enqueued, so we want a fresh
        // download. (Dart already short-circuits re-enqueue when the task
        // is still in the store, so reaching here means the user wants
        // a new copy.)
        if (finalFile.exists()) {
            Log.w(TAG, "${params.taskId}: overwriting existing ${finalFile.name}")
            finalFile.delete()
        }

        val resumeOffset = if (partialFile.exists()) partialFile.length() else 0L

        val request = DownloadHttpClient.buildGet(
            url = params.url,
            headers = params.headers,
            resumeOffset = resumeOffset,
        )

        // Create the Call manually so we can cancel it on coroutine
        // cancellation. Blocking `source.read()` ignores Job.cancel()
        // until the next ensureActive() check — which on slow connections
        // can be 30+ seconds. call.cancel() forces the read to throw
        // IOException immediately.
        val call = DownloadHttpClient.client.newCall(request)
        coroutineContext[Job]?.invokeOnCompletion { cause ->
            if (cause != null) call.cancel()
        }

        val response = call.execute()
        response.use { resp ->
            val code = resp.code
            if (code == 416) {
                // Range not satisfiable — likely already complete.
                Log.w(TAG, "${params.taskId}: 416 — treating partial as complete")
                partialFile.renameTo(finalFile)
                eventSink.emitStatus(params.taskId, DownloadStatus.COMPLETED)
                return
            }

            if (!resp.isSuccessful) {
                throw DownloadHttpException(code, "HTTP $code for ${params.url}")
            }

            // Reject expired / redirect-landing pages. CDNs like Mediafire
            // return HTML when the signed URL has expired — writing that
            // into a .mp4 produces an unplayable file.
            val contentType = resp.header("Content-Type").orEmpty()
            if (contentType.startsWith("text/", ignoreCase = true) ||
                contentType.contains("html", ignoreCase = true)
            ) {
                // Expired URL — drop the stale partial so the next attempt
                // starts from scratch with a fresh link.
                partialFile.delete()
                throw DownloadHttpException(
                    code,
                    "Expired/invalid URL (Content-Type=$contentType)",
                )
            }

            val body = resp.body
                ?: throw DownloadHttpException(code, "Empty response body")

            // Total size: for 206, add resume offset; for 200, use content-length.
            val contentLength = body.contentLength()
            val totalBytes = when (code) {
                206 -> resumeOffset + (if (contentLength > 0) contentLength else 0L)
                else -> if (contentLength > 0) contentLength else -1L
            }

            // If server returned 200 (ignoring Range), restart from zero.
            val append = code == 206
            val fos = FileOutputStream(partialFile, append)

            fos.use { out ->
                val buffer = ByteArray(BUFFER_SIZE)
                var written = if (append) resumeOffset else 0L
                var lastEmitMs = 0L
                var intervalBytes = 0L
                var intervalStartMs = System.currentTimeMillis()

                val source = body.source()
                while (true) {
                    coroutineContext.ensureActive()

                    val read = source.read(buffer, 0, BUFFER_SIZE)
                    if (read == -1) break

                    out.write(buffer, 0, read)
                    written += read
                    intervalBytes += read

                    val now = System.currentTimeMillis()
                    val elapsed = now - lastEmitMs
                    if (elapsed >= PROGRESS_THROTTLE_MS) {
                        val intervalMs = now - intervalStartMs
                        val bps = if (intervalMs > 0) {
                            (intervalBytes * 1000L) / intervalMs
                        } else 0L

                        eventSink.emitProgress(
                            params.taskId,
                            written,
                            totalBytes,
                            bps,
                        )
                        lastEmitMs = now
                        intervalBytes = 0L
                        intervalStartMs = now
                    }
                }

                // Final flush + fsync.
                out.fd.sync()
            }

            // Rename .partial → final.
            if (!partialFile.renameTo(finalFile)) {
                throw DownloadIOException(
                    "Failed to rename ${partialFile.name} → ${finalFile.name}",
                )
            }

            // Emit final progress + completed with the final file path
            // so Dart can persist it in Drift for offline playback.
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
    }
}

// ── Exceptions ───────────────────────────────────────────────────────────────

internal class DownloadHttpException(
    val httpCode: Int,
    message: String,
) : Exception(message)

internal class DownloadIOException(message: String) : Exception(message)
