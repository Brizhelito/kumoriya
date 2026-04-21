package dev.kumoriya.exoplayer.nexus

import org.json.JSONObject

/**
 * Mirror of Dart `NexusStreamToken`.
 *
 * Tokens look like `"1773305579_df60ad1571a525e89085e88992fc61ce23073fe4"`
 * — a Unix timestamp + an opaque server-side hash joined with `_`. The
 * anime.nexus CDN rejects requests whose timestamp is more than ~5 min
 * old, so [expiresAtMillis] is a conservative invalidation hint.
 */
internal data class NexusStreamToken(
    val token: String,
    val timestamp: Long,
    val hash: String,
) {
    val expiresAtMillis: Long
        get() = timestamp * 1000L + 5 * 60 * 1000L

    companion object {
        fun fromJson(obj: JSONObject): NexusStreamToken {
            val token = obj.optString("token").trim()
            var timestamp = obj.optLong("timestamp", 0L)
            var hash = obj.optString("hash", "").trim()

            if ((timestamp == 0L || hash.isEmpty()) && token.contains('_')) {
                val parts = token.split('_')
                if (parts.size == 2) {
                    if (timestamp == 0L) timestamp = parts[0].toLongOrNull() ?: 0L
                    if (hash.isEmpty()) hash = parts[1]
                }
            }
            return NexusStreamToken(token = token, timestamp = timestamp, hash = hash)
        }
    }
}
