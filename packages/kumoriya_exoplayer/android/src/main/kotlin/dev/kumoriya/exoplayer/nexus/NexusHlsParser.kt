package dev.kumoriya.exoplayer.nexus

import android.net.Uri

/**
 * Minimal HLS master playlist parser tuned for anime.nexus layouts.
 *
 * The native pipeline does NOT rewrite variant or segment manifests: Media3
 * handles those once our [NexusDataSource] attaches the signed query
 * params. The only reason to parse the master is to expose the available
 * video qualities + audio groups to the Dart UI (and for diagnostics).
 *
 * anime.nexus variant paths are stable:
 *   `<base>_<variant>-<track>.m3u8`  for video & audio playlists
 *   `<base>_<variant>_<NNNN>-<track>.m4s|.mp4` for segment / init files
 *
 * Track 0 is video, track 1+ are audio groups; variant is the quality
 * bucket (a numeric id assigned by the backend).
 */
internal class NexusHlsParser {

    data class VariantMetadata(val variant: String, val track: Int)

    data class AudioEntry(
        val groupId: String,
        val uri: Uri,
        val metadata: VariantMetadata,
    )

    data class VideoStream(
        val uri: Uri,
        val audioGroupId: String?,
        val qualityLabel: String,
        val metadata: VariantMetadata,
    )

    data class Master(
        val audios: List<AudioEntry>,
        val streams: List<VideoStream>,
    )

    fun parseMaster(body: String, baseUri: Uri): Master {
        val audios = ArrayList<AudioEntry>()
        val streams = ArrayList<VideoStream>()
        val lines = body.split('\n')

        var index = 0
        while (index < lines.size) {
            val raw = lines[index]
            val line = raw.trim()

            if (line.startsWith("#EXT-X-MEDIA")) {
                val attrs = parseAttributes(line)
                if (attrs["TYPE"] == "AUDIO") {
                    val groupId = attrs["GROUP-ID"]?.trim().orEmpty()
                    val uriValue = attrs["URI"]?.trim().orEmpty()
                    if (groupId.isNotEmpty() && uriValue.isNotEmpty()) {
                        val uri = resolve(baseUri, uriValue)
                        val meta = parseVariantMetadata(uri)
                        if (meta != null) {
                            audios.add(
                                AudioEntry(
                                    groupId = groupId,
                                    uri = uri,
                                    metadata = meta,
                                ),
                            )
                        }
                    }
                }
                index++
                continue
            }

            if (line.startsWith("#EXT-X-STREAM-INF") && index + 1 < lines.size) {
                val attrs = parseAttributes(line)
                val uriLine = lines[index + 1].trim()
                if (uriLine.isNotEmpty() && !uriLine.startsWith('#')) {
                    val uri = resolve(baseUri, uriLine)
                    val meta = parseVariantMetadata(uri)
                    if (meta != null) {
                        streams.add(
                            VideoStream(
                                uri = uri,
                                audioGroupId = attrs["AUDIO"]?.trim(),
                                qualityLabel = qualityLabel(attrs),
                                metadata = meta,
                            ),
                        )
                    }
                }
                index += 2
                continue
            }

            index++
        }

        return Master(audios = audios, streams = streams)
    }

    companion object {
        private val VARIANT_RE = Regex("""_([0-9]+)-([0-9]+)\.m3u8$""")
        private val ATTR_RE = Regex("""([A-Z0-9-]+)=("[^"]*"|[^,]+)""")

        fun parseVariantMetadata(uri: Uri): VariantMetadata? {
            val match = VARIANT_RE.find(uri.path.orEmpty()) ?: return null
            val variant = match.groupValues[1]
            val track = match.groupValues[2].toIntOrNull() ?: return null
            return VariantMetadata(variant = variant, track = track)
        }

        fun parseAttributes(line: String): Map<String, String> {
            val out = LinkedHashMap<String, String>()
            for (m in ATTR_RE.findAll(line)) {
                val key = m.groupValues[1]
                var value = m.groupValues[2].trim()
                if (value.startsWith('"') && value.endsWith('"')) {
                    value = value.substring(1, value.length - 1)
                }
                out[key] = value
            }
            return out
        }

        private fun qualityLabel(attrs: Map<String, String>): String {
            val resolution = attrs["RESOLUTION"]
            if (resolution != null) {
                val match = Regex("""(\d+)x(\d+)""").find(resolution)
                if (match != null) return "${match.groupValues[2]}p"
            }
            val bandwidth = attrs["BANDWIDTH"]?.toIntOrNull() ?: 0
            val kbps = bandwidth / 1000
            return when {
                kbps >= 8000 -> "2160p"
                kbps >= 4000 -> "1080p"
                kbps >= 1500 -> "720p"
                kbps >= 800 -> "480p"
                kbps >= 400 -> "360p"
                kbps > 0 -> "240p"
                else -> "auto"
            }
        }

        private fun resolve(base: Uri, ref: String): Uri {
            return Uri.parse(
                java.net.URI(base.toString()).resolve(ref).toString(),
            )
        }
    }
}
