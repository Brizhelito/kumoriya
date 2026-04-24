package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Central download orchestrator.
 *
 * Manages active download [Job]s keyed by `taskId`. Each enqueue spawns a
 * coroutine on [Dispatchers.IO] supervised so one failure doesn't cancel
 * siblings.
 *
 * Future phases plug in [DirectDownloader] (Fase 3) and
 * [HlsSegmentDownloader] (Fase 4) here.
 */
internal class DownloadEngine(
    private val context: Context,
    private val eventSink: DownloadEventSink,
    internal val notificationCenter: NotificationCenter,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val jobs = ConcurrentHashMap<String, Job>()

    /**
     * Tasks paused by the network monitor (connectivity loss or wifiOnly
     * violation). Tracked separately from user pauses so
     * [onConnectivityRecovered] only resumes what *we* auto-paused — a
     * user-initiated pause survives a reconnect.
     */
    private val autoPausedTasks = java.util.Collections.newSetFromMap(
        ConcurrentHashMap<String, Boolean>(),
    )

    /** True when the user enabled "download on WiFi only" in settings. */
    @Volatile
    private var wifiOnly: Boolean = false

    private val networkMonitor = NetworkMonitor(context).also { mon ->
        mon.start { prev, current ->
            // Dispatch on the IO scope so we never block the system
            // ConnectivityService thread.
            scope.launch { onNetworkChange(prev, current) }
        }
    }

    /**
     * Last-known params per task, kept so [cancel] can locate and delete
     * the `.partial` / final file on disk even after the coroutine's
     * own reference to params has gone out of scope. Also used by the
     * notification center (action buttons need `resume(params)`) and by
     * the FGS action dispatcher.
     */
    internal val paramsByTask = ConcurrentHashMap<String, DownloadParams>()

    /**
     * FIFO queue of tasks waiting for a concurrency slot. Protected by
     * the monitor on [queueLock] — enqueues, slot releases, and cancels
     * all need a coherent (running, waiting) snapshot to avoid both
     * overshooting the cap and stalling the queue.
     */
    private val waitingQueue = ArrayDeque<DownloadParams>()
    private val queueLock = Any()

    /**
     * Persistent tombstone list — durable across process death so a
     * cancel that happens while Flutter is detached is NOT undone by
     * the next cold-start reconcile. See [CancelledTombstoneStore] for
     * the full rationale.
     */
    private val cancelledTombstones = CancelledTombstoneStore(context)

    init {
        shared = this
        // Seed the event sink snapshot cache with one CANCELLED entry
        // per tombstoned taskId. The Dart `_applyNativeSnapshots` pass
        // on next reattach will consume these and delete the matching
        // Drift rows — acknowledging the snapshot via `forgetSnapshot`
        // also removes the tombstone, keeping the prefs small.
        val tombstones = cancelledTombstones.all()
        if (tombstones.isNotEmpty()) {
            Log.i(TAG, "seeding ${tombstones.size} cancelled tombstone(s)")
            for (taskId in tombstones) {
                eventSink.emitStatus(taskId, DownloadStatus.CANCELLED)
            }
        }
    }

    /** True while at least one download job is active. */
    val hasActiveJobs: Boolean get() = jobs.values.any { it.isActive }

    /** Number of currently running (non-completed, non-cancelled) jobs. */
    val activeCount: Int get() = jobs.values.count { it.isActive }

    // ── Task lifecycle ──────────────────────────────────────────────────

    fun enqueue(params: DownloadParams) {
        // Clear any cancel residue for this taskId. Download ids are
        // deterministic per (anilistId, episodeNumber) so a user who
        // cancels Ep 5 and then immediately re-enqueues it hits the
        // SAME taskId — without this, the stale tombstone + CANCELLED
        // snapshot would resurrect on the next cold start and wipe the
        // freshly-downloading task. Re-enqueue is an explicit user
        // intent to override any previous cancel.
        cancelledTombstones.remove(params.taskId)
        eventSink.forgetSnapshot(params.taskId)

        if (jobs[params.taskId]?.isActive == true) {
            Log.w(TAG, "enqueue: task ${params.taskId} already active, ignoring")
            return
        }

        Log.i(TAG, "enqueue: scheduling ${params.taskId} (isHls=${params.isHls})")

        paramsByTask[params.taskId] = params

        // wifiOnly gate: if the user is on a metered (cellular) network
        // and the policy forbids it, don't even start the job — park the
        // task in DISCONNECTED so it auto-resumes when WiFi returns.
        val net = networkMonitor.current
        if (!net.online || (wifiOnly && !net.isWifiLike)) {
            val reason = if (!net.online) "offline" else "metered + wifiOnly"
            Log.i(TAG, "enqueue: parking ${params.taskId} ($reason)")
            autoPausedTasks.add(params.taskId)
            eventSink.emitStatus(params.taskId, DownloadStatus.DISCONNECTED)
            notificationCenter.updateStatus(params, DownloadStatus.DISCONNECTED)
            return
        }

        // Concurrency gate: keep no more than [MAX_CONCURRENT] downloads
        // running at once. Excess tasks park in PENDING and wait their
        // turn — a completing task drains the queue from the `finally`
        // block. Sampling `jobs.size` under `queueLock` together with
        // the enqueue/dequeue of [waitingQueue] is what makes this
        // race-free: without the lock two concurrent enqueues could both
        // see 2 active, both start, and overshoot to 4.
        val startNow = synchronized(queueLock) {
            // Dedupe the waiting queue so resume/retry clicks don't
            // stack multiple copies of the same task.
            waitingQueue.removeAll { it.taskId == params.taskId }
            if (jobs.size < MAX_CONCURRENT) {
                true
            } else {
                waitingQueue.addLast(params)
                false
            }
        }
        if (!startNow) {
            Log.i(TAG, "enqueue: queued ${params.taskId} (active=${jobs.size})")
            eventSink.emitStatus(params.taskId, DownloadStatus.PENDING)
            notificationCenter.updateStatus(params, DownloadStatus.PENDING)
            return
        }

        startJob(params)
    }

    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    private fun startJob(params: DownloadParams) {
        notificationCenter.updateStatus(params, DownloadStatus.DOWNLOADING)
        // Any prior auto-pause marker is stale now — we're actively
        // starting the job.
        autoPausedTasks.remove(params.taskId)

        lateinit var thisJob: Job
        thisJob = scope.launch {
            try {
                Log.d(TAG, "coroutine start: ${params.taskId}")
                eventSink.emitStatus(params.taskId, DownloadStatus.DOWNLOADING)
                runWithRetry(params)
            } catch (_: CancellationException) {
                Log.d(TAG, "task ${params.taskId} cancelled")
            } catch (e: Exception) {
                // runWithRetry surfaces only terminal failures — all
                // transient ones are swallowed+retried internally. A
                // failure here means the classifier decided to stop
                // trying; translate to the right UI state.
                val cancelled = coroutineContext[Job]?.isCancelled == true
                if (cancelled) {
                    Log.d(TAG, "task ${params.taskId} cancelled (via ${e.javaClass.simpleName})")
                } else {
                    handleTerminal(params, e)
                }
            } finally {
                // Only remove if this Job still owns the map entry. A
                // slow-cancelling predecessor must not wipe a fresh
                // replacement that was enqueued with the same taskId.
                // coroutineContext[Job]!! is the same Job that `scope.launch`
                // returns — safe to reference from inside the coroutine and
                // immune to the lateinit race.
                jobs.remove(params.taskId, coroutineContext[Job])
                // Slot freed → pull the next waiter (if any) into an
                // active download BEFORE notifying the channel. Must run
                // even on failure/cancel paths so one bad task doesn't
                // stall the whole queue. Draining first also prevents
                // the FGS stop-debounce from briefly observing "no
                // active jobs" between this slot release and the next
                // promotion.
                drainQueue()
                eventSink.notifyTaskFinished(params.taskId)
            }
        }
        jobs[params.taskId] = thisJob
    }

    /**
     * Promote up to [MAX_CONCURRENT] waiting tasks into active jobs.
     * Safe to call from any thread — the lock keeps the dequeue atomic
     * with the `jobs.size` check. Called from the coroutine's `finally`
     * and from admin paths (pauseAll/cancelAll) that free slots.
     */
    private fun drainQueue() {
        while (true) {
            val next = synchronized(queueLock) {
                if (jobs.size >= MAX_CONCURRENT) return
                waitingQueue.removeFirstOrNull()
            } ?: return
            Log.i(TAG, "drainQueue: starting ${next.taskId}")
            startJob(next)
        }
    }

    fun pause(taskId: String) {
        // Waiting (PENDING) task → just unqueue. No Job to cancel.
        val wasQueued = synchronized(queueLock) {
            waitingQueue.removeAll { it.taskId == taskId }
        }
        jobs.remove(taskId)?.cancel()
        // A manual pause supersedes any auto-pause marker — on reconnect
        // we must not resume a task the user explicitly paused.
        autoPausedTasks.remove(taskId)
        eventSink.emitStatus(taskId, DownloadStatus.PAUSED)
        paramsByTask[taskId]?.let { notificationCenter.updateStatus(it, DownloadStatus.PAUSED) }
        if (wasQueued) drainQueue()
    }

    fun resume(taskId: String, params: DownloadParams) {
        // Re-enqueue; the downloader reads the manifest to resume.
        enqueue(params)
    }

    /**
     * Resume a task from the notification action. Uses the cached params
     * (the user never provides them through a notification click) and
     * no-ops when the task was garbage-collected between pause and click.
     */
    fun resumeById(taskId: String) {
        val params = paramsByTask[taskId] ?: run {
            Log.w(TAG, "resumeById: no params for $taskId")
            return
        }
        enqueue(params)
    }

    /**
     * Called by Dart (via `forgetSnapshot` / `acknowledgeCancelled`
     * MethodChannel) once it has consumed a CANCELLED snapshot and
     * written the Drift delete. Removes both the in-memory snapshot
     * and the persistent tombstone so we don't replay the same cancel
     * on every subsequent sync.
     */
    fun acknowledgeSnapshot(taskId: String) {
        eventSink.forgetSnapshot(taskId)
        cancelledTombstones.remove(taskId)
    }

    fun cancel(taskId: String) {
        val wasQueued = synchronized(queueLock) {
            waitingQueue.removeAll { it.taskId == taskId }
        }
        jobs.remove(taskId)?.cancel()
        autoPausedTasks.remove(taskId)
        StorageLayout.deleteTmpTask(context, taskId)
        deleteTargetArtifacts(paramsByTask.remove(taskId))
        // Persist the cancel BEFORE emitting so even if the process
        // dies right after this line, the next cold start will still
        // know this taskId was cancelled and propagate to Drift.
        cancelledTombstones.add(taskId)
        eventSink.emitStatus(taskId, DownloadStatus.CANCELLED)
        notificationCenter.clearForTask(taskId)
        if (wasQueued) drainQueue()
    }

    /**
     * Delete the `.partial` working file and the renamed final file, if
     * either still exists. Called on cancel so the disk stays consistent
     * with the (deleted) Drift row — otherwise the user sees "cancelled"
     * in the UI while the file lingers in Downloads/.
     */
    private fun deleteTargetArtifacts(params: DownloadParams?) {
        if (params == null) return
        try {
            val animeDir = File(
                params.targetDir,
                StorageLayout.sanitize(params.animeTitle),
            )
            File(animeDir, "${params.fileName}.partial").delete()
            File(animeDir, "${params.fileName}.chunks.json").delete()
            File(animeDir, "${params.fileName}.chunks.json.tmp").delete()
            File(animeDir, params.fileName).delete()
            // HLS rewrites the Dart-provided extension (always `.ts` at
            // enqueue) to the real container on disk — `.ts` when remux
            // is off, `.mp4` when on. Sweep both variants plus their
            // `.partial` siblings so neither a half-finished concat nor
            // a freshly-muxed MP4 survives a cancel.
            val baseName = params.fileName.substringBeforeLast('.')
            File(animeDir, "$baseName.ts").delete()
            File(animeDir, "$baseName.ts.partial").delete()
            File(animeDir, "$baseName.mp4").delete()
            File(animeDir, "$baseName.mp4.partial").delete()
        } catch (e: Exception) {
            Log.w(TAG, "cancel: failed to delete artifacts for ${params.taskId}", e)
        }
    }

    fun cancelAll() {
        // Sweep both running and queued tasks — `cancel()` handles each
        // case (unqueue or cancel coroutine). Copy the queue ids first
        // so we don't mutate it under the forEach.
        val queuedIds = synchronized(queueLock) {
            waitingQueue.map { it.taskId }
        }
        val ids = (jobs.keys().toList() + queuedIds).distinct()
        ids.forEach { cancel(it) }
    }

    fun pauseAll() {
        val queuedIds = synchronized(queueLock) {
            waitingQueue.map { it.taskId }
        }
        val ids = (jobs.keys().toList() + queuedIds).distinct()
        ids.forEach { pause(it) }
    }

    /**
     * Resume every task currently known to the engine that is not already
     * active. Used by the summary notification's "Resume all" action.
     */
    fun resumeAll() {
        val queuedIds = synchronized(queueLock) {
            waitingQueue.map { it.taskId }.toSet()
        }
        val candidates = paramsByTask.keys.toList().filter {
            jobs[it]?.isActive != true && it !in queuedIds
        }
        candidates.forEach { resumeById(it) }
    }

    // ── Network monitor integration ─────────────────────────────────────

    /**
     * Called when the user toggles the "WiFi only" setting. Re-evaluates
     * every active task against the new policy: on cellular + wifiOnly,
     * auto-pauses; on wifi + !wifiOnly, does nothing (already running).
     */
    fun setWifiOnly(enabled: Boolean) {
        if (wifiOnly == enabled) return
        wifiOnly = enabled
        Log.i(TAG, "wifiOnly → $enabled")
        val snapshot = networkMonitor.current
        if (enabled && snapshot.online && !snapshot.isWifiLike) {
            autoPauseAll("wifiOnly toggled on while on metered network")
        } else if (!enabled && snapshot.online) {
            // Disabling wifiOnly on a working network → resume whatever
            // we auto-paused earlier. A connectivity-loss pause remains
            // blocked (we're still online, so nothing to do anyway).
            resumeAutoPaused()
        }
    }

    private fun onNetworkChange(
        prev: NetworkMonitor.Snapshot,
        current: NetworkMonitor.Snapshot,
    ) {
        // 1. We just went offline → pause everything so the UI reflects
        //    the situation immediately instead of waiting for OkHttp's
        //    own timeout to surface IOException.
        if (prev.online && !current.online) {
            autoPauseAll("connectivity lost")
            return
        }

        // 2. We're back online.
        if (!prev.online && current.online) {
            if (!wifiOnly || current.isWifiLike) {
                resumeAutoPaused()
            }
            return
        }

        // 3. Still online but the transport changed (WiFi ↔ cellular).
        if (current.online && wifiOnly) {
            if (!current.isWifiLike) {
                autoPauseAll("switched to metered network while wifiOnly")
            } else {
                resumeAutoPaused()
            }
        }
    }

    private fun autoPauseAll(reason: String) {
        // Drain the waiting queue too — otherwise PENDING tasks would
        // silently skip the disconnect state and try to run the instant
        // a slot frees up, only to fail again on the downed network.
        val queued = synchronized(queueLock) {
            val copy = waitingQueue.toList()
            waitingQueue.clear()
            copy
        }
        val active = jobs.keys.toList()
        if (active.isEmpty() && queued.isEmpty()) return
        Log.i(
            TAG,
            "autoPauseAll: ${active.size} active + ${queued.size} queued, reason=$reason",
        )
        active.forEach { taskId ->
            jobs.remove(taskId)?.cancel()
            autoPausedTasks.add(taskId)
            eventSink.emitStatus(taskId, DownloadStatus.DISCONNECTED)
            paramsByTask[taskId]?.let {
                notificationCenter.updateStatus(it, DownloadStatus.DISCONNECTED)
            }
        }
        queued.forEach { params ->
            autoPausedTasks.add(params.taskId)
            eventSink.emitStatus(params.taskId, DownloadStatus.DISCONNECTED)
            notificationCenter.updateStatus(params, DownloadStatus.DISCONNECTED)
        }
    }

    private fun resumeAutoPaused() {
        val ids = autoPausedTasks.toList()
        if (ids.isEmpty()) return
        Log.i(TAG, "resumeAutoPaused: ${ids.size} task(s)")
        ids.forEach { taskId ->
            autoPausedTasks.remove(taskId)
            val params = paramsByTask[taskId] ?: return@forEach
            enqueue(params)
        }
    }

    // ── Error classification + retry ────────────────────────────────────

    /**
     * Run the appropriate downloader for [params] with retry semantics
     * driven by [DownloadErrorClassifier]. Transient failures
     * (RetryOnce / RetryBackoff) are swallowed and retried inline; the
     * downloaders resume from their on-disk manifest so a retry doesn't
     * re-download completed bytes. Terminal failures propagate out so
     * the outer catch can emit the right UI state.
     */
    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    private suspend fun runWithRetry(params: DownloadParams) {
        var backoffAttempt = 0
        var retryOnceUsed = false
        while (true) {
            try {
                if (params.isHls) {
                    HlsDownloader.download(context, params, eventSink)
                } else {
                    ParallelDownloader.download(context, params, eventSink)
                }
                return
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                val action = DownloadErrorClassifier.classify(e)
                Log.w(
                    TAG,
                    "${params.taskId}: ${e.javaClass.simpleName} → $action",
                )
                when (action) {
                    is DownloadErrorClassifier.Action.RetryOnce -> {
                        if (retryOnceUsed) throw e
                        retryOnceUsed = true
                        // Tiny 500ms grace so we don't thrash the server
                        // on back-to-back 404s from an unwarmed CDN edge.
                        kotlinx.coroutines.delay(500L)
                    }
                    is DownloadErrorClassifier.Action.RetryBackoff -> {
                        backoffAttempt++
                        if (backoffAttempt > DownloadErrorClassifier.MAX_BACKOFF_ATTEMPTS) throw e
                        val delayMs = DownloadErrorClassifier.backoffMillis(backoffAttempt)
                        Log.i(
                            TAG,
                            "${params.taskId}: retry #$backoffAttempt in ${delayMs}ms",
                        )
                        kotlinx.coroutines.delay(delayMs)
                    }
                    else -> throw e
                }
            }
        }
    }

    /**
     * Translate a terminal exception into the appropriate emitted state.
     * Called only when [runWithRetry] gave up (classifier returned a
     * non-retry action, or the retry budget was exhausted).
     */
    private fun handleTerminal(params: DownloadParams, e: Throwable) {
        when (val action = DownloadErrorClassifier.classify(e)) {
            is DownloadErrorClassifier.Action.Disconnected -> {
                Log.w(TAG, "${params.taskId} disconnected: ${e.javaClass.simpleName}")
                autoPausedTasks.add(params.taskId)
                eventSink.emitStatus(
                    params.taskId,
                    DownloadStatus.DISCONNECTED,
                    errorMessage = e.message,
                    errorCode = "download.network_error",
                )
                notificationCenter.updateStatus(params, DownloadStatus.DISCONNECTED)
            }
            is DownloadErrorClassifier.Action.StorageFull -> {
                Log.e(TAG, "${params.taskId} failed: disk full")
                eventSink.emitStatus(
                    params.taskId,
                    DownloadStatus.FAILED,
                    errorMessage = e.message,
                    errorCode = "download.storage_full",
                )
            }
            is DownloadErrorClassifier.Action.FailFast,
            is DownloadErrorClassifier.Action.RetryOnce,
            is DownloadErrorClassifier.Action.RetryBackoff -> {
                // RetryOnce/RetryBackoff reach this branch only after
                // the retry budget is spent — treat as permanent.
                val code = when (action) {
                    is DownloadErrorClassifier.Action.FailFast -> action.code
                    is DownloadErrorClassifier.Action.RetryOnce -> action.code
                    is DownloadErrorClassifier.Action.RetryBackoff -> action.code
                    else -> "download.unexpected"
                }
                Log.e(TAG, "${params.taskId} failed [$code]", e)
                eventSink.emitStatus(
                    params.taskId,
                    DownloadStatus.FAILED,
                    errorMessage = e.message,
                    errorCode = code,
                )
            }
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────

    fun destroy() {
        networkMonitor.stop()
        scope.cancel()
        jobs.clear()
        synchronized(queueLock) { waitingQueue.clear() }
        autoPausedTasks.clear()
        notificationCenter.clearAll()
        if (shared === this) shared = null
    }

    companion object {
        private const val TAG = "DownloadEngine"

        /**
         * Maximum number of downloads allowed to run concurrently. Excess
         * tasks park in a FIFO queue and are promoted automatically as
         * slots free up. Three mirrors common manager apps (IDM, FDM)
         * and keeps aggregate bandwidth usage predictable on mobile
         * links, without starving short HLS tasks behind a long direct
         * download. Each running task still chunks internally via
         * [ParallelDownloader].
         */
        private const val MAX_CONCURRENT = 3

        /**
         * Latest-wins reference exposed to [KumoriyaDownloadService] so it
         * can dispatch notification actions without Binder plumbing. The
         * value is set in `init` and cleared in [destroy]. Nullable in
         * callers because the FGS might receive a legacy action intent
         * after the plugin detached.
         */
        @Volatile
        internal var shared: DownloadEngine? = null
            private set
    }
}

// ── Data classes ─────────────────────────────────────────────────────────────

/**
 * Parameters passed from Dart per enqueue call. Mirrors the MethodChannel
 * argument map.
 */
internal data class DownloadParams(
    val taskId: String,
    val url: String,
    val headers: Map<String, String>,
    val fileName: String,
    val isHls: Boolean,
    val targetDir: String,
    val animeTitle: String,
    val serverName: String?,
    val qualityLabel: String?,
    /**
     * HLS-only: when `true` the concatenated `.ts` is remuxed to `.mp4`
     * via Media3 Transformer; when `false` the `.ts` is kept as-is and
     * renamed to the final file. Default `true` (remux on).
     */
    val remuxToMp4: Boolean = true,
)

/** Download status emitted to Dart via EventChannel. */
internal enum class DownloadStatus {
    PENDING,
    DOWNLOADING,
    PAUSED,
    COMPLETED,
    FAILED,
    CANCELLED,
    REMUXING,
    /**
     * Emitted when the network drops mid-transfer (UnknownHostException,
     * ConnectException, SocketTimeoutException, generic IOException that
     * isn't a server-side HTTP failure). The engine preserves partial
     * bytes; a future [NetworkMonitor] will auto-resume, and the UI
     * exposes a distinct "Sin conexión" label so the user knows the
     * cause is not their fault.
     */
    DISCONNECTED,
}
