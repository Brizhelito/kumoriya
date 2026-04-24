package dev.kumoriya.exoplayer

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import dev.kumoriya.exoplayer.downloads.DownloadChannels
import java.util.concurrent.Executors

/**
 * Fase 1 plugin entrypoint.
 *
 * Owns the single MethodChannel `dev.kumoriya.exoplayer/methods` and routes
 * incoming calls to the proper [PlayerInstance] via [PlayerRegistry].
 * ExoPlayer objects live on the Android main thread, so every player call
 * is marshalled there via [mainHandler] even if the MethodChannel
 * callback arrives from another thread.
 */
class KumoriyaExoPlayerPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var registry: PlayerRegistry
    private var downloadChannels: DownloadChannels? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Background executor for blocking IO (anime.nexus bootstrap, WS
     * handshake). Single-threaded to keep openNexus serialized per plugin
     * instance — concurrent bootstraps on the same cookie jar would race.
     */
    private val ioExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "kumoriya-nexus-io").apply { isDaemon = true }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_METHODS)
        channel.setMethodCallHandler(this)

        registry = PlayerRegistry(
            context = binding.applicationContext,
            binaryMessenger = binding.binaryMessenger,
            textures = binding.textureRegistry,
        )

        downloadChannels = DownloadChannels(
            context = binding.applicationContext,
            messenger = binding.binaryMessenger,
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "ping" -> result.success("pong")
            "create" -> onMain(result) {
                val instance = registry.create()
                mapOf("textureId" to instance.textureId)
            }
            "open" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val url = call.requireString("url")
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers").orEmpty()
                val startPositionMs = call.argument<Number>("startPositionMs")?.toLong()
                val mimeType = call.argument<String>("mimeType")
                registry.require(textureId).open(
                    url,
                    headers,
                    startPositionMs,
                    mimeType,
                )
                null
            }
            "play" -> onMain(result) {
                registry.require(call.requireLong("textureId")).play()
                null
            }
            "pause" -> onMain(result) {
                registry.require(call.requireLong("textureId")).pause()
                null
            }
            "seek" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val positionMs = call.requireLong("positionMs")
                registry.require(textureId).seekTo(positionMs)
                null
            }
            "setVolume" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val value = call.requireDouble("value").toFloat()
                registry.require(textureId).setVolume(value)
                null
            }
            "setSpeed" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val rate = call.requireDouble("rate").toFloat()
                registry.require(textureId).setSpeed(rate)
                null
            }
            "selectAudioTrack" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val trackId = call.requireString("trackId")
                registry.require(textureId).selectAudioTrack(trackId)
                null
            }
            "selectVideoTrack" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val trackId = call.requireString("trackId")
                registry.require(textureId).selectVideoTrack(trackId)
                null
            }
            "clearVideoTrackOverride" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                registry.require(textureId).clearVideoTrackOverride()
                null
            }
            "selectSubtitleTrack" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val trackId = call.requireString("trackId")
                registry.require(textureId).selectSubtitleTrack(trackId)
                null
            }
            "setPreferredSubtitleLanguages" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val languages = call.argument<List<String>>("languages").orEmpty()
                registry.require(textureId).setPreferredSubtitleLanguages(languages)
                null
            }
            "clearSubtitleTrack" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                registry.require(textureId).clearSubtitleTrack()
                null
            }
            "addExternalSubtitle" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val uri = call.requireString("uri")
                val mimeType = call.requireString("mimeType")
                val language = call.argument<String>("language")
                val label = call.argument<String>("label")
                registry.require(textureId).addExternalSubtitle(
                    uri = uri,
                    mimeType = mimeType,
                    language = language,
                    label = label,
                )
                null
            }
            "clearExternalSubtitles" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                registry.require(textureId).clearExternalSubtitles()
                null
            }
            "setOverallGainDb" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val db = call.requireDouble("db")
                registry.require(textureId).setOverallGainDb(db)
                null
            }
            "setVoiceClarity" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val strength = call.requireDouble("strength")
                registry.require(textureId).setVoiceClarity(strength)
                null
            }
            "setDiagnosticsEnabled" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val enabled = call.argument<Boolean>("enabled") ?: false
                registry.require(textureId).setDiagnosticsEnabled(enabled)
                null
            }
            "swapUrl" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                val url = call.requireString("url")
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers").orEmpty()
                val mimeType = call.argument<String>("mimeType")
                val startPositionMs = call.argument<Number>("startPositionMs")?.toLong()
                registry.require(textureId).swapUrl(
                    url = url,
                    headers = headers,
                    mimeType = mimeType,
                    startPositionMs = startPositionMs,
                )
                null
            }
            "dispose" -> onMain(result) {
                val textureId = call.requireLong("textureId")
                registry.dispose(textureId)
            }
            "openNexus" -> {
                val textureId = try {
                    call.requireLong("textureId")
                } catch (t: Throwable) {
                    result.error("bad_args", t.message ?: "openNexus args", null)
                    return
                }
                val watchUrl = try {
                    call.requireString("watchUrl")
                } catch (t: Throwable) {
                    result.error("bad_args", t.message ?: "openNexus args", null)
                    return
                }
                val startPositionMs = call.argument<Number>("startPositionMs")
                    ?.toLong()
                ioExecutor.execute {
                    try {
                        val instance = registry.require(textureId)
                        // Phase 1 on IO: blocking HTTP bootstrap + WS handshake.
                        val session = instance.bootstrapNexusSession(watchUrl)
                        // Phase 2 on main: hand the prepared session to
                        // ExoPlayer's setMediaSource + prepare.
                        mainHandler.post {
                            try {
                                instance.attachNexusSession(
                                    session,
                                    startPositionMs,
                                )
                                result.success(null)
                            } catch (t: Throwable) {
                                session.close()
                                result.error(
                                    t::class.java.simpleName,
                                    t.message ?: "unknown",
                                    null,
                                )
                            }
                        }
                    } catch (t: Throwable) {
                        mainHandler.post {
                            result.error(
                                t::class.java.simpleName,
                                t.message ?: "unknown",
                                null,
                            )
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mainHandler.post { registry.disposeAll() }
        channel.setMethodCallHandler(null)
        downloadChannels?.detach()
        downloadChannels = null
        ioExecutor.shutdown()
    }

    /**
     * Hops to the main thread, runs [block] and forwards its return value
     * (or exception) to the Flutter [Result]. `null` return is serialised
     * as `null` (void) on the Dart side.
     */
    private fun onMain(result: Result, block: () -> Any?) {
        val work = Runnable {
            try {
                result.success(block())
            } catch (t: Throwable) {
                result.error(
                    t::class.java.simpleName,
                    t.message ?: "unknown",
                    null,
                )
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            work.run()
        } else {
            mainHandler.post(work)
        }
    }

    companion object {
        const val CHANNEL_METHODS = "dev.kumoriya.exoplayer/methods"
    }
}

// --- MethodCall helpers ---------------------------------------------------

private fun MethodCall.requireLong(key: String): Long =
    argument<Number>(key)?.toLong()
        ?: throw IllegalArgumentException("missing long arg '$key'")

private fun MethodCall.requireDouble(key: String): Double =
    argument<Number>(key)?.toDouble()
        ?: throw IllegalArgumentException("missing double arg '$key'")

private fun MethodCall.requireString(key: String): String =
    argument<String>(key)
        ?: throw IllegalArgumentException("missing string arg '$key'")
