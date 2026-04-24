package dev.kumoriya.exoplayer.downloads

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridge between the download engine (IO threads) and Flutter's
 * [EventChannel] (main thread).
 *
 * All `emit*` methods are safe to call from any thread — they post to
 * the main looper before touching the [EventChannel.EventSink].
 */
internal class DownloadEventSink : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Per-task latest snapshot. Populated on every emit* call and
     * consumed by `DownloadEngine.snapshotForSync()` so Flutter can
     * reconcile its Drift state after a detach → reattach cycle during
     * which all channel events were dropped (sink was null).
     *
     * Entries survive terminal statuses (completed/failed/cancelled)
     * until the next `enqueue` with the same taskId overwrites them —
     * required so that "task completed while Flutter was detached"
     * still surfaces through the next sync.
     */
    internal data class Snapshot(
        val taskId: String,
        var status: DownloadStatus,
        var downloadedBytes: Long,
        var totalBytes: Long,
        var bytesPerSecond: Long,
        var filePath: String?,
        var errorMessage: String?,
        var errorCode: String?,
    )

    private val snapshots = java.util.concurrent.ConcurrentHashMap<String, Snapshot>()

    fun allSnapshots(): List<Snapshot> = snapshots.values.toList()

    fun forgetSnapshot(taskId: String) {
        snapshots.remove(taskId)
    }

    /**
     * Flutter-scoped callback invoked when a task finishes. Re-assigned
     * each time [DownloadChannels] attaches; set to a no-op on detach.
     */
    var onTaskFinished: (String) -> Unit = {}

    /**
     * Process-scoped counterpart of [onTaskFinished]. Registered once
     * by [DownloadCore] and never re-assigned; drives the always-on
     * FGS stop debounce so the service is torn down when the last
     * download completes even if Flutter is detached.
     */
    var onTaskFinishedCore: (String) -> Unit = {}

    /** Fires both callbacks. Invoked by the engine's `finally` block. */
    fun notifyTaskFinished(taskId: String) {
        runCatching { onTaskFinishedCore(taskId) }
        runCatching { onTaskFinished(taskId) }
    }

    /**
     * Side-channel listeners. Installed by [DownloadChannels] to drive the
     * [NotificationCenter]. They are fire-and-forget — never block the
     * emitter and never throw back into the downloader coroutine.
     */
    var onProgress:
        (taskId: String, downloaded: Long, total: Long, bps: Long) -> Unit =
        { _, _, _, _ -> }
    var onStatus: (taskId: String, status: DownloadStatus) -> Unit =
        { _, _ -> }

    // ── StreamHandler ───────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ── Status events ───────────────────────────────────────────────────

    fun emitStatus(
        taskId: String,
        status: DownloadStatus,
        errorMessage: String? = null,
        errorCode: String? = null,
        filePath: String? = null,
        totalBytes: Long? = null,
    ) {
        // Cache first so even if the sink is null (Flutter detached)
        // the next snapshotForSync() replays this transition.
        snapshots.compute(taskId) { _, current ->
            val base = current ?: Snapshot(
                taskId = taskId,
                status = status,
                downloadedBytes = 0L,
                totalBytes = 0L,
                bytesPerSecond = 0L,
                filePath = null,
                errorMessage = null,
                errorCode = null,
            )
            base.status = status
            if (errorMessage != null) base.errorMessage = errorMessage
            if (errorCode != null) base.errorCode = errorCode
            if (filePath != null) base.filePath = filePath
            if (totalBytes != null) base.totalBytes = totalBytes
            // Terminal statuses freeze downloadedBytes at totalBytes (if
            // known) so the UI shows 100% on sync-after-completion.
            if (status == DownloadStatus.COMPLETED && base.totalBytes > 0) {
                base.downloadedBytes = base.totalBytes
                base.bytesPerSecond = 0L
            }
            base
        }
        val event = buildMap<String, Any?> {
            put("type", "status")
            put("taskId", taskId)
            put("status", status.name.lowercase())
            if (errorMessage != null) put("errorMessage", errorMessage)
            if (errorCode != null) put("errorCode", errorCode)
            if (filePath != null) put("filePath", filePath)
            if (totalBytes != null) put("totalBytes", totalBytes)
        }
        post(event)
        runCatching { onStatus(taskId, status) }
    }

    // ── Progress events ─────────────────────────────────────────────────

    fun emitProgress(
        taskId: String,
        downloadedBytes: Long,
        totalBytes: Long,
        bytesPerSecond: Long = 0L,
    ) {
        snapshots.compute(taskId) { _, current ->
            val base = current ?: Snapshot(
                taskId = taskId,
                status = DownloadStatus.DOWNLOADING,
                downloadedBytes = downloadedBytes,
                totalBytes = totalBytes,
                bytesPerSecond = bytesPerSecond,
                filePath = null,
                errorMessage = null,
                errorCode = null,
            )
            base.downloadedBytes = downloadedBytes
            base.totalBytes = totalBytes
            base.bytesPerSecond = bytesPerSecond
            base
        }
        val event = mapOf<String, Any?>(
            "type" to "progress",
            "taskId" to taskId,
            "downloadedBytes" to downloadedBytes,
            "totalBytes" to totalBytes,
            "bytesPerSecond" to bytesPerSecond,
        )
        post(event)
        runCatching { onProgress(taskId, downloadedBytes, totalBytes, bytesPerSecond) }
    }

    // ── Warning events ──────────────────────────────────────────────────

    fun emitWarning(taskId: String, code: String, message: String) {
        val event = mapOf<String, Any?>(
            "type" to "warning",
            "taskId" to taskId,
            "code" to code,
            "message" to message,
        )
        post(event)
    }

    // ── Internal ────────────────────────────────────────────────────────

    private fun post(event: Map<String, Any?>) {
        val s = sink ?: return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            s.success(event)
        } else {
            mainHandler.post { sink?.success(event) }
        }
    }
}
