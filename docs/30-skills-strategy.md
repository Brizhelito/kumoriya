# Skills Strategy for Kumoriya

## Principle

Use repository skills for repeatable, high-value workflows.

Keep skills:
- narrow
- triggerable
- auditable
- composable

## Starter skills in this kit

- kumoriya-architecture
- flutter-vertical-slice
- source-plugin
- resolver-plugin
- anilist-matching
- visual-foundation
- validate-task
- skill-factory

## When to use `$skill-creator`

Use Codex's built-in `$skill-creator` when:
- a workflow repeats 3+ times
- a prompt is too long to keep rewriting
- the workflow needs scripts, references, or assets
- you want the skill available in app, IDE, and CLI

Do **not** create a skill for one-off tasks.

## Skill review checklist

- clear `name`
- clear `description`
- explicit trigger boundaries
- scope exclusions
- validation requirements
- references/scripts only if they add real value
