from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .paths import root

_COMMENT_LINE = re.compile(r"^\s*(#|//).*$")
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_DART_DOC = re.compile(r"^\s*///.*$", re.MULTILINE)


def _strip(text: str, language: str) -> str:
    text = _BLOCK_COMMENT.sub("", text)
    if language == "dart":
        text = _DART_DOC.sub("", text)
    kept: list[str] = []
    for line in text.splitlines():
        if not line.strip():
            continue
        if _COMMENT_LINE.match(line):
            continue
        kept.append(line)
    return "\n".join(kept)


def _guess_language(path: Path) -> str:
    ext = path.suffix.lower()
    return {
        ".dart": "dart",
        ".py": "python",
        ".go": "go",
        ".ts": "typescript",
        ".tsx": "typescript",
        ".js": "javascript",
    }.get(ext, "text")


def minimize_file(rel_path: str, *, new_file_hint: str | None = None) -> dict[str, Any]:
    p = root() / rel_path
    if not p.exists():
        return {
            "file": rel_path,
            "mode": "new_file",
            "full_contents": None,
            "relevant": {"signatures_available": [new_file_hint] if new_file_hint else []},
            "stripped": [],
        }
    raw = p.read_text(encoding="utf-8")
    lang = _guess_language(p)
    loc = len(raw.splitlines())
    if loc <= 120:
        return {
            "file": rel_path,
            "mode": "patch",
            "full_contents": _strip(raw, lang),
            "relevant": None,
            "stripped": ["comments", "blank_lines"],
        }
    # Large file: return only imports block + top-level signatures.
    lines = raw.splitlines()
    imports = [l for l in lines if l.startswith(("import ", "from ", "use ", "package "))]
    signatures = [
        l for l in lines
        if re.match(r"^\s*(class|def|fn|func|void|Future|Stream|String|int|bool|double|public|private|export)\b", l)
    ]
    snippet_body = "\n".join(imports[:30] + ["// ..."] + signatures[:60])
    return {
        "file": rel_path,
        "mode": "patch",
        "full_contents": None,
        "relevant": {
            "signatures_available": signatures[:60],
            "snippets": [{"reason": "imports+signatures", "lines": f"1-{loc}", "code": snippet_body}],
        },
        "stripped": ["comments", "blank_lines", "unrelated_functions"],
    }


def minimize_task_files(task: dict[str, Any]) -> list[dict[str, Any]]:
    fa = task.get("files_allowed", {}) or {}
    files: list[str] = []
    for key in ("modify", "create", "read_only"):
        for f in fa.get(key, []) or []:
            files.append(f)
    # De-dupe preserving order.
    seen: set[str] = set()
    uniq: list[str] = []
    for f in files:
        if f not in seen:
            uniq.append(f)
            seen.add(f)
    return [minimize_file(f) for f in uniq]
