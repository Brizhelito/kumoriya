# Git, Worktrees, and Automations

## Git policy

- use conventional commits
- prefer one meaningful change per commit
- do not batch architecture + feature + cleanup in one commit
- protect main from force pushes

## Worktrees

Use worktrees for:
- risky refactors
- parallel exploration
- longer-running feature threads
- background Codex tasks

## Automations

Use Codex automations only after a prompt is already proven manually.

Recommended first automations later:
- dependency drift check
- stale plugin health check
- docs sync check
- PR hygiene check

Do not automate destructive tasks.
