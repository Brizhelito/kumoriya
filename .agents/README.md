# .agents/

Orchestration state for the Architect/Worker/Reviewer pipeline.

## Layout

- `rules.yaml` — roles, budgets, guards. Canonical config.
- `system_index.json` — structural memory of modules, exports, invariants.
- `tasks/` — one YAML per task. `_template.yaml` is the schema.
- `contracts/` — one JSON per module. `_template.json` is the schema.
- `tests/` — one spec per task. `_template.spec.yaml` is the schema.
- `runs/<TASK_ID>/` — per-attempt worker outputs, reviewer verdicts, retry context.
- `skills/` — Claude-style progressive-disclosure skills (existing, untouched).

## Who reads what

| File                   | Architect | Worker | Reviewer |
|------------------------|-----------|--------|----------|
| `rules.yaml`           | yes       | summary only | yes |
| `system_index.json`    | yes       | **never** | yes (slice) |
| `tasks/*.yaml`         | yes (own) | yes (single) | yes |
| `contracts/*.json`     | yes       | yes (referenced) | yes |
| `tests/*.spec.yaml`    | yes       | yes (referenced) | yes |
| `runs/*/attempt-*.json`| on escalate | **never** (worker is stateless across attempts) | yes |
| other source files     | index only | only `task.files_allowed` | yes |

## Entry points

Use the Windsurf workflows in `.windsurf/workflows/`:

- `/architect-plan` — plan a feature (strong model)
- `/run-next-task` — execute the next runnable task end-to-end
- `/worker-run` — implement one task (cheap model)
- `/reviewer-check` — validate one attempt (strong or mid)
- `/escalate-task` — send a failing task back to the architect
- `/index-refresh` — rebuild `system_index.json` from ground truth

When the `kumoriya-orch` MCP server is running (`tools/kumoriya-orch/`),
workflows delegate state mutations to it. Without MCP, they fall back to
direct file reads/writes.
