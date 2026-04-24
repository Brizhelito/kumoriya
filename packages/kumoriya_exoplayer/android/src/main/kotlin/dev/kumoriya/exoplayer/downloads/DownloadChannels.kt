package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the download [MethodChannel] and [EventChannel] to the
 * [DownloadEngine].
 *
 * Instantiated by [KumoriyaExoPlayerPlugin.onAttachedToEngine] and torn
 * down on [detach].
 */
internal class DownloadChannels(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val core = DownloadCore.get(context)
    private val eventSink get() = core.eventSink
    private val engine get() = core.engine

    private val methodChannel = MethodChannel(messenger, CHANNEL_METHODS)
    private val eventChannel = EventChannel(messenger, CHANNEL_EVENTS)

    // Handler kept so in-session enqueue/start races are coalesced —
    // rapid enqueue → cancel → enqueue on the same taskId would
    // otherwise risk calling startForegroundService while a stopService
    // is still in flight (Android 12+ crash). Used only as a
    // debounce-hold for the per-MethodCall `cancelAll` path; the
    // always-on stop hook lives in [DownloadCore].
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingStopFgs = Runnable {
        if (!engine.hasActiveJobs) KumoriyaDownloadService.stop(context)
    }

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
        eventChannel.setStreamHandler(eventSink)
    }

    fun detach() {
        // IMPORTANT: do NOT destroy the engine or stop the FGS here.
        // Flutter detach fires when the user swipes the app from
        // recents — killing the engine would kill every in-flight
        // download with the UI. The engine lives in [DownloadCore]
        // process-scope so downloads keep running, the FGS keeps the
        // process alive, and notifications keep updating. We just
        // unwire the Flutter-owned pieces here.
        mainHandler.removeCallbacks(pendingStopFgs)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // ── MethodChannel dispatch ──────────────────────────────────────────

    @Suppress("UNCHECKED_CAST")
    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "enqueue" -> {
                    val params = call.toDownloadParams()
                    // Cancel any pending stop first — if a stop was
                    // scheduled from the previous task, we don't want
                    // it firing between our start and the job starting.
                    mainHandler.removeCallbacks(pendingStopFgs)
                    KumoriyaDownloadService.start(context)
                    engine.enqueue(params)
                    result.success(null)
                }
                "pause" -> {
                    engine.pause(call.requireArg("taskId"))
                    result.success(null)
                }
                "resume" -> {
                    val params = call.toDownloadParams()
                    engine.resume(params.taskId, params)
                    result.success(null)
                }
                "cancel" -> {
                    engine.cancel(call.requireArg("taskId"))
                    result.success(null)
                }
                "cancelAll" -> {
                    engine.cancelAll()
                    mainHandler.removeCallbacks(pendingStopFgs)
                    mainHandler.postDelayed(pendingStopFgs, FGS_STOP_DEBOUNCE_MS)
                    result.success(null)
                }
                "pauseAll" -> {
                    engine.pauseAll()
                    result.success(null)
                }
                "setWifiOnly" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine.setWifiOnly(enabled)
                    result.success(null)
                }
                "sync" -> {
                    // Return the engine's latest-known snapshot per task
                    // so Dart can reconcile Drift after a detach →
                    // reattach cycle during which all channel events
                    // were dropped. Emits one map per task the engine
                    // has seen in this process lifetime (including
                    // terminal statuses that fired while detached).
                    val snapshots = eventSink.allSnapshots().map { snap ->
                        buildMap<String, Any?> {
                            put("taskId", snap.taskId)
                            put("status", snap.status.name.lowercase())
                            put("downloadedBytes", snap.downloadedBytes)
                            put("totalBytes", snap.totalBytes)
                            put("bytesPerSecond", snap.bytesPerSecond)
                            if (snap.filePath != null) put("filePath", snap.filePath)
                            if (snap.errorMessage != null) put("errorMessage", snap.errorMessage)
                            if (snap.errorCode != null) put("errorCode", snap.errorCode)
                        }
                    }
                    result.success(snapshots)
                }
                "forgetSnapshot" -> {
                    // Called by Dart after it has successfully applied a
                    // terminal-state sync entry to Drift. Acknowledges
                    // both the in-memory snapshot AND any persistent
                    // cancelled tombstone so the same cancel isn't
                    // replayed on the next cold start.
                    engine.acknowledgeSnapshot(call.requireArg("taskId"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "MethodChannel error: ${call.method}", e)
            result.error("download_error", e.message, null)
        }
    }

    // ── Arg parsing ─────────────────────────────────────────────────────

    @Suppress("UNCHECKED_CAST")
    private fun MethodCall.toDownloadParams(): DownloadParams {
        return DownloadParams(
            taskId = requireArg("taskId"),
            url = requireArg("url"),
            headers = argument<Map<String, String>>("headers") ?: emptyMap(),
            fileName = requireArg("fileName"),
            isHls = argument<Boolean>("isHls") ?: false,
            targetDir = requireArg("targetDir"),
            animeTitle = argument<String>("animeTitle") ?: "",
            serverName = argument<String>("serverName"),
            qualityLabel = argument<String>("qualityLabel"),
            remuxToMp4 = argument<Boolean>("remuxToMp4") ?: true,
        )
    }

    private fun <T> MethodCall.requireArg(key: String): T {
        @Suppress("UNCHECKED_CAST")
        return argument<T>(key) ?: throw IllegalArgumentException("missing arg '$key'")
    }

    companion object {
        private const val TAG = "DownloadChannels"
        const val CHANNEL_METHODS = "dev.kumoriya.exoplayer/downloads"
        const val CHANNEL_EVENTS = "dev.kumoriya.exoplayer/downloads/events"

        /**
         * Idle window after the last task finishes before the FGS is
         * torn down. Long enough to coalesce rapid enqueue/cancel
         * cycles, short enough that a genuinely-idle app doesn't keep
         * the service alive indefinitely.
         */
        private const val FGS_STOP_DEBOUNCE_MS = 4000L
    }
}
