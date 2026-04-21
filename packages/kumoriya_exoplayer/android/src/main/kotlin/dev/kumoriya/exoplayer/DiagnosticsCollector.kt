package dev.kumoriya.exoplayer

import androidx.media3.common.Format
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.analytics.AnalyticsListener

/**
 * Collects the runtime playback stats that back the Fase 5 diagnostics
 * overlay. Mutable-in-place by design — a single instance is attached
 * to the ExoPlayer when diagnostics are enabled and
 * [PlayerInstance.emitDiagnosticsSnapshot] reads its current fields on a
 * polling cadence.
 *
 * Every Media3 callback the overlay cares about updates a field and
 * returns — no event fan-out from inside the listener so the audio /
 * video renderer threads never block on Flutter's event channel.
 */
internal class DiagnosticsCollector : AnalyticsListener {

    var droppedVideoFrames: Long = 0L
        private set
    var renderedVideoFrames: Long = 0L
        private set

    var videoCodec: String? = null
        private set
    var videoDecoder: String? = null
        private set
    var videoBitrate: Int = 0
        private set
    var videoHardwareAccelerated: Boolean? = null
        private set

    var audioCodec: String? = null
        private set
    var audioSampleRate: Int = 0
        private set
    var audioChannels: Int = 0
        private set

    var bandwidthBps: Long = 0L
        private set

    fun reset() {
        droppedVideoFrames = 0L
        renderedVideoFrames = 0L
        videoCodec = null
        videoDecoder = null
        videoBitrate = 0
        videoHardwareAccelerated = null
        audioCodec = null
        audioSampleRate = 0
        audioChannels = 0
        bandwidthBps = 0L
    }

    // --- AnalyticsListener overrides ------------------------------------

    override fun onDroppedVideoFrames(
        eventTime: AnalyticsListener.EventTime,
        droppedFrames: Int,
        elapsedMs: Long,
    ) {
        droppedVideoFrames += droppedFrames.toLong()
    }

    override fun onRenderedFirstFrame(
        eventTime: AnalyticsListener.EventTime,
        output: Any,
        renderTimeMs: Long,
    ) {
        renderedVideoFrames += 1L
    }

    override fun onVideoInputFormatChanged(
        eventTime: AnalyticsListener.EventTime,
        format: Format,
        decoderReuseEvaluation: DecoderReuseEvaluation?,
    ) {
        videoCodec = format.codecs ?: format.sampleMimeType
        videoBitrate = format.bitrate.takeIf { it > 0 } ?: videoBitrate
    }

    override fun onVideoDecoderInitialized(
        eventTime: AnalyticsListener.EventTime,
        decoderName: String,
        initializedTimestampMs: Long,
        initializationDurationMs: Long,
    ) {
        videoDecoder = decoderName
        // AOSP convention: the stock software decoders live under
        // `OMX.google.*` and the Exo-bundled ones include `.sw.` in the
        // name. Everything else is vendor hardware.
        videoHardwareAccelerated = !(
            decoderName.startsWith("OMX.google.") ||
                decoderName.contains(".sw.") ||
                decoderName.contains("software", ignoreCase = true)
            )
    }

    override fun onAudioInputFormatChanged(
        eventTime: AnalyticsListener.EventTime,
        format: Format,
        decoderReuseEvaluation: DecoderReuseEvaluation?,
    ) {
        audioCodec = format.codecs ?: format.sampleMimeType
        if (format.sampleRate > 0) audioSampleRate = format.sampleRate
        if (format.channelCount > 0) audioChannels = format.channelCount
    }

    override fun onBandwidthEstimate(
        eventTime: AnalyticsListener.EventTime,
        totalLoadTimeMs: Int,
        totalBytesLoaded: Long,
        bitrateEstimate: Long,
    ) {
        bandwidthBps = bitrateEstimate
    }
}
