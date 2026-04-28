package dev.kumoriya.exoplayer.downloads

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.DefaultExtractorInput
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.PositionHolder
import androidx.media3.extractor.SeekMap
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.TrackOutput.CryptoData
import androidx.media3.extractor.mp4.FragmentedMp4Extractor
import androidx.media3.muxer.BufferInfo
import androidx.media3.muxer.Mp4Muxer
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer

/**
 * Transmuxes a concatenated fragmented MP4 stream (init segment +
 * raw HLS/CMAF media segments appended in playlist order) to a flat
 * (non-fragmented) MP4 file with proper sample-table indexes
 * (`stco/co64`, `stsc`, `stsz`, `stts`, `ctts`).
 *
 * Why this exists instead of [HlsRemuxer]:
 *
 * - [HlsRemuxer] uses Media3 [androidx.media3.transformer.Transformer]
 *   which spins up a full ExoPlayer asset loader pipeline (player
 *   loop, message threads, decoder/encoder slots, listener events)
 *   even for a pure transmux. On a 24-minute AV1 episode (~170MB)
 *   this was measured at 30s on a mid-range device.
 *
 * - This class reads the input via [FragmentedMp4Extractor] and
 *   writes via [Mp4Muxer] directly, with no decoder/encoder/player
 *   in between. Pure extract-and-rewrite.
 *
 * Why this works while manual concat doesn't:
 *
 * - The extractor is the canonical Media3 implementation that knows
 *   how to handle every CMAF/fMP4 quirk: per-segment styp/sidx,
 *   tfdt continuity across moofs, edit lists for AAC priming,
 *   trex defaults, multi-track interleaving, etc. We delegate ALL
 *   container parsing to it.
 *
 * - The muxer is the canonical Media3 implementation that emits a
 *   spec-compliant flat MP4 with correct index tables. Players
 *   read it as a regular non-fragmented MP4 — duration, seek and
 *   A/V sync all work without any post-hoc patching.
 */
@UnstableApi
internal object Mp4Transmuxer {

    private const val TAG = "Mp4Transmuxer"

    /**
     * Transmux [input] (concatenated fMP4) into [output] (flat MP4).
     *
     * Blocking. Throws [Mp4TransmuxException] on container errors,
     * [java.io.IOException] on disk errors. The caller is
     * responsible for cleaning up [input]/[output] on failure.
     */
    fun transmux(input: File, output: File, taskId: String) {
        require(input.exists() && input.length() > 0) {
            "transmux input missing or empty: $input"
        }
        if (output.exists()) output.delete()
        output.parentFile?.mkdirs()

        val raf = RandomAccessFile(input, "r")
        var fos: FileOutputStream? = null
        var muxer: Mp4Muxer? = null
        var extractor: FragmentedMp4Extractor? = null
        try {
            fos = FileOutputStream(output)
            muxer = Mp4Muxer.Builder(fos).build()
            val bridge = ExtractorOutputBridge(muxer, taskId)
            extractor = FragmentedMp4Extractor()
            extractor.init(bridge)

            val dataReader = SeekableDataReader(raf)
            var extractorInput: ExtractorInput = DefaultExtractorInput(
                dataReader, /* position= */ 0L, /* length= */ raf.length(),
            )
            val positionHolder = PositionHolder()
            var iterations = 0
            loop@ while (true) {
                iterations++
                val result = extractor.read(extractorInput, positionHolder)
                when (result) {
                    Extractor.RESULT_CONTINUE -> {
                        // keep reading
                    }
                    Extractor.RESULT_SEEK -> {
                        // Re-anchor the input at the requested position.
                        // FragmentedMp4Extractor rarely seeks during a
                        // forward read; it can happen when the moov
                        // appears after some moof boxes, etc.
                        raf.seek(positionHolder.position)
                        extractorInput = DefaultExtractorInput(
                            dataReader,
                            positionHolder.position,
                            raf.length(),
                        )
                    }
                    Extractor.RESULT_END_OF_INPUT -> break@loop
                    else -> throw Mp4TransmuxException(
                        "unexpected extractor result=$result after $iterations reads",
                    )
                }
            }
            Log.i(
                TAG,
                "$taskId: extractor finished after $iterations reads, " +
                    "tracks=${bridge.collectorCount}, " +
                    "samples=${bridge.totalSamples}",
            )
        } catch (t: Throwable) {
            output.delete()
            throw if (t is Mp4TransmuxException) t
            else Mp4TransmuxException("transmux failed: ${t.message}", t)
        } finally {
            try { extractor?.release() } catch (_: Throwable) {}
            try { muxer?.close() } catch (_: Throwable) {}
            try { fos?.close() } catch (_: Throwable) {}
            try { raf.close() } catch (_: Throwable) {}
        }
    }

    /**
     * [DataReader] backed by a [RandomAccessFile]. The
     * [DefaultExtractorInput] only consumes forward; we drive
     * non-sequential repositioning explicitly via [RandomAccessFile.seek]
     * when [Extractor.RESULT_SEEK] is returned.
     */
    private class SeekableDataReader(
        private val raf: RandomAccessFile,
    ) : DataReader {
        override fun read(target: ByteArray, offset: Int, length: Int): Int {
            val n = raf.read(target, offset, length)
            return if (n == -1) C.RESULT_END_OF_INPUT else n
        }
    }

    /**
     * Bridges [ExtractorOutput]/[TrackOutput] callbacks emitted by
     * [FragmentedMp4Extractor] into [Mp4Muxer.addTrack] /
     * [Mp4Muxer.writeSampleData] calls.
     */
    private class ExtractorOutputBridge(
        private val muxer: Mp4Muxer,
        private val taskId: String,
    ) : ExtractorOutput {

        private val collectors = HashMap<Int, SampleCollector>()

        val collectorCount: Int get() = collectors.size
        val totalSamples: Long
            get() = collectors.values.sumOf { it.sampleCount }

        override fun track(id: Int, type: Int): TrackOutput {
            val existing = collectors[id]
            if (existing != null) return existing
            val created = SampleCollector(muxer, taskId, extractorTrackId = id)
            collectors[id] = created
            return created
        }

        override fun endTracks() {
            // No-op. The Mp4Muxer doesn't require an explicit "tracks
            // sealed" call — addTrack on first format() is enough.
        }

        override fun seekMap(seekMap: SeekMap) {
            // We don't use the extractor's seek map for transmux —
            // samples come in DTS order naturally for fmp4 and the
            // muxer builds its own index from the metadata we feed.
        }
    }

    /**
     * Per-track sample accumulator. Buffers bytes from
     * [TrackOutput.sampleData] calls until [TrackOutput.sampleMetadata]
     * commits a complete sample, at which point the bytes are
     * forwarded to the muxer.
     *
     * The buffer is grown on demand. For fMP4 transmux, the
     * extractor commits samples right after their bytes arrive
     * (offset == 0), so the buffer is reset to length 0 after each
     * commit and never grows unboundedly. We support `offset > 0`
     * defensively per the [TrackOutput] contract.
     */
    private class SampleCollector(
        private val muxer: Mp4Muxer,
        private val taskId: String,
        private val extractorTrackId: Int,
    ) : TrackOutput {

        private var muxerTrackIndex: Int = -1
        private var format: Format? = null
        private var buffer: ByteArray = ByteArray(64 * 1024)
        private var bufferLen: Int = 0
        var sampleCount: Long = 0L
            private set

        override fun format(format: Format) {
            this.format = format
            if (muxerTrackIndex < 0) {
                muxerTrackIndex = muxer.addTrack(format)
                Log.i(
                    TAG,
                    "$taskId: registered track extractorId=$extractorTrackId " +
                        "muxerIdx=$muxerTrackIndex mime=${format.sampleMimeType} " +
                        "codecs=${format.codecs}",
                )
            } else {
                // Format updates after registration would require
                // editing the muxer's track header — we don't expect
                // this in fMP4 (codec config is stable in moov).
                Log.w(
                    TAG,
                    "$taskId: track $extractorTrackId format updated post-registration; ignored",
                )
            }
        }

        override fun sampleData(
            input: DataReader,
            length: Int,
            allowEndOfInput: Boolean,
            sampleDataPart: Int,
        ): Int {
            // Encryption / supplemental data is bypassed for transmux;
            // the muxer doesn't accept these out of band.
            if (sampleDataPart != TrackOutput.SAMPLE_DATA_PART_MAIN) {
                return input.read(ByteArray(length), 0, length).also { read ->
                    if (read == C.RESULT_END_OF_INPUT && allowEndOfInput) return read
                }
            }
            ensureCapacity(bufferLen + length)
            var totalRead = 0
            while (totalRead < length) {
                val n = input.read(buffer, bufferLen + totalRead, length - totalRead)
                if (n == C.RESULT_END_OF_INPUT) {
                    if (totalRead == 0 && allowEndOfInput) {
                        return C.RESULT_END_OF_INPUT
                    }
                    break
                }
                totalRead += n
            }
            bufferLen += totalRead
            return totalRead
        }

        override fun sampleData(data: ParsableByteArray, length: Int, sampleDataPart: Int) {
            if (length <= 0) return
            if (sampleDataPart != TrackOutput.SAMPLE_DATA_PART_MAIN) {
                data.skipBytes(length)
                return
            }
            ensureCapacity(bufferLen + length)
            data.readBytes(buffer, bufferLen, length)
            bufferLen += length
        }

        override fun sampleMetadata(
            timeUs: Long,
            flags: Int,
            size: Int,
            offset: Int,
            cryptoData: CryptoData?,
        ) {
            if (muxerTrackIndex < 0) {
                throw Mp4TransmuxException(
                    "sampleMetadata before format on track $extractorTrackId",
                )
            }
            if (cryptoData != null) {
                // We don't transmux DRM-protected streams — they would
                // require feeding sample encryption metadata through a
                // muxer that supports it, which Mp4Muxer doesn't on
                // the path we use here. HLS streams from anime sources
                // are clear; bail loudly if a DRM track ever shows up.
                throw Mp4TransmuxException(
                    "encrypted samples on track $extractorTrackId not supported",
                )
            }
            val sampleEnd = bufferLen - offset
            val sampleStart = sampleEnd - size
            if (sampleStart < 0 || sampleEnd > bufferLen) {
                throw Mp4TransmuxException(
                    "sample range OOB: track=$extractorTrackId start=$sampleStart " +
                        "end=$sampleEnd bufferLen=$bufferLen size=$size offset=$offset",
                )
            }
            val sampleBuf = ByteBuffer.wrap(buffer, sampleStart, size).slice()
            val info = BufferInfo(timeUs, size, flags)
            muxer.writeSampleData(muxerTrackIndex, sampleBuf, info)
            sampleCount++
            // Reclaim the prefix that's been committed. For typical
            // fMP4 (offset == 0) this resets the buffer; otherwise we
            // shift the trailing `offset` bytes to the front.
            if (offset == 0) {
                bufferLen = 0
            } else {
                System.arraycopy(buffer, sampleEnd, buffer, 0, offset)
                bufferLen = offset
            }
        }

        private fun ensureCapacity(needed: Int) {
            if (buffer.size >= needed) return
            var newSize = buffer.size
            while (newSize < needed) newSize *= 2
            buffer = buffer.copyOf(newSize)
        }
    }
}

internal class Mp4TransmuxException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
