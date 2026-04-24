from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

from .paths import (
    agents_dir,
    contracts_dir,
    rules_path,
    runs_dir,
    system_index_path,
    tasks_dir,
    tests_dir,
)


# ---------- low level ----------

def _read_yaml(p: Path) -> dict[str, Any]:
    with p.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _write_yaml(p: Path, data: dict[str, Any]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
    tmp.replace(p)


def _read_json(p: Path) -> dict[str, Any]:
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(p: Path, data: dict[str, Any]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    tmp.replace(p)


# ---------- tasks ----------

def list_task_ids() -> list[str]:
    out: list[str] = []
    for p in sorted(tasks_dir().glob("TASK-*.yaml")):
        if p.name.startswith("_"):
            continue
        out.append(p.stem)
    return out


def task_path(task_id: str) -> Path:
    return tasks_dir() / f"{task_id}.yaml"


def load_task(task_id: str) -> dict[str, Any]:
    return _read_yaml(task_path(task_id))


def save_task(task_id: str, data: dict[str, Any]) -> None:
    _write_yaml(task_path(task_id), data)


def set_task_status(task_id: str, status: str) -> None:
    t = load_task(task_id)
    t["status"] = status
    save_task(task_id, t)


# ---------- contracts ----------

def load_contract_for_task(task: dict[str, Any]) -> dict[str, Any] | None:
    module = (task.get("provides") or {}).get("module")
    if not module:
        return None
    p = contracts_dir() / f"{module}.json"
    if not p.is_file():
        return None
    return _read_json(p)


def save_contract(module: str, data: dict[str, Any]) -> None:
    _write_json(contracts_dir() / f"{module}.json", data)


# ---------- tests ----------

def load_tests_for_task(task_id: str) -> dict[str, Any]:
    p = tests_dir() / f"{task_id}.spec.yaml"
    return _read_yaml(p) if p.is_file() else {}


def save_tests(task_id: str, data: dict[str, Any]) -> None:
    _write_yaml(tests_dir() / f"{task_id}.spec.yaml", data)


# ---------- runs ----------

def run_dir(task_id: str) -> Path:
    d = runs_dir() / task_id
    d.mkdir(parents=True, exist_ok=True)
    return d


def next_attempt_no(task_id: str) -> int:
    d = run_dir(task_id)
    n = 0
    for p in d.glob("attempt-*.json"):
        try:
            n = max(n, int(p.stem.split("-")[-1]))
        except ValueError:
            continue
    return n + 1


def save_attempt(task_id: str, attempt_no: int, payload: dict[str, Any]) -> Path:
    p = run_dir(task_id) / f"attempt-{attempt_no:02d}.json"
    _write_json(p, payload)
    return p


def save_verdict(task_id: str, attempt_no: int, payload: dict[str, Any]) -> Path:
    p = run_dir(task_id) / f"verdict-{attempt_no:02d}.json"
    _write_json(p, payload)
    return p


def load_retry_context(task_id: str) -> dict[str, Any] | None:
    p = run_dir(task_id) / "retry-context.json"
    return _read_json(p) if p.is_file() else None


def save_retry_context(task_id: str, payload: dict[str, Any]) -> Path:
    p = run_dir(task_id) / "retry-context.json"
    _write_json(p, payload)
    return p


def clear_retry_context(task_id: str) -> None:
    p = run_dir(task_id) / "retry-context.json"
    if p.is_file():
        p.unlink()


# ---------- system index ----------

def load_index() -> dict[str, Any]:
    return _read_json(system_index_path())


def save_index(data: dict[str, Any]) -> None:
    _write_json(system_index_path(), data)


def index_slice(modules: list[str]) -> dict[str, Any]:
    idx = load_index()
    return {
        "version": idx.get("version"),
        "global_invariants": idx.get("global_invariants", []),
        "modules": {m: idx["modules"].get(m) for m in modules if m in idx.get("modules", {})},
        "dependencies": {m: idx.get("dependencies", {}).get(m, []) for m in modules},
    }


# ---------- rules ----------

def load_rules() -> dict[str, Any]:
    return _read_yaml(rules_path())


# ---------- misc ----------

def ensure_dirs() -> None:
    for d in (tasks_dir(), contracts_dir(), tests_dir(), runs_dir()):
        d.mkdir(parents=True, exist_ok=True)
    if not system_index_path().is_file():
        _write_json(system_index_path(), {
            "version": 1,
            "modules": {},
            "dependencies": {},
            "global_invariants": [],
            "error_code_registry": {},
        })


def agents_root() -> Path:
    return agents_dir()
