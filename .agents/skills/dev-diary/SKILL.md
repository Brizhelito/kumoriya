---
name: dev-diary
description: Document every approved change to Kumoriya immediately. Use after any implementation task is validated and approved. Maintains a chronological dev diary under docs/dev-diary/ with one file per day.
---

## Purpose

Maintain a persistent, chronological record of every change made to Kumoriya so that developers and AI agents can quickly understand what was done, when, and why — even across conversation boundaries or after context loss.

## Workflow

1. After a change is **validated and approved**, append an entry to `docs/dev-diary/YYYY-MM-DD.md` (using the current date).
2. If the file does not exist yet for today, create it with the header template below.
3. Commit the diary entry immediately with: `docs(diary): YYYY-MM-DD — <short summary>`
4. Never batch diary entries — one commit per change set.

## File Template (new day)

```markdown
# Dev Diary — YYYY-MM-DD

> Auto-maintained by dev-diary skill. One entry per approved change.

---
```

## Entry Template

Append this block for each change:

```markdown
## HH:MM — <short title>

**Category:** fix | feature | refactor | infra | docs
**Affected files:**
- `path/to/file1.dart`
- `path/to/file2.dart`

**Summary:**
<1-3 sentences describing what changed and why.>

**Linked phase:** <Phase X.Y from master plan, if applicable>

---
```

## Rules

- Keep entries factual and concise — no filler prose.
- Always list affected files with relative paths.
- Always tag the category.
- If the change relates to the v0.2 master plan, reference the phase.
- If a change introduces known residual risk, note it in the summary.
- Do not duplicate CHANGELOG content — the diary is for dev/AI context, not user-facing release notes.
- The diary is committed to version control and should be treated as a source of truth for "what happened."

## Example

```markdown
## 14:30 — Reduce idle timeout to 5s

**Category:** fix
**Affected files:**
- `apps/kumoriya_app/lib/src/features/downloads/application/download_manager_service.dart`

**Summary:**
Reduced HTTP idle timeout from 60s to 5s to release server connections promptly after download completion. Prevents resource holding on CDN servers that was causing connection pool exhaustion on sequential downloads.

**Linked phase:** Phase 1.3

---
```
