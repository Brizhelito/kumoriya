from __future__ import annotations

import os
from pathlib import Path


def root() -> Path:
    """Repo root. Override via KUMORIYA_ROOT."""
    r = os.environ.get("KUMORIYA_ROOT")
    if r:
        return Path(r).resolve()
    # Fallback: walk up from cwd until we find .agents/rules.yaml.
    cur = Path.cwd().resolve()
    for p in [cur, *cur.parents]:
        if (p / ".agents" / "rules.yaml").is_file():
            return p
    raise RuntimeError("Cannot locate Kumoriya repo root. Set KUMORIYA_ROOT.")


def agents_dir() -> Path:
    return root() / ".agents"


def tasks_dir() -> Path:
    return agents_dir() / "tasks"


def contracts_dir() -> Path:
    return agents_dir() / "contracts"


def tests_dir() -> Path:
    return agents_dir() / "tests"


def runs_dir() -> Path:
    return agents_dir() / "runs"


def system_index_path() -> Path:
    return agents_dir() / "system_index.json"


def rules_path() -> Path:
    return agents_dir() / "rules.yaml"
