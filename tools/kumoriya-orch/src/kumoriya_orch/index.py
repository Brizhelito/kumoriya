from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from . import store


def commit_task_into_index(task: dict[str, Any], contract: dict[str, Any] | None) -> dict[str, Any]:
    """Atomically record a green task's module into system_index.json."""
    idx = store.load_index()
    modules = idx.setdefault("modules", {})
    deps = idx.setdefault("dependencies", {})
    registry = idx.setdefault("error_code_registry", {})

    provides = task.get("provides") or {}
    module = provides.get("module")
    if not module:
        # Task does not add a module (e.g. a test-only or export-plumbing task).
        idx["updated_at"] = datetime.now(timezone.utc).isoformat()
        store.save_index(idx)
        return idx

    exports = provides.get("exports", []) or []
    if contract is None:
        contract = {}

    modules[module] = {
        "path": _primary_path_for(task),
        "exports": [
            {"name": e, "signature": contract.get("signature", "")} for e in exports
        ],
        "invariants": contract.get("invariants", []),
        "error_codes": [e.get("code") for e in (contract.get("errors") or [])],
        "purity": contract.get("purity", "unknown"),
        "owned_by_task": task.get("id"),
    }
    deps[module] = (task.get("consumes") or {}).get("modules", [])

    for err in contract.get("errors", []) or []:
        code = err.get("code")
        if code:
            registry[code] = module

    idx["version"] = int(idx.get("version", 0)) + 1
    idx["updated_at"] = datetime.now(timezone.utc).isoformat()
    store.save_index(idx)

    # Mark dependents stale if this module's exports changed.
    _invalidate_dependents(module)
    return idx


def _primary_path_for(task: dict[str, Any]) -> str | None:
    fa = task.get("files_allowed") or {}
    for key in ("create", "modify"):
        for f in fa.get(key, []) or []:
            return f
    return None


def _invalidate_dependents(module: str) -> None:
    """Mark any task that consumes `module` as stale."""
    for tid in store.list_task_ids():
        t = store.load_task(tid)
        if t.get("status") == "pass":
            consumed = (t.get("consumes") or {}).get("modules", []) or []
            if module in consumed and t.get("id") != module:
                t["status"] = "stale"
                store.save_task(tid, t)


def rebuild() -> dict[str, Any]:
    """Rebuild index from every pass task + its contract."""
    idx = {
        "version": 1,
        "modules": {},
        "dependencies": {},
        "global_invariants": store.load_index().get("global_invariants", []),
        "error_code_registry": {},
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    store.save_index(idx)
    for tid in store.list_task_ids():
        t = store.load_task(tid)
        if t.get("status") == "pass":
            contract = store.load_contract_for_task(t)
            commit_task_into_index(t, contract)
    return store.load_index()
