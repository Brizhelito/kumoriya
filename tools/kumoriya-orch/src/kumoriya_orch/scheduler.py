from __future__ import annotations

from typing import Any

from . import store


def all_tasks() -> list[dict[str, Any]]:
    return [store.load_task(tid) for tid in store.list_task_ids()]


def next_runnable() -> dict[str, Any] | None:
    tasks = all_tasks()
    by_id = {t["id"]: t for t in tasks if "id" in t}
    for t in tasks:
        if t.get("status") != "ready":
            continue
        deps = t.get("depends_on", []) or []
        if all(by_id.get(d, {}).get("status") == "pass" for d in deps):
            return t
    return None


def dependents_of(task_id: str) -> list[str]:
    out: list[str] = []
    for t in all_tasks():
        if task_id in (t.get("depends_on", []) or []):
            out.append(t["id"])
    return out
