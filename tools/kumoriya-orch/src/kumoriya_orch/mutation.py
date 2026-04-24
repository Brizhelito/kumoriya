from __future__ import annotations

from typing import Any


def run_mutation(task: dict[str, Any], contract: dict[str, Any] | None,
                 tests: dict[str, Any]) -> dict[str, Any]:
    """Mutation suite runner stub.

    The real implementation dispatches per language to a small harness that
    imports the module under test and hammers it with generated inputs
    (random_ascii, unicode_fuzz, boundary, property_based) while asserting
    contract invariants as oracles.

    Until the harness is wired, we return `ok=true` with a `skipped` flag so
    the pipeline does not block. Reviewer C10 will read this and warn.
    """
    if contract is None or not (tests or {}).get("mutation"):
        return {"ok": True, "skipped": True, "reason": "no mutation spec"}
    return {
        "ok": True,
        "skipped": True,
        "reason": "mutation harness not yet implemented",
        "generators_declared": list((tests.get("mutation") or {}).get("generators", [])),
    }
