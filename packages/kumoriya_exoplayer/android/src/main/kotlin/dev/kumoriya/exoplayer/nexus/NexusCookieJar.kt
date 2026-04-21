package dev.kumoriya.exoplayer.nexus

import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import java.util.concurrent.CopyOnWriteArrayList

/**
 * In-memory cookie jar scoped to a single nexus playback session.
 *
 * Correctness rules:
 *  - Cookies are stored in a single flat list, identified by
 *    (domain, path, name). A new cookie with the same triple replaces the
 *    previous value, matching RFC 6265 §5.3.
 *  - Outbound lookups rely on [Cookie.matches] so the jar honours the
 *    cookie's own `domain=` attribute, path scoping, `Secure`, and the
 *    host-only flag. The previous implementation bucketed by request host,
 *    which dropped any `domain=.anime.nexus` cookie for sibling hosts like
 *    `prd-socket.anime.nexus` \u2014 that was the auth-cookie bug.
 *  - Expired cookies are lazily evicted on every read.
 */
internal class NexusCookieJar : CookieJar {
    private val cookies = CopyOnWriteArrayList<Cookie>()

    /** Seed a cookie straight into the store (e.g. the synthetic `sid`). */
    fun seed(cookie: Cookie) {
        removeMatching(cookie)
        cookies.add(cookie)
    }

    fun seedHeader(url: HttpUrl, header: String) {
        for (pair in header.split(';')) {
            val trimmed = pair.trim()
            if (trimmed.isEmpty()) continue
            val eq = trimmed.indexOf('=')
            if (eq <= 0) continue
            val cookie = Cookie.Builder()
                .domain(url.host)
                .path("/")
                .name(trimmed.substring(0, eq))
                .value(trimmed.substring(eq + 1))
                .build()
            seed(cookie)
        }
    }

    override fun saveFromResponse(url: HttpUrl, incoming: List<Cookie>) {
        if (incoming.isEmpty()) return
        val now = System.currentTimeMillis()
        for (cookie in incoming) {
            removeMatching(cookie)
            if (cookie.expiresAt > now) {
                cookies.add(cookie)
            }
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val now = System.currentTimeMillis()
        val matches = mutableListOf<Cookie>()
        val iter = cookies.iterator()
        while (iter.hasNext()) {
            val c = iter.next()
            if (c.expiresAt <= now) {
                cookies.remove(c)
                continue
            }
            if (c.matches(url)) matches.add(c)
        }
        return matches
    }

    /** Render all stored cookies for [url] as a `Cookie` header value. */
    fun asCookieHeader(url: HttpUrl): String? {
        val list = loadForRequest(url)
        if (list.isEmpty()) return null
        return list.joinToString("; ") { "${it.name}=${it.value}" }
    }

    private fun removeMatching(candidate: Cookie) {
        cookies.removeAll {
            it.name == candidate.name &&
                it.domain == candidate.domain &&
                it.path == candidate.path
        }
    }
}
