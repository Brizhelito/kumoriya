# Skill Creation Playbook

## Default rule

Use Codex's built-in `$skill-creator` first.

Why:
- it matches Codex's expected skill format
- it asks about triggers and boundaries
- it can create instruction-only or richer skills
- it reduces format drift

## Workflow

1. Decide whether the workflow truly repeats.
2. Run `$skill-creator`.
3. Generate the first draft.
4. Manually refine:
   - tighten trigger conditions
   - add exclusions
   - add validation requirements
   - add references or scripts only if justified
5. Commit the skill separately.

## Example candidates for new future skills

- jkanime-parser-hardening
- resolver-fixture-builder
- codex-pr-review
- plugin-health-check
- drift-schema-change
- offline-download-pipeline
