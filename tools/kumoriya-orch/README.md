# kumoriya-orch

MCP server that owns the Architect/Worker/Reviewer pipeline state for Kumoriya.

It is the single writer to `.agents/tasks/`, `.agents/contracts/`, `.agents/tests/`,
`.agents/runs/` and `.agents/system_index.json`. Workflows in `.windsurf/workflows/`
call its tools instead of reading/writing those files directly, which keeps
Cascade's chat context small and deterministic.

## Install (editable)

```bash
# From repo root:
python -m venv tools/kumoriya-orch/.venv
tools/kumoriya-orch/.venv/bin/pip install -e tools/kumoriya-orch
```

## Register with Windsurf

Add to your MCP config (Cascade settings → MCP servers):

```json
{
  "kumoriya-orch": {
    "command": "tools/kumoriya-orch/.venv/bin/kumoriya-orch",
    "args": [],
    "env": { "KUMORIYA_ROOT": "." }
  }
}
```

## Tools exposed

| Tool                         | Purpose                                                                 |
|------------------------------|-------------------------------------------------------------------------|
| `list_tasks`                 | All tasks with status and deps.                                         |
| `get_task`                   | Full task + contract + tests for an id.                                 |
| `next_task`                  | First runnable task respecting DAG.                                     |
| `preflight`                  | Run P1–P6 over a task; returns `{ok, errors[]}`.                        |
| `worker_context`             | Returns minimized worker payload (no `system_index`).                   |
| `submit_attempt`             | Write worker files, run format/analyze/test/lint, persist results.      |
| `reviewer_context`           | Returns reviewer payload (adds `system_index` slice + run artifacts).   |
| `save_verdict`               | Persist reviewer verdict.                                               |
| `build_retry_context`        | Build the structured retry packet for the next worker attempt.          |
| `run_mutation`               | Execute the mutation suite for the task.                                |
| `commit_task`                | Mark `pass`, update `system_index.json`, invalidate dependents.         |
| `escalate_task`              | Mark `blocked`, record reason, emit patch hints for the architect.      |
| `apply_architect_patch`      | Validate & commit architect-written task/contract/test edits.           |
| `index_get` / `index_slice`  | Read the full index or a modules slice.                                 |
| `index_rebuild`              | Rebuild index from green tasks and repo reality.                        |

## Fallback mode

If the server is not running, the workflows implement the same logic inline
against the filesystem. Behaviour must remain identical; MCP is an
acceleration and state-discipline layer, not a gate.
