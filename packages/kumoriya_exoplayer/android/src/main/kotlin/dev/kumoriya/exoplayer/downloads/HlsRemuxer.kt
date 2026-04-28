package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.Transformer
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Transmuxes a local `.ts` file to `.mp4` using Media3's [Transformer].
 *
 * Transformer is strictly main-thread: [Transformer.start],
 * [Transformer.cancel] and [Transformer.getProgress] must all be called
 * from the looper Transformer was built on. This object constructs the
 * Transformer on the main looper and marshals every call through a
 * [Handler].
 *
 * The coroutine resumes when Transformer's listener fires `onCompleted`
 * or `onError`. Cancellation cancels the underlying Transformer.
 */
@UnstableApi
internal object HlsRemuxer {

    private const val TAG = "HlsRemuxer"
    private const val PROGRESS_POLL_MS = 500L

    /**
     * Remux [input] (a container Transformer can read — typically a
     * concatenated `.ts`) to [output] (MP4). Emits
     * [DownloadStatus.REMUXING] when the job starts and updates progress
     * periodically. On success returns the size of [output]; on failure
     * throws the underlying exception.
     */
    suspend fun remux(
        context: Context,
        taskId: String,
        input: File,
        output: File,
        eventSink: DownloadEventSink,
    ): Long {
        eventSink.emitStatus(taskId, DownloadStatus.REMUXING)
        Log.i(TAG, "$taskId: remux start ${input.name} → ${output.name}")
        if (output.exists()) output.delete()

        val main = Handler(Looper.getMainLooper())
        return suspendCancellableCoroutine { cont ->
            // Transformer must be built + driven on its looper. Build it
            // on main and keep the reference to it in closure state.
            val pending = PendingRemux(cont, eventSink, taskId)
            main.post {
                try {
                    // No `setVideoMimeType` / `setAudioMimeType`: we want
                    // Transformer to KEEP whatever codec the input already
                    // uses and just re-container the compressed bitstream.
                    // Hardcoding H.264 here would silently re-encode AV1
                    // streams (the whole point of the animeav1 source is
                    // that they ship AV1 — MP4 supports it via `av1C`).
                    // Transformer transmuxes when the muxer accepts the
                    // input codec and falls back to re-encode only when
                    // it cannot, which is the correct default for a
                    // codec-agnostic download pipeline.
                    // Use Media3's pure-Kotlin/Java in-app MP4 muxer
                    // instead of the system MediaMuxer. The system muxer
                    // round-trips through AOSP's framework-level writer
                    // which is noticeably slower for transmux workloads
                    // (observed 30s for 170MB AV1 fMP4 on a mid-range
                    // device); InAppMp4Muxer is typically 2-4× faster
                    // because it skips the framework hop and shares
                    // buffers with Transformer's pipeline.
                    val transformer = Transformer.Builder(context)
                        .setMuxerFactory(InAppMp4Muxer.Factory())
                        .addListener(pending.listener)
                        .build()
                    pending.transformer = transformer

                    val mediaItem = MediaItem.fromUri(Uri.fromFile(input))
                    transformer.start(mediaItem, output.absolutePath)

                    // We intentionally do NOT push remux progress onto the
                    // download progress stream — the UI bar is sized in
                    // bytes and jumping to 0/100 would regress the bar
                    // from "downloading finished" back to 0%. The REMUXING
                    // status emitted above is enough for the UI to show
                    // a "procesando..." state; byte-level progress stays
                    // frozen at last-known until COMPLETED.
                } catch (t: Throwable) {
                    pending.finished = true
                    cont.resumeWithException(t)
                }
            }

            cont.invokeOnCancellation {
                main.post {
                    pending.finished = true
                    try {
                        pending.transformer?.cancel()
                    } catch (_: Throwable) {/* ignore */}
                    if (output.exists()) output.delete()
                }
            }
        }.also {
            Log.i(TAG, "$taskId: remux done → size=${output.length()}B")
        }
    }

    /**
     * Holds the continuation + Transformer listener together so progress
     * polling and listener callbacks can share a `finished` flag and
     * guard against double-resume.
     */
    private class PendingRemux(
        private val cont: CancellableContinuation<Long>,
        private val eventSink: DownloadEventSink,
        private val taskId: String,
    ) {
        var transformer: Transformer? = null

        @Volatile
        var finished: Boolean = false

        val listener = object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                if (finished) return
                finished = true
                // ExportResult exposes durationMs, fileSizeBytes, etc. —
                // caller will rename/size through File APIs.
                Log.i(
                    TAG,
                    "$taskId: Transformer onCompleted size=${exportResult.fileSizeBytes}B " +
                        "duration=${exportResult.durationMs}ms frames=${exportResult.videoFrameCount}",
                )
                cont.resume(exportResult.fileSizeBytes)
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                if (finished) return
                finished = true
                Log.e(TAG, "$taskId: Transformer onError", exportException)
                cont.resumeWithException(exportException)
            }
        }
    }
}
