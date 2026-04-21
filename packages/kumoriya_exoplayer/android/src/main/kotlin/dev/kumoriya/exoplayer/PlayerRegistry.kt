package dev.kumoriya.exoplayer

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.view.TextureRegistry
import java.util.concurrent.ConcurrentHashMap

/**
 * Map of `textureId -> PlayerInstance` scoped to the plugin binding.
 *
 * Owns the wiring between the Flutter binary messenger, the Android
 * [Context] and every live `ExoPlayer` managed by the plugin.
 */
class PlayerRegistry(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val textures: TextureRegistry,
) {
    private val instances = ConcurrentHashMap<Long, PlayerInstance>()

    fun create(): PlayerInstance {
        val entry = textures.createSurfaceTexture()
        val instance = PlayerInstance(context, entry, binaryMessenger)
        instances[instance.textureId] = instance
        return instance
    }

    fun get(textureId: Long): PlayerInstance? = instances[textureId]

    fun require(textureId: Long): PlayerInstance =
        instances[textureId]
            ?: throw IllegalStateException("No PlayerInstance for textureId=$textureId")

    fun dispose(textureId: Long): Boolean {
        val removed = instances.remove(textureId) ?: return false
        removed.release()
        return true
    }

    fun disposeAll() {
        val snapshot = instances.values.toList()
        instances.clear()
        snapshot.forEach { it.release() }
    }

    fun size(): Int = instances.size
}
