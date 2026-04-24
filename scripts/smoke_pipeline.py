#!/usr/bin/env python3
"""Smoke test for the kumoriya-orch pipeline.

Exercises the full loop WITHOUT calling any LLM:
  1. scheduler.next_runnable() picks TASK-SMOKE-01
  2. preflight.preflight() returns ok
  3. fake worker emits a correct slugify implementation
  4. runners.run_for_files() runs pytest on tools/kumoriya-orch
  5. store.save_verdict() stores a synthetic pass verdict
  6. index.commit_task_into_index() updates system_index.json

Run from repo root with the orch venv python:

    tools/kumoriya-orch/.venv/bin/python scripts/smoke_pipeline.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "kumoriya-orch" / "src"))

from kumoriya_orch import index as index_mod
from kumoriya_orch import preflight as preflight_mod
from kumoriya_orch import runners as runners_mod
from kumoriya_orch import scheduler, store


WORKER_OUTPUT = '''\
import re
import unicodedata

_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def slugify(text: str, max_len: int) -> str:
    if not isinstance(max_len, int) or max_len < 1 or max_len > 200:
        raise ValueError("E_RANGE")
    norm = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    norm = norm.lower().strip()
    if not norm:
        raise ValueError("E_EMPTY")
    slug = _NON_ALNUM.sub("-", norm).strip("-")
    if not slug:
        raise ValueError("E_EMPTY")
    return slug[:max_len].rstrip("-")
'''


def banner(msg: str) -> None:
    print(f"\n=== {msg} ===")


def main() -> int:
    store.ensure_dirs()

    banner("1. scheduler.next_runnable()")
    t = scheduler.next_runnable()
    if not t or t.get("id") != "TASK-SMOKE-01":
        print(f"FAIL: expected TASK-SMOKE-01, got {t}")
        return 1
    print(f"picked: {t['id']} ({t['title']})")

    banner("2. preflight")
    c = store.load_contract_for_task(t)
    tests = store.load_tests_for_task(t["id"])
    idx = store.load_index()
    pf = preflight_mod.preflight(t, c, tests, idx)
    print(json.dumps(pf, indent=2))
    if not pf["ok"]:
        return 2

    banner("3. fake worker submit_attempt")
    files = [{
        "path": "tools/kumoriya-orch/src/kumoriya_orch/smoke_slugify.py",
        "content": WORKER_OUTPUT,
    }]
    store.set_task_status(t["id"], "in_progress")
    attempt_no = store.next_attempt_no(t["id"])
    written = runners_mod.write_worker_files(files)
    print(f"wrote: {written}")

    banner("4. runners.run_for_files() (pytest)")
    result = runners_mod.run_for_files(written)
    for name, steps in result["runners"].items():
        for step in steps:
            print(f"  [{name}] {step['cmd']} -> rc={step['returncode']} ok={step['ok']}")
            if not step.get("ok"):
                print("  stderr_tail:", step.get("stderr_tail", "")[-400:])
    if not result["ok"]:
        print("FAIL: runners red")
        store.save_attempt(t["id"], attempt_no, {"runners_result": result, "files": files})
        return 4
    store.save_attempt(t["id"], attempt_no, {"runners_result": result, "files": files})

    banner("5. save synthetic reviewer verdict (pass)")
    verdict = {
        "verdict": "pass",
        "violations": [],
        "anti_cheat": {"suspicious_literals": [], "adversarial_probe": {"plausible": True}},
        "minimal_fix_hint": None,
        "confidence": 0.95,
    }
    vpath = store.save_verdict(t["id"], attempt_no, verdict)
    print(f"verdict: {vpath}")

    banner("6. commit_task_into_index()")
    t = store.load_task(t["id"])
    t["status"] = "pass"
    store.save_task(t["id"], t)
    new_idx = index_mod.commit_task_into_index(t, c)
    print(f"index version: {new_idx.get('version')}")
    mod = new_idx["modules"].get("kumoriya_orch.smoke_slugify")
    print("module entry:", json.dumps(mod, indent=2))

    banner("OK")
    print("Smoke test passed end-to-end.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
