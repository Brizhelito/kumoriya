"""MCP server exposing orchestration tools to Cascade workflows."""
from __future__ import annotations

import hashlib
import json
from typing import Any

try:
    from mcp.server.fastmcp import FastMCP
except Exception as e:  # pragma: no cover
    raise SystemExit(
        "mcp[cli] is required. Install the package in editable mode:\n"
        "  pip install -e tools/kumoriya-orch\n"
        f"Import error: {e}"
    )

from . import index as index_mod
from . import mutation as mutation_mod
from . import preflight as preflight_mod
from . import retry as retry_mod
from . import runners as runners_mod
from . import scheduler
from . import store


mcp = FastMCP("kumoriya-orch")


# ---------------- tasks ----------------

@mcp.tool()
def list_tasks(status: str | None = None) -> list[dict[str, Any]]:
    """List all tasks, optionally filtered by status."""
    out = []
    for tid in store.list_task_ids():
        t = store.load_task(tid)
        if status and t.get("status") != status:
            continue
        out.append({
            "id": t.get("id", tid),
            "title": t.get("title"),
            "status": t.get("status"),
            "depends_on": t.get("depends_on", []),
        })
    return out


@mcp.tool()
def get_task(task_id: str) -> dict[str, Any]:
    """Full task + contract + tests for one id."""
    t = store.load_task(task_id)
    return {
        "task": t,
        "contract": store.load_contract_for_task(t),
        "tests": store.load_tests_for_task(task_id),
    }


@mcp.tool()
def next_task() -> dict[str, Any] | None:
    """Pick the next runnable task according to DAG. Returns null if none."""
    t = scheduler.next_runnable()
    return t


# ---------------- preflight ----------------

@mcp.tool()
def preflight(task_id: str) -> dict[str, Any]:
    """Run P1..P6 for a task. Returns `{ok, errors[]}`."""
    t = store.load_task(task_id)
    c = store.load_contract_for_task(t)
    tests = store.load_tests_for_task(task_id)
    idx = store.load_index()
    return preflight_mod.preflight(t, c, tests, idx)


# ---------------- worker / reviewer context ----------------

@mcp.tool()
def worker_context(task_id: str) -> dict[str, Any]:
    """Minimized payload for the worker. Never includes system_index."""
    from .minimize import minimize_task_files
    t = store.load_task(task_id)
    c = store.load_contract_for_task(t)
    tests = store.load_tests_for_task(task_id)
    retry_ctx = store.load_retry_context(task_id)
    return {
        "task": t,
        "contract": c,
        "tests": tests,
        "files": minimize_task_files(t),
        "retry_context": retry_ctx,
        "attempt_no": store.next_attempt_no(task_id),
    }


@mcp.tool()
def reviewer_context(task_id: str, attempt_no: int) -> dict[str, Any]:
    """Payload for the reviewer: task+contract+tests + run artifacts + index slice."""
    t = store.load_task(task_id)
    c = store.load_contract_for_task(t)
    tests = store.load_tests_for_task(task_id)
    run = store.run_dir(task_id) / f"attempt-{attempt_no:02d}.json"
    attempt = json.loads(run.read_text()) if run.is_file() else {}
    modules = [t.get("provides", {}).get("module")] + list(
        (t.get("consumes") or {}).get("modules", []) or []
    )
    modules = [m for m in modules if m]
    return {
        "task": t,
        "contract": c,
        "tests": tests,
        "attempt": attempt,
        "system_index_slice": store.index_slice(modules),
    }


# ---------------- submit / verdict / retry ----------------

@mcp.tool()
def submit_attempt(task_id: str, files: list[dict[str, str]]) -> dict[str, Any]:
    """Persist worker files, run language runners, store attempt.

    `files` is a list of `{path, content}` dicts parsed from the `<<<FILE ... FILE>>>`
    blocks the worker emitted.
    """
    store.set_task_status(task_id, "in_progress")
    attempt_no = store.next_attempt_no(task_id)
    written = runners_mod.write_worker_files(files)
    runner_result = runners_mod.run_for_files(written)
    digest = hashlib.sha256(
        json.dumps(files, sort_keys=True).encode("utf-8")
    ).hexdigest()
    payload = {
        "task_id": task_id,
        "attempt_no": attempt_no,
        "files": files,
        "files_written": written,
        "runners_result": runner_result,
        "output_hash": digest,
    }
    path = store.save_attempt(task_id, attempt_no, payload)
    return {"attempt_no": attempt_no, "path": str(path), "runners_result": runner_result}


@mcp.tool()
def save_verdict(task_id: str, attempt_no: int, verdict: dict[str, Any]) -> dict[str, Any]:
    """Persist a reviewer verdict."""
    path = store.save_verdict(task_id, attempt_no, verdict)
    return {"ok": True, "path": str(path)}


@mcp.tool()
def build_retry_context(task_id: str, attempt_no: int) -> dict[str, Any]:
    """Produce the structured retry packet for the next worker attempt."""
    verdict_path = store.run_dir(task_id) / f"verdict-{attempt_no:02d}.json"
    attempt_path = store.run_dir(task_id) / f"attempt-{attempt_no:02d}.json"
    verdict = json.loads(verdict_path.read_text()) if verdict_path.is_file() else {}
    attempt = json.loads(attempt_path.read_text()) if attempt_path.is_file() else {}
    rc = retry_mod.build_retry_context(
        attempt=attempt_no,
        verdict=verdict,
        runners_result=attempt.get("runners_result"),
        previous_output_hash=attempt.get("output_hash"),
    )
    store.save_retry_context(task_id, rc)
    return rc


# ---------------- mutation / commit / escalate ----------------

@mcp.tool()
def run_mutation(task_id: str) -> dict[str, Any]:
    """Run the mutation suite for this task."""
    t = store.load_task(task_id)
    c = store.load_contract_for_task(t)
    tests = store.load_tests_for_task(task_id)
    return mutation_mod.run_mutation(t, c, tests)


@mcp.tool()
def commit_task(task_id: str) -> dict[str, Any]:
    """Mark task pass and update system_index atomically."""
    t = store.load_task(task_id)
    c = store.load_contract_for_task(t)
    t["status"] = "pass"
    store.save_task(task_id, t)
    idx = index_mod.commit_task_into_index(t, c)
    store.clear_retry_context(task_id)
    return {"ok": True, "status": "pass", "index_version": idx.get("version")}


@mcp.tool()
def escalate_task(task_id: str, reason: str) -> dict[str, Any]:
    """Mark task blocked with a reason for the architect."""
    t = store.load_task(task_id)
    t["status"] = "blocked"
    t["escalation"] = {"reason": reason}
    store.save_task(task_id, t)
    return {"ok": True, "status": "blocked", "reason": reason}


# ---------------- index ----------------

@mcp.tool()
def index_get() -> dict[str, Any]:
    return store.load_index()


@mcp.tool()
def index_slice(modules: list[str]) -> dict[str, Any]:
    return store.index_slice(modules)


@mcp.tool()
def index_rebuild() -> dict[str, Any]:
    return index_mod.rebuild()


# ---------------- entry ----------------

def main() -> None:
    store.ensure_dirs()
    mcp.run()


if __name__ == "__main__":
    main()
