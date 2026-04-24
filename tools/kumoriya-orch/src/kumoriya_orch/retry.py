from __future__ import annotations

from typing import Any


def build_retry_context(*, attempt: int,
                        verdict: dict[str, Any],
                        runners_result: dict[str, Any] | None,
                        previous_output_hash: str | None) -> dict[str, Any]:
    failing_tests: list[dict[str, Any]] = []
    static_violations: list[dict[str, Any]] = []

    if runners_result:
        for _name, steps in (runners_result.get("runners") or {}).items():
            for step in steps:
                if step.get("ok"):
                    continue
                # Best-effort: surface last lines of stderr as failing test info.
                failing_tests.append({
                    "id": None,
                    "expected": None,
                    "actual": None,
                    "diff": (step.get("stderr_tail") or step.get("stdout_tail") or "")[-800:],
                    "cmd": step.get("cmd"),
                })

    for v in verdict.get("violations") or []:
        static_violations.append({
            "check": v.get("check"),
            "location": v.get("detail"),
        })

    return {
        "attempt": attempt + 1,
        "failing_tests": failing_tests,
        "static_violations": static_violations,
        "reviewer_hint": verdict.get("minimal_fix_hint"),
        "do_not_touch": ["function signature", "error code names"],
        "previous_output_hash": previous_output_hash,
    }
