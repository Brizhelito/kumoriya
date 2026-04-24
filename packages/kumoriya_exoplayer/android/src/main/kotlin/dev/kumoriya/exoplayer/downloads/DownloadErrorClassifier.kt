package dev.kumoriya.exoplayer.downloads

import android.system.ErrnoException
import android.system.OsConstants
import java.io.IOException

/**
 * Classifies download failures into a small set of actions the engine can
 * take. Keeps the retry logic in one place so [DownloadEngine] can stay
 * focused on coroutine/job wiring.
 *
 * Decision rules (per plan Fase 8):
 * - 401 / 403 / 410 → [Action.FailFast]: credentials dead, no retry will
 *   help.
 * - 404             → [Action.RetryOnce]: transient CDN lookup hiccups
 *   are common; one retry resolves most of them without user input.
 * - 5xx / timeouts  → [Action.RetryBackoff]: exponential 1/2/4/8/16s with
 *   a cap at 5 attempts.
 * - [DownloadIOException] / 416       → [Action.FailFast].
 * - ENOSPC / "No space left"          → [Action.StorageFull].
 * - Any other [IOException]           → [Action.Disconnected]: network
 *   level fault, the engine parks the task for auto-resume on reconnect.
 */
internal object DownloadErrorClassifier {

    sealed interface Action {
        /** Permanent failure — emit FAILED immediately. */
        data class FailFast(val code: String) : Action

        /** Single retry with no backoff, then FAILED. */
        data class RetryOnce(val code: String) : Action

        /** Exponential retry capped at [MAX_BACKOFF_ATTEMPTS]. */
        data class RetryBackoff(val code: String) : Action

        /** Disk full — park as FAILED with a distinctive code. */
        object StorageFull : Action

        /** Network-level error — surface as DISCONNECTED. */
        object Disconnected : Action
    }

    fun classify(e: Throwable): Action {
        if (e is DownloadHttpException) {
            return when (e.httpCode) {
                401 -> Action.FailFast("download.auth_required")
                403 -> Action.FailFast("download.forbidden")
                410 -> Action.FailFast("download.gone")
                416 -> Action.FailFast("download.range_not_satisfiable")
                404 -> Action.RetryOnce("download.not_found")
                in 500..599 -> Action.RetryBackoff("download.server_error_${e.httpCode}")
                408, 429 -> Action.RetryBackoff("download.http_${e.httpCode}")
                else -> Action.FailFast("download.http_${e.httpCode}")
            }
        }

        if (e is DownloadIOException) {
            return Action.FailFast("download.io_error")
        }

        if (isDiskFull(e)) {
            return Action.StorageFull
        }

        if (e is java.net.SocketTimeoutException) {
            return Action.RetryBackoff("download.timeout")
        }

        if (e is IOException) {
            return Action.Disconnected
        }

        return Action.FailFast("download.unexpected")
    }

    /** Walks the cause chain for ENOSPC (safe on API <26 where constant missing). */
    private fun isDiskFull(e: Throwable): Boolean {
        var current: Throwable? = e
        while (current != null) {
            if (current is ErrnoException && current.errno == OsConstants.ENOSPC) return true
            // Not every OEM surfaces ErrnoException; fall back to the
            // message prefix emitted by libcore's write() wrapper.
            val msg = current.message ?: ""
            if (msg.contains("ENOSPC", ignoreCase = true) ||
                msg.contains("No space left", ignoreCase = true)
            ) return true
            current = current.cause
        }
        return false
    }

    /**
     * Compute the delay for attempt N of a [Action.RetryBackoff]. First
     * retry waits 1s, then 2s, 4s, 8s, 16s — capped there.
     */
    fun backoffMillis(attempt: Int): Long {
        val clamped = attempt.coerceIn(1, MAX_BACKOFF_ATTEMPTS)
        return 1000L shl (clamped - 1)
    }

    const val MAX_BACKOFF_ATTEMPTS = 5
}
