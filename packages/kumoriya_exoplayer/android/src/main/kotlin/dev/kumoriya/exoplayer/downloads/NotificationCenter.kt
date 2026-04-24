package dev.kumoriya.exoplayer.downloads

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.concurrent.ConcurrentHashMap

/**
 * Owns the download notification UI — one per-task notification plus a
 * group summary that the foreground service pins.
 *
 * Update calls are throttled to ~1 Hz per task so high-frequency progress
 * events from [DownloadEventSink] don't flood the system NotificationManager
 * (it rate-limits us anyway past ~10/s).
 *
 * Actions (Pause / Resume / Cancel / Pause all / Resume all) are sent as
 * explicit [Intent]s to [KumoriyaDownloadService] which dispatches them to
 * [DownloadEngine].
 */
internal class NotificationCenter(private val context: Context) {

    private val notifMgr = NotificationManagerCompat.from(context)

    /** Throttle map: taskId → last emit timestamp. */
    private val lastUpdateAt = ConcurrentHashMap<String, Long>()

    /**
     * Latest known per-task snapshot. Persists across throttled updates so
     * we can render the correct title/quality/server even when only the
     * progress numbers change.
     */
    private val snapshots = ConcurrentHashMap<String, TaskSnapshot>()

    init {
        ensureChannel()
    }

    // ── Public API ──────────────────────────────────────────────────────

    /** Update the snapshot and post a notification if the throttle allows. */
    fun updateProgress(
        params: DownloadParams,
        downloadedBytes: Long,
        totalBytes: Long,
        bytesPerSecond: Long,
    ) {
        val snap = snapshots.computeIfAbsent(params.taskId) {
            TaskSnapshot(params, DownloadStatus.DOWNLOADING)
        }.apply {
            this.downloadedBytes = downloadedBytes
            this.totalBytes = totalBytes
            this.bytesPerSecond = bytesPerSecond
        }
        if (shouldEmit(params.taskId)) {
            post(snap)
        }
    }

    /** Update the status and always push (status transitions aren't throttled). */
    fun updateStatus(params: DownloadParams, status: DownloadStatus) {
        val snap = snapshots.computeIfAbsent(params.taskId) {
            TaskSnapshot(params, status)
        }.apply { this.status = status }

        when (status) {
            DownloadStatus.COMPLETED,
            DownloadStatus.CANCELLED -> {
                // Drop the per-task notif on terminal states. COMPLETED is
                // intentionally silent: Android's own download notification
                // UX expects a "Download finished" flash, but we leave that
                // to the in-app UI to avoid double notifications.
                clearForTask(params.taskId)
                return
            }
            else -> Unit
        }
        post(snap)
    }

    /** Cancel the notification for a task (on cancel / completion). */
    fun clearForTask(taskId: String) {
        snapshots.remove(taskId)
        lastUpdateAt.remove(taskId)
        notifMgr.cancel(notifId(taskId))
        // Refresh the summary so its title + counters drop this task.
        // If nothing remains, don't re-post an empty "Kumoriya" row —
        // the FGS will be stopped by the debounce and we want the
        // notification shade clean. Posting then stopping leaves a
        // momentary ghost notification some OEM launchers refuse to
        // animate away.
        if (snapshots.isEmpty()) {
            notifMgr.cancel(SUMMARY_ID)
            return
        }
        try {
            if (notifMgr.areNotificationsEnabled()) {
                notifMgr.notify(SUMMARY_ID, buildSummary())
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "POST_NOTIFICATIONS denied on summary refresh", e)
        }
    }

    /** Build the summary notification the FGS attaches as foreground. */
    fun buildSummary(): android.app.Notification {
        val active = snapshots.values.count {
            it.status == DownloadStatus.DOWNLOADING ||
                it.status == DownloadStatus.REMUXING
        }
        val paused = snapshots.values.count {
            it.status == DownloadStatus.PAUSED ||
                it.status == DownloadStatus.DISCONNECTED
        }

        val title = when {
            active > 0 && paused > 0 -> "$active descargando \u00b7 $paused en pausa"
            active > 0 -> if (active == 1) "1 descarga activa" else "$active descargas activas"
            paused > 0 -> if (paused == 1) "1 descarga en pausa" else "$paused descargas en pausa"
            else -> "Kumoriya"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setGroup(GROUP_KEY)
            .setGroupSummary(true)
            .setContentIntent(openDownloadsIntent())

        if (active > 0) {
            builder.addAction(
                android.R.drawable.ic_media_pause,
                "Pausar todo",
                actionIntent(ACTION_PAUSE_ALL, null),
            )
        }
        if (paused > 0) {
            builder.addAction(
                android.R.drawable.ic_media_play,
                "Reanudar todo",
                actionIntent(ACTION_RESUME_ALL, null),
            )
        }

        return builder.build()
    }

    /** Push the latest summary to the NotificationManager (FGS updates too). */
    fun postSummary() {
        if (!notifMgr.areNotificationsEnabled()) return
        try {
            notifMgr.notify(SUMMARY_ID, buildSummary())
        } catch (e: SecurityException) {
            Log.w(TAG, "POST_NOTIFICATIONS denied", e)
        }
    }

    /** Drop all notifications (called on service teardown). */
    fun clearAll() {
        snapshots.keys.toList().forEach { clearForTask(it) }
        notifMgr.cancel(SUMMARY_ID)
        lastUpdateAt.clear()
    }

    // ── Internal ────────────────────────────────────────────────────────

    private fun shouldEmit(taskId: String): Boolean {
        val now = System.currentTimeMillis()
        val last = lastUpdateAt[taskId] ?: 0L
        if (now - last < THROTTLE_MS) return false
        lastUpdateAt[taskId] = now
        return true
    }

    private fun post(snap: TaskSnapshot) {
        if (!notifMgr.areNotificationsEnabled()) return
        try {
            notifMgr.notify(notifId(snap.params.taskId), build(snap))
            // Keep the summary fresh so the group header counters match
            // the per-task notifications the user is looking at.
            notifMgr.notify(SUMMARY_ID, buildSummary())
        } catch (e: SecurityException) {
            Log.w(TAG, "POST_NOTIFICATIONS denied for ${snap.params.taskId}", e)
        }
    }

    private fun build(snap: TaskSnapshot): android.app.Notification {
        val p = snap.params
        val line1 = buildString {
            append(p.animeTitle.ifBlank { p.fileName })
        }
        // Non-DOWNLOADING states lead with the status label so the user
        // doesn't have to read the small subText to understand the row
        // is paused / disconnected / processing. For DOWNLOADING we keep
        // the server + quality + speed triple which is more informative.
        val line2 = buildString {
            if (snap.status != DownloadStatus.DOWNLOADING) {
                append(statusLabel(snap.status))
            }
            p.serverName?.let {
                if (isNotEmpty()) append(" \u00b7 ")
                append(it)
            }
            p.qualityLabel?.let {
                if (isNotEmpty()) append(" \u00b7 ")
                append(it)
            }
            if (snap.bytesPerSecond > 0 && snap.status == DownloadStatus.DOWNLOADING) {
                if (isNotEmpty()) append(" \u00b7 ")
                append(fmtBytes(snap.bytesPerSecond)).append("/s")
            }
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIconFor(snap.status))
            .setContentTitle(line1)
            .setContentText(line2.ifBlank { statusLabel(snap.status) })
            .setOngoing(snap.status != DownloadStatus.PAUSED)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setGroup(GROUP_KEY)
            .setOnlyAlertOnce(true)
            .setContentIntent(openDownloadsIntent())

        // Progress bar: indeterminate during REMUXING (byte count is stale),
        // percentage when we know the total, hidden on PAUSED.
        when (snap.status) {
            DownloadStatus.REMUXING ->
                builder.setProgress(0, 0, true)
            DownloadStatus.DOWNLOADING -> {
                if (snap.totalBytes > 0) {
                    val pct = ((snap.downloadedBytes * 100L) / snap.totalBytes)
                        .toInt().coerceIn(0, 100)
                    builder.setProgress(100, pct, false)
                    builder.setSubText("$pct%")
                } else {
                    builder.setProgress(0, 0, true)
                }
            }
            DownloadStatus.PAUSED -> {
                if (snap.totalBytes > 0) {
                    val pct = ((snap.downloadedBytes * 100L) / snap.totalBytes)
                        .toInt().coerceIn(0, 100)
                    builder.setProgress(100, pct, false)
                    builder.setSubText("En pausa \u00b7 $pct%")
                } else {
                    builder.setSubText("En pausa")
                }
            }
            DownloadStatus.DISCONNECTED -> {
                // Same shape as PAUSED but different subText so the user
                // reads it as "we're waiting for your network, not for
                // you". Progress stays visible — partial bytes are kept
                // and resume will pick up from there.
                if (snap.totalBytes > 0) {
                    val pct = ((snap.downloadedBytes * 100L) / snap.totalBytes)
                        .toInt().coerceIn(0, 100)
                    builder.setProgress(100, pct, false)
                    builder.setSubText("Sin conexi\u00f3n \u00b7 $pct%")
                } else {
                    builder.setSubText("Sin conexi\u00f3n")
                }
            }
            else -> Unit
        }

        // Actions: pause+cancel while downloading, resume+cancel while paused.
        when (snap.status) {
            DownloadStatus.DOWNLOADING,
            DownloadStatus.REMUXING -> {
                if (snap.status == DownloadStatus.DOWNLOADING) {
                    builder.addAction(
                        android.R.drawable.ic_media_pause,
                        "Pausar",
                        actionIntent(ACTION_PAUSE, snap.params.taskId),
                    )
                }
                builder.addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Cancelar",
                    actionIntent(ACTION_CANCEL, snap.params.taskId),
                )
            }
            DownloadStatus.PAUSED,
            DownloadStatus.DISCONNECTED -> {
                // Resume works the same in both cases: engine re-enqueues
                // and the downloader reads the manifest to pick up where
                // it left off. User tapping resume on DISCONNECTED is
                // effectively a manual retry.
                builder.addAction(
                    android.R.drawable.ic_media_play,
                    if (snap.status == DownloadStatus.DISCONNECTED)
                        "Reintentar"
                    else
                        "Reanudar",
                    actionIntent(ACTION_RESUME, snap.params.taskId),
                )
                builder.addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Cancelar",
                    actionIntent(ACTION_CANCEL, snap.params.taskId),
                )
            }
            else -> Unit
        }

        return builder.build()
    }

    private fun actionIntent(action: String, taskId: String?): PendingIntent {
        val intent = Intent(context, KumoriyaDownloadService::class.java).apply {
            this.action = action
            taskId?.let { putExtra(EXTRA_TASK_ID, it) }
        }
        // requestCode must be unique per action+task to avoid PendingIntent
        // collision between tasks; use a hash as a stable key.
        val requestCode = (action + (taskId ?: "")).hashCode()
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, requestCode, intent, flags)
        } else {
            PendingIntent.getService(context, requestCode, intent, flags)
        }
    }

    private fun openDownloadsIntent(): PendingIntent? {
        // Deep-link back into the app's downloads tab. The host Flutter
        // activity must handle `kumoriya://downloads` in its manifest to
        // surface the user on the Downloads page — if it doesn't, the tap
        // falls back to opening the launcher activity.
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return null
        val deepLink = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("kumoriya://downloads"))
            .setPackage(context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val resolved = context.packageManager
            .resolveActivity(deepLink, 0)
        val target = if (resolved != null) deepLink else launch.apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            OPEN_REQUEST_CODE,
            target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun smallIconFor(status: DownloadStatus): Int = when (status) {
        DownloadStatus.PAUSED -> android.R.drawable.ic_media_pause
        DownloadStatus.REMUXING -> android.R.drawable.stat_sys_upload
        DownloadStatus.DISCONNECTED -> android.R.drawable.stat_notify_error
        else -> android.R.drawable.stat_sys_download
    }

    private fun statusLabel(status: DownloadStatus): String = when (status) {
        DownloadStatus.DOWNLOADING -> "Descargando\u2026"
        DownloadStatus.PAUSED -> "En pausa"
        DownloadStatus.REMUXING -> "Procesando\u2026"
        DownloadStatus.FAILED -> "Error"
        DownloadStatus.COMPLETED -> "Listo"
        DownloadStatus.CANCELLED -> "Cancelado"
        DownloadStatus.PENDING -> "Esperando\u2026"
        DownloadStatus.DISCONNECTED -> "Sin conexi\u00f3n"
    }

    private fun fmtBytes(bytes: Long): String = when {
        bytes >= 1_000_000_000L -> "%.1f GB".format(bytes / 1_000_000_000.0)
        bytes >= 1_000_000L -> "%.1f MB".format(bytes / 1_000_000.0)
        bytes >= 1_000L -> "%.0f kB".format(bytes / 1_000.0)
        else -> "$bytes B"
    }

    private fun notifId(taskId: String): Int {
        // Positive int derived from the taskId. Keep the high bit clear so
        // it never collides with [SUMMARY_ID] (= 1) or the service id.
        return (taskId.hashCode() and 0x7FFFFFFF).let { if (it < 100) it + 100 else it }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Descargas",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Progreso de descargas activas"
                    setShowBadge(false)
                },
            )
        }
    }

    private data class TaskSnapshot(
        val params: DownloadParams,
        var status: DownloadStatus,
        var downloadedBytes: Long = 0L,
        var totalBytes: Long = 0L,
        var bytesPerSecond: Long = 0L,
    )

    companion object {
        private const val TAG = "NotifCenter"

        const val CHANNEL_ID = "kumoriya_downloads"
        const val GROUP_KEY = "kumoriya_downloads_group"

        /** Notification id for the group summary. Keeps it out of the
         *  per-task id range so they never collide. */
        const val SUMMARY_ID = 1

        const val ACTION_PAUSE = "dev.kumoriya.downloads.PAUSE"
        const val ACTION_RESUME = "dev.kumoriya.downloads.RESUME"
        const val ACTION_CANCEL = "dev.kumoriya.downloads.CANCEL"
        const val ACTION_PAUSE_ALL = "dev.kumoriya.downloads.PAUSE_ALL"
        const val ACTION_RESUME_ALL = "dev.kumoriya.downloads.RESUME_ALL"
        const val EXTRA_TASK_ID = "taskId"

        private const val OPEN_REQUEST_CODE = 0
        private const val THROTTLE_MS = 1000L
    }
}
