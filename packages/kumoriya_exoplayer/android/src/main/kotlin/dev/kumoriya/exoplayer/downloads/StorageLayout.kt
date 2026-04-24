package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.os.StatFs
import java.io.File

/**
 * Filesystem layout for downloads.
 *
 * **Tmp dir** (app-private, invisible to user):
 * `{filesDir}/kumoriya/downloads/tmp/{taskId}/`
 *
 * **Final dir** (user-chosen via [DownloadDirectoryService]):
 * Passed per-task by Dart at enqueue time as `targetDir`.
 */
internal object StorageLayout {

    // ── Tmp paths ───────────────────────────────────────────────────────

    /** Root of all tmp download working directories. */
    fun tmpRoot(context: Context): File =
        File(context.filesDir, "kumoriya/downloads/tmp")

    /** Working directory for a single task's segments / partial file. */
    fun tmpTaskDir(context: Context, taskId: String): File =
        File(tmpRoot(context), taskId)

    /** State manifest within a task's tmp directory. */
    fun stateManifest(context: Context, taskId: String): File =
        File(tmpTaskDir(context, taskId), ".state.json")

    // ── Sanitization ────────────────────────────────────────────────────

    private val UNSAFE_CHARS = Regex("[\\\\/:*?\"<>|]")

    /** Remove characters unsafe in FAT32/NTFS/ext4 filenames. */
    fun sanitize(name: String): String =
        name.replace(UNSAFE_CHARS, "_").trim().take(200)

    // ── Storage checks ──────────────────────────────────────────────────

    /** Available bytes on the partition that contains [dir]. */
    fun availableBytes(dir: File): Long {
        if (!dir.exists()) dir.mkdirs()
        return try {
            StatFs(dir.absolutePath).availableBytes
        } catch (_: Exception) {
            0L
        }
    }

    // ── Cleanup ─────────────────────────────────────────────────────────

    /** Delete a task's entire tmp directory tree. */
    fun deleteTmpTask(context: Context, taskId: String) {
        tmpTaskDir(context, taskId).deleteRecursively()
    }

    /** Sweep orphaned tmp directories that have no corresponding active task. */
    fun sweepOrphans(context: Context, activeTaskIds: Set<String>) {
        val root = tmpRoot(context)
        if (!root.isDirectory) return
        root.listFiles()?.forEach { dir ->
            if (dir.isDirectory && dir.name !in activeTaskIds) {
                dir.deleteRecursively()
            }
        }
    }
}
