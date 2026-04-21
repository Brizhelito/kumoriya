package dev.kumoriya.exoplayer.nexus

/** Root exception for every failure raised by the native nexus pipeline. */
open class NexusException(message: String, cause: Throwable? = null) :
    RuntimeException(message, cause)

class NexusScrapeException(message: String, cause: Throwable? = null) :
    NexusException(message, cause)

class NexusStreamDataException(message: String, cause: Throwable? = null) :
    NexusException(message, cause)

class NexusTransportException(message: String, cause: Throwable? = null) :
    NexusException(message, cause)

class NexusWsException(message: String, cause: Throwable? = null) :
    NexusException(message, cause)

class NexusHlsException(message: String, cause: Throwable? = null) :
    NexusException(message, cause)

/**
 * Raised when multiple cdn.nexus edges reject our signed tokens with the
 * same `{"error":"Token validation failed"}` body. In practice this
 * means the CDN WAF has flagged the client's public IP globally —
 * rotating edges cannot recover, only switching network/VPN can.
 */
class NexusBlockedByWafException(
    message: String,
    cause: Throwable? = null,
) : NexusException(message, cause)
