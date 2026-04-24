package dev.kumoriya.exoplayer.downloads

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log

/**
 * Observes system connectivity so the download engine can react to
 * network loss (emit `DISCONNECTED` and pause in-flight transfers) and
 * recovery (auto-resume tasks that were paused by loss or by a
 * cellular-blocked `wifiOnly` policy).
 *
 * The callback runs on the [ConnectivityManager] internal thread, so the
 * [listener] must be thread-safe. Every invocation carries the latest
 * [Snapshot] — callers don't need to query capabilities themselves.
 */
internal class NetworkMonitor(private val context: Context) {

    /** Snapshot of the current transport / online state. */
    internal data class Snapshot(
        val online: Boolean,
        val unmetered: Boolean,
    ) {
        /** True when the current network is WiFi / Ethernet / VPN (no data charges). */
        val isWifiLike: Boolean get() = online && unmetered
    }

    /** Listener signature: (previous, current). */
    internal fun interface Listener {
        fun onChange(previous: Snapshot, current: Snapshot)
    }

    private val cm = context.getSystemService(ConnectivityManager::class.java)

    @Volatile
    private var latest: Snapshot = Snapshot(online = false, unmetered = false)

    /** Most recent snapshot. Safe to read from any thread. */
    val current: Snapshot get() = latest

    private var listener: Listener? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    // ── Lifecycle ───────────────────────────────────────────────────────

    fun start(listener: Listener) {
        if (callback != null) return
        this.listener = listener

        // Seed `latest` from the active network so the first dispatch
        // isn't an edge case — `onAvailable` only fires on *transitions*,
        // not on the current state at registration time.
        latest = queryActiveSnapshot()

        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                update { it.copy(online = true) }
            }
            override fun onLost(network: Network) {
                // Another active network may still exist — re-query
                // instead of flipping `online` off immediately, which
                // would cause spurious DISCONNECTED emits when swapping
                // WiFi → cellular without an intermediate offline gap.
                update { queryActiveSnapshot() }
            }
            override fun onCapabilitiesChanged(
                network: Network,
                caps: NetworkCapabilities,
            ) {
                update {
                    Snapshot(
                        online = caps.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_INTERNET,
                        ),
                        unmetered = caps.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_NOT_METERED,
                        ),
                    )
                }
            }
        }
        callback = cb

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        try {
            cm.registerNetworkCallback(request, cb)
            Log.d(TAG, "registered, initial=$latest")
        } catch (e: SecurityException) {
            Log.w(TAG, "registerNetworkCallback denied", e)
            callback = null
        }
    }

    fun stop() {
        callback?.let {
            try {
                cm.unregisterNetworkCallback(it)
            } catch (e: IllegalArgumentException) {
                // Already unregistered — benign.
            }
        }
        callback = null
        listener = null
    }

    // ── Internal ────────────────────────────────────────────────────────

    private inline fun update(transform: (Snapshot) -> Snapshot) {
        val prev = latest
        val next = transform(prev)
        if (prev == next) return
        latest = next
        Log.d(TAG, "connectivity $prev → $next")
        listener?.onChange(prev, next)
    }

    private fun queryActiveSnapshot(): Snapshot {
        val active = cm.activeNetwork ?: return Snapshot(false, false)
        val caps = cm.getNetworkCapabilities(active) ?: return Snapshot(false, false)
        return Snapshot(
            online = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
            unmetered = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
        )
    }

    companion object {
        private const val TAG = "NetworkMonitor"
    }
}
