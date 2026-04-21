#!/usr/bin/env python3
"""Extract anime.nexus-relevant events from a Chrome --log-net-log dump.

Usage:
    python3 scripts/extract_nexus_netlog.py /tmp/nexus-netlog.json.gz \
        > /tmp/nexus-slim.json

Pulls:
    - HTTP requests to *.anime.nexus, *.cdn.nexus, *.nexus.
    - Request & response headers (sensitive cookies redacted).
    - WebSocket upgrades + every frame sent/received.
Discards everything else (assets, telemetry, unrelated hosts).
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

import ijson


HOST_RE = re.compile(r"://([^/]+)")
NEXUS_RE = re.compile(r"(anime\.nexus|cdn\.nexus|socket\.anime\.nexus)", re.I)
REDACT_COOKIES = re.compile(
    r"(next-auth[\w.-]*|__Secure-[\w.-]*|__Host-[\w.-]*|sid|session|authjs[\w.-]*)"
    r"=[^;\s]+",
    re.I,
)


def redact(text: str) -> str:
    return REDACT_COOKIES.sub(r"\1=REDACTED", text)


def is_nexus(url: str | None) -> bool:
    if not url:
        return False
    m = HOST_RE.search(url)
    if not m:
        return False
    return bool(NEXUS_RE.search(m.group(1)))


def iter_events(path: Path):
    opener = gzip.open if path.suffix == ".gz" else open

    # Streaming constants extraction.
    constants: dict = {}
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        try:
            constants = next(
                iter(ijson.items(f, "constants.logEventTypes"))
            )
            constants = {"logEventTypes": constants}
        except (StopIteration, ijson.common.IncompleteJSONError):
            pass

    # Streaming events; netlog often has trailing garbage after the events
    # array when Chrome was killed \u2014 swallow the IncompleteJSONError.
    def event_stream():
        with opener(path, "rt", encoding="utf-8", errors="replace") as g:
            try:
                yield from ijson.items(g, "events.item")
            except ijson.common.IncompleteJSONError:
                return

    return constants, event_stream()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    constants, events = iter_events(path)

    # Build event-type id -> name map
    type_map = {
        int(v): k for k, v in constants.get("logEventTypes", {}).items()
    }

    # Group events by source (url-request / websocket).
    sources: dict[int, dict] = {}
    for ev in events:
        src = ev.get("source") or {}
        src_id = src.get("id")
        if src_id is None:
            continue
        entry = sources.setdefault(
            src_id,
            {
                "type": src.get("type"),
                "events": [],
                "url": None,
                "is_ws": False,
            },
        )
        params = ev.get("params") or {}
        ev_type = type_map.get(ev.get("type"), str(ev.get("type")))

        url = params.get("url")
        if url and not entry["url"]:
            entry["url"] = url

        if "WEBSOCKET" in ev_type:
            entry["is_ws"] = True

        entry["events"].append(
            {
                "phase": ev.get("phase"),
                "type": ev_type,
                "time": ev.get("time"),
                "params": params,
            }
        )

    # Keep only nexus-related sources.
    kept = []
    for src_id, entry in sources.items():
        if not (is_nexus(entry["url"]) or entry["is_ws"]):
            continue
        if entry["is_ws"] and not is_nexus(entry["url"]):
            # Skip non-nexus websockets.
            continue
        trimmed_events = []
        for ev in entry["events"]:
            p = ev["params"]
            if "headers" in p:
                if isinstance(p["headers"], list):
                    p["headers"] = [redact(h) for h in p["headers"]]
                elif isinstance(p["headers"], str):
                    p["headers"] = redact(p["headers"])
            for key in ("cookie_line", "line", "value"):
                if key in p and isinstance(p[key], str):
                    p[key] = redact(p[key])
            trimmed_events.append(ev)
        kept.append(
            {
                "source_id": src_id,
                "url": entry["url"],
                "is_ws": entry["is_ws"],
                "events": trimmed_events,
            }
        )

    out = {
        "source_count": len(kept),
        "websocket_count": sum(1 for k in kept if k["is_ws"]),
        "sources": kept,
    }
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
