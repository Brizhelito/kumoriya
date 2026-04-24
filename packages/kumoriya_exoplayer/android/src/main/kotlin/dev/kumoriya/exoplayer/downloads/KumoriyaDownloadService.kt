package dev.kumoriya.exoplayer.downloads

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat

/**
 * Foreground service that keeps the process alive while downloads run.
 *
 * Lifecycle is driven by [DownloadEngine]: started when the first task is
 * enqueued, stopped when the last task completes / is cancelled. The
 * service does **not** own the engine — it is a pure keep-alive.
 *
 * The notification shown is a low-importance summary. Per-task
 * notifications arrive in Fase 7.
 */
internal class KumoriyaDownloadService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        promoteToForeground()
        Log.d(TAG, "FGS created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android mandates that every startForegroundService() call be
        // followed by a startForeground() within 5s. onCreate only runs
        // on the first start, so we must also promote here for every
        // subsequent start request — otherwise the system kills the
        // process with ForegroundServiceDidNotStartInTimeException.
        promoteToForeground()

        // Dispatch notification actions. The NotificationCenter builds
        // PendingIntents targeted at this service; we route them to the
        // engine via the @Volatile `shared` reference. If the plugin
        // detached between post and click, the action is a no-op.
        intent?.action?.let { action ->
            val engine = DownloadEngine.shared
            val taskId = intent.getStringExtra(NotificationCenter.EXTRA_TASK_ID)
            when (action) {
                NotificationCenter.ACTION_PAUSE -> taskId?.let { engine?.pause(it) }
                NotificationCenter.ACTION_RESUME -> taskId?.let { engine?.resumeById(it) }
                NotificationCenter.ACTION_CANCEL -> taskId?.let { engine?.cancel(it) }
                NotificationCenter.ACTION_PAUSE_ALL -> engine?.pauseAll()
                NotificationCenter.ACTION_RESUME_ALL -> engine?.resumeAll()
                else -> Log.d(TAG, "Unhandled service action: $action")
            }
        }

        // Sticky: if the system kills us we want a restart so we can
        // reconcile state with the engine on the next attach.
        return START_STICKY
    }

    private fun promoteToForeground() {
        val notification = buildSummaryNotification()
        ServiceCompat.startForeground(
            this,
            NotificationCenter.SUMMARY_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )
    }

    /**
     * Fires when the user swipes the app from recents. The default
     * platform behaviour is inconsistent across OEMs — some invoke
     * `stopSelf` via the system, others leave the FGS running. Override
     * explicitly to keep the service alive: downloads run in their own
     * coroutines owned by [DownloadCore] and are completely independent
     * of the activity task being swiped.
     *
     * `rootIntent` is intentionally ignored.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        val engine = DownloadEngine.shared
        val active = engine?.hasActiveJobs == true
        Log.i(TAG, "onTaskRemoved (active=$active) — keeping FGS alive")
        // Do NOT call super.onTaskRemoved(...) — its default on some
        // ROMs ends up scheduling a stopSelf. We want the opposite.
    }

    override fun onDestroy() {
        // stopService alone is not reliably enough to clear the summary
        // notification on every OEM skin — MIUI and OneUI have been
        // observed leaving it pinned until the next device unlock.
        // Explicitly detach + remove so the shade is always clean after
        // the last download terminates.
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        Log.d(TAG, "FGS destroyed")
        super.onDestroy()
    }

    // ── Notification ────────────────────────────────────────────────────

    private fun ensureChannel() {
        // The NotificationCenter owns channel creation. We still reach
        // into it here so the FGS can start even before the first event
        // sink listener fires (e.g. a cold boot where the service is
        // restarted by the system).
        NotificationCenter(this)
    }

    private fun buildSummaryNotification(): Notification {
        val engine = DownloadEngine.shared
        return engine?.notificationCenter?.buildSummary()
            ?: fallbackSummary()
    }

    /**
     * Minimal notification used if the engine isn't attached yet — the
     * FGS must post *something* within 5s of [startForeground] or Android
     * kills the process with a `ForegroundServiceDidNotStartInTime`
     * exception.
     */
    private fun fallbackSummary(): Notification =
        androidx.core.app.NotificationCompat
            .Builder(this, NotificationCenter.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Kumoriya")
            .setContentText("Descargando…")
            .setOngoing(true)
            .setSilent(true)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW)
            .build()

    companion object {
        private const val TAG = "KumoriyaDLService"

        /** Start the foreground service. Safe to call multiple times. */
        fun start(context: Context) {
            val intent = Intent(context, KumoriyaDownloadService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stop the foreground service. */
        fun stop(context: Context) {
            context.stopService(
                Intent(context, KumoriyaDownloadService::class.java),
            )
        }
    }
}
