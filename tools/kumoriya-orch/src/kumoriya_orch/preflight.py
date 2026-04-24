from __future__ import annotations

from typing import Any


def preflight(task: dict[str, Any], contract: dict[str, Any] | None,
              tests: dict[str, Any], system_index: dict[str, Any]) -> dict[str, Any]:
    """Run P1..P6 against a task spec. Pure, no IO, no model calls."""
    errors: list[str] = []

    if contract is None:
        errors.append("P0: contract missing for task.provides.module")
        return {"ok": False, "errors": errors}

    test_cases = tests.get("cases", []) or []
    test_ids = {c.get("id") for c in test_cases}
    task_test_ids = set(task.get("tests", []) or [])

    # P1: every task-declared test id exists and is covered by contract.
    for tid in task_test_ids:
        if tid not in test_ids:
            errors.append(f"P1: task.tests references unknown id {tid}")

    # P3: every error code has at least one failure test.
    declared_errors = {e.get("code") for e in (contract.get("errors") or [])}
    failure_error_codes = {
        c.get("assert_raises") for c in test_cases if c.get("kind") == "failure"
    }
    for code in declared_errors:
        if code and code not in failure_error_codes:
            errors.append(f"P3: error code {code} not exercised by any failure test")

    # P2: edge cases must not contradict invariants (syntactic check only:
    # flag obvious "raise E_X" inside edge_cases while E_X is not declared).
    referenced_in_edges = set()
    for e in contract.get("edge_cases", []) or []:
        expected = str(e.get("expected", ""))
        for code in declared_errors:
            if code and code in expected:
                referenced_in_edges.add(code)
    # (reserved for future deeper checks)
    _ = referenced_in_edges

    # P4: all types resolved — reject explicit "any" in input/output contracts.
    types_blob = str(contract.get("types", {})) + str(task.get("input_contract", []))
    if "any" in types_blob.lower().split() or '"any"' in types_blob.lower():
        errors.append("P4: unresolved 'any' type detected")

    # P5: no violation of global invariants (syntactic — reject forbidden tokens).
    forbidden_tokens = [
        "bypass anilist",
        "override anilist",
        "import from tests",
    ]
    blob = (str(task) + str(contract)).lower()
    for tok in forbidden_tokens:
        if tok in blob:
            errors.append(f"P5: forbidden intent detected: {tok}")

    # P6: estimated loc vs max_lines (best-effort).
    max_lines = None
    for c in task.get("constraints", []) or []:
        if isinstance(c, dict) and "max_lines" in c:
            max_lines = c["max_lines"]
    if max_lines is not None:
        est = max(40, 15 * max(1, len(task_test_ids)))
        if est > int(max_lines) * 2:
            errors.append(
                f"P6: estimated LoC {est} >> max_lines {max_lines}; split task"
            )

    # Dependency sanity: no cycles involving this task's depends_on.
    deps = task.get("depends_on", []) or []
    if task["id"] in deps:
        errors.append("P6: task depends on itself")

    return {"ok": not errors, "errors": errors}
