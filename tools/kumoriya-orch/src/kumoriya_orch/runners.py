from __future__ import annotations

import shlex
import subprocess
from pathlib import Path
from typing import Any

from .paths import root
from .store import load_rules


def _match_runner(files: list[str], rules: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    """Return unique (name, runner_cfg) whose cwd_match intersects `files`."""
    out: list[tuple[str, dict[str, Any]]] = []
    seen: set[str] = set()
    for name, cfg in (rules.get("runners") or {}).items():
        matches = cfg.get("cwd_match", []) or []
        for m in matches:
            prefix = m.replace("*", "")
            if any(f.startswith(prefix) or prefix in f for f in files):
                if name not in seen:
                    out.append((name, cfg))
                    seen.add(name)
                break
    return out


def _run(cmd: str, cwd: Path, timeout: int = 180) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            shlex.split(cmd),
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "cmd": cmd,
            "cwd": str(cwd),
            "returncode": proc.returncode,
            "stdout_tail": proc.stdout[-4000:],
            "stderr_tail": proc.stderr[-4000:],
            "ok": proc.returncode == 0,
        }
    except subprocess.TimeoutExpired:
        return {"cmd": cmd, "cwd": str(cwd), "returncode": -1, "ok": False, "error": "timeout"}
    except FileNotFoundError as e:
        return {"cmd": cmd, "cwd": str(cwd), "returncode": -1, "ok": False, "error": f"missing: {e}"}


def run_for_files(files: list[str]) -> dict[str, Any]:
    """Run format/analyze/test/lint/vet for the runners relevant to the files list."""
    rules = load_rules()
    repo = root()
    results: dict[str, list[dict[str, Any]]] = {}
    for name, cfg in _match_runner(files, rules):
        steps: list[dict[str, Any]] = []
        # Pick a cwd that actually exists from cwd_match patterns.
        cwd = repo
        for pat in cfg.get("cwd_match", []) or []:
            candidate = repo / pat.replace("*", "")
            if candidate.exists():
                cwd = candidate
                break
        for step in ("format", "analyze", "vet", "lint", "test"):
            if step in cfg:
                steps.append(_run(cfg[step], cwd))
        results[name] = steps
    all_ok = all(step.get("ok") for steps in results.values() for step in steps) if results else True
    return {"ok": all_ok, "runners": results}


def write_worker_files(blocks: list[dict[str, str]]) -> list[str]:
    """Persist worker file blocks to disk. Each block: {path, content}."""
    written: list[str] = []
    repo = root()
    for b in blocks:
        p = repo / b["path"]
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(b["content"], encoding="utf-8")
        written.append(b["path"])
    return written
