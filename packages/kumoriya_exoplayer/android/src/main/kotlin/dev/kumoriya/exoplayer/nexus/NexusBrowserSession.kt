package dev.kumoriya.exoplayer.nexus

import java.security.SecureRandom

/**
 * Mirror of `NexusBrowserSession.generate()` from the Dart resolver.
 *
 * Every playback session opens a brand new browser-like identity: a UUIDv4
 * fingerprint and a synthetic `sid=<hex>` seed cookie. The real anime.nexus
 * reference implementation (`createBrowserSession` in the web SPA) does the
 * same — the server binds session state to the seeded `sid` from the very
 * first HTTP hit, without it the WebSocket auth handshake fails with
 * `Authentication failed`.
 */
internal class NexusBrowserSession private constructor(
    val fingerprint: String,
    val seedCookieHeader: String,
) {
    companion object {
        fun generate(): NexusBrowserSession {
            val rng = SecureRandom()
            val fingerprint = uuidV4(rng)
            val sid = hex(rng, 16)
            return NexusBrowserSession(
                fingerprint = fingerprint,
                seedCookieHeader = "sid=$sid",
            )
        }

        fun withFingerprint(fingerprint: String, seedCookieHeader: String = ""):
            NexusBrowserSession =
            NexusBrowserSession(fingerprint, seedCookieHeader)

        private fun hex(rng: SecureRandom, bytes: Int): String {
            val buf = ByteArray(bytes)
            rng.nextBytes(buf)
            val sb = StringBuilder(bytes * 2)
            for (b in buf) {
                val v = b.toInt() and 0xFF
                if (v < 0x10) sb.append('0')
                sb.append(v.toString(16))
            }
            return sb.toString()
        }

        /**
         * UUIDv4 faithful to the Dart implementation (randomness concentrated
         * in the same positions, version nibble = `4`, variant nibble in
         * `8..b`). Using [java.util.UUID.randomUUID] would be equivalent for
         * anime.nexus, but we keep the byte layout identical to stay wire
         * compatible when debugging against the Dart resolver.
         */
        private fun uuidV4(rng: SecureRandom): String {
            val p1 = hex(rng, 4) // 8 hex chars
            val p2 = hex(rng, 2) // 4 hex chars
            val p3 = "4" + hex(rng, 2).substring(1) // 4xxx
            val p4a = (8 + rng.nextInt(4)).toString(16) // 8..b
            val p4b = hex(rng, 2).substring(1) // 3 chars
            val p5 = hex(rng, 6) // 12 hex chars
            return "$p1-$p2-$p3-$p4a$p4b-$p5"
        }
    }
}
