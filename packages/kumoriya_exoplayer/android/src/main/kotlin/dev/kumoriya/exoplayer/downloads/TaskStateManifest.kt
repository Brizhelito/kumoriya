package dev.kumoriya.exoplayer.downloads

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream

/**
 * Persistent state for a single download task.
 *
 * Written atomically (`.tmp` → fsync → rename) so a crash mid-write never
 * corrupts the manifest. Read on resume to know which segments are done.
 */
@Serializable
internal data class TaskStateManifest(
    val taskId: String,
    val kind: DownloadKind,
    val totalSegments: Int = 0,
    val completedSegments: Int = 0,
    val downloadedBytes: Long = 0L,
    val totalBytes: Long = 0L,
    /** Segment indices that have been fully written and fsynced. */
    val doneSegments: Set<Int> = emptySet(),
) {
    @Serializable
    enum class DownloadKind { DIRECT, HLS }

    companion object {
        private val json = Json {
            ignoreUnknownKeys = true
            prettyPrint = false
        }

        /** Read from disk. Returns `null` if missing or corrupt. */
        fun readOrNull(file: File): TaskStateManifest? = try {
            if (file.exists()) json.decodeFromString(file.readText()) else null
        } catch (_: Exception) {
            null
        }
    }

    /** Atomic write: tmp → fsync → rename. */
    fun writeTo(file: File) {
        val parent = file.parentFile ?: return
        if (!parent.exists()) parent.mkdirs()

        val tmp = File(parent, "${file.name}.tmp")
        FileOutputStream(tmp).use { fos ->
            fos.write(json.encodeToString(this).toByteArray())
            fos.fd.sync()
        }
        tmp.renameTo(file)
    }
}
