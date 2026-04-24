package dev.kumoriya.exoplayer.downloads

import android.content.Context

/**
 * Process-scope holder for the downloader core (engine + notification
 * center + event sink).
 *
 * Why: when the user swipes the app from recents, Flutter detaches the
 * engine and `KumoriyaExoPlayerPlugin.onDetachedFromEngine` fires. If
 * the `DownloadEngine` were owned by the plugin (as it was originally),
 * the detach would cancel every in-flight download and tear down the
 * foreground service — exactly the opposite of what the user expects
 * when they "close the app" with downloads still running.
 *
 * Moving ownership to a process-scope singleton decouples download work
 * from the UI lifecycle. Flutter attach/detach now only wires/unwires
 * the Method/Event channels; the engine keeps running, the FGS keeps
 * the process alive, and notifications keep updating. A subsequent
 * cold start (e.g. after the OS eventually kills the process) is still
 * covered by the `_reconcileOnCold` pass in the Dart backend.
 *
 * Thread-safety: [get] is guarded so parallel attach calls can't
 * instantiate two engines. Subsequent reads are lock-free through the
 * @Volatile reference.
 */
internal object DownloadCore {

    private const val FGS_STOP_DEBOUNCE_MS = 4000L

    @Volatile
    private var instance: Holder? = null
    private val lock = Any()

    fun get(context: Context): Holder {
        val existing = instance
        if (existing != null) return existing
        return synchronized(lock) {
            val stillExisting = instance
            if (stillExisting != null) return@synchronized stillExisting
            val appContext = context.applicationContext
            val eventSink = DownloadEventSink()
            val notificationCenter = NotificationCenter(appContext)
            val engine = DownloadEngine(appContext, eventSink, notificationCenter)

            // Always-on notification side-channel — survives every
            // Flutter attach/detach cycle so the UI in the shade keeps
            // updating after the user swipes the app away.
            eventSink.onProgress = { taskId, downloaded, total, bps ->
                engine.paramsByTask[taskId]?.let { params ->
                    notificationCenter.updateProgress(params, downloaded, total, bps)
                }
            }
            eventSink.onStatus = { taskId, status ->
                engine.paramsByTask[taskId]?.let { params ->
                    notificationCenter.updateStatus(params, status)
                }
            }

            // Always-on FGS stop debounce. Runs regardless of Flutter
            // lifecycle so the service tears down when the last
            // download completes even if the app is closed. The
            // Flutter-scoped DownloadChannels registers its own
            // on-top-of this hook too for start-debouncing inside an
            // attached session; both can coexist because they both
            // only stop the service when `hasActiveJobs == false`.
            val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
            val pendingStop = Runnable {
                if (!engine.hasActiveJobs) {
                    KumoriyaDownloadService.stop(appContext)
                }
            }
            eventSink.onTaskFinishedCore = { _ ->
                if (!engine.hasActiveJobs) {
                    mainHandler.removeCallbacks(pendingStop)
                    mainHandler.postDelayed(pendingStop, FGS_STOP_DEBOUNCE_MS)
                }
            }

            val holder = Holder(engine, eventSink, notificationCenter)
            instance = holder
            holder
        }
    }

    internal data class Holder(
        val engine: DownloadEngine,
        val eventSink: DownloadEventSink,
        val notificationCenter: NotificationCenter,
    )
}
