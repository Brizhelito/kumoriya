package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Durable record of taskIds the engine has cancelled.
 *
 * Why: the cancel flow emits `DownloadStatus.CANCELLED` through
 * `DownloadEventSink`, but when Flutter is detached the event is dropped
 * at the channel boundary (the sink is null). The snapshot cache in
 * `DownloadEventSink` covers the detach → reattach case, but a further
 * process death between cancel and reattach wipes the in-memory
 * snapshots too. In that window Drift still has the task as
 * `downloading`, and `_reconcileOnCold` on the next app start would
 * re-enqueue it — resurrecting cancelled downloads.
 *
 * Persisting the taskId to [SharedPreferences] makes the cancel signal
 * survive the process death. On the next init the engine seeds
 * `DownloadEventSink.snapshots` with one `CANCELLED` entry per
 * tombstoned id so the Dart `_applyNativeSnapshots` pass deletes the
 * matching Drift row before `_reconcileOnCold` runs.
 *
 * Tombstones are dropped by [remove] once Dart has acknowledged the
 * snapshot via `forgetSnapshot` — at that point Drift is authoritative
 * and there's nothing left to recover from.
 */
internal class CancelledTombstoneStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun all(): Set<String> = prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()

    fun add(taskId: String) {
        val current = all().toMutableSet()
        if (current.add(taskId)) {
            prefs.edit().putStringSet(KEY_IDS, current).apply()
            Log.d(TAG, "tombstone added $taskId (total=${current.size})")
        }
    }

    fun remove(taskId: String) {
        val current = all().toMutableSet()
        if (current.remove(taskId)) {
            prefs.edit().putStringSet(KEY_IDS, current).apply()
            Log.d(TAG, "tombstone removed $taskId (remaining=${current.size})")
        }
    }

    companion object {
        private const val TAG = "CancelledTombstone"
        private const val PREFS_NAME = "kumoriya_downloads_tombstones"
        private const val KEY_IDS = "cancelled_task_ids"
    }
}
