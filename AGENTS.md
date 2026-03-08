# Kumoriya - Codex Project Instructions

## Mission

Build Kumoriya as a plugin-first otaku platform for:

- anime streaming
- anime downloads
- manga/manhwa reading
- offline-first usage
- strong tracking/subscription logic
- Android-first with Windows support

## Non-negotiables

1. **AniList is the canonical metadata source.**
2. **Plugins are first-class from day 1.**
3. **WebView is last-resort infrastructure, not a visible UX primitive.**
4. **Prefer no match over false match.**
5. **Prefer no stream over wrong stream.**
6. **Avoid code copied blindly from legacy projects.**
7. **Every structural decision must protect long-term maintainability.**
8. **Work by vertical slices, not giant rewrites.**

## Working style

- Be pragmatic with strict boundaries.
- Keep changes scoped.
- Do not inflate architecture without clear payoff.
- Prefer explicit contracts and testable modules.
- Use Git checkpoints for meaningful phases.
- Use worktrees for risky or long-running tasks.
- Prefer small reviewable diffs.

## Architecture guardrails

- Feature-first modular monolith.
- Riverpod for state and DI.
- Result/Either style error handling for domain/application/plugin boundaries.
- UI must not depend on concrete plugin implementations.
- Plugin contracts live in plugin-facing packages, not in UI packages.
- Domain models stay clean and framework-light.
- Storage is a separate concern.
- The player does not resolve links.
- Resolvers are independent and individually testable.

## Matching rules

- AniList -> source matching must be conservative.
- Normalize strings before comparing.
- Titles, aliases, format, and year may contribute.
- If confidence is weak, return no match.
- Do not silently auto-link low-confidence matches.

## Scraping rules

- Prefer resilient selectors and parser helpers.
- Add fixtures whenever the parsing logic is non-trivial.
- Avoid brittle logic that depends on one exact DOM shape when a safer alternative exists.
- Keep source plugins independent from resolver plugins.

## Validation rules

For implementation tasks:
- run formatting
- run static analysis
- run relevant tests
- report residual risk honestly

Do not claim a feature is stable if:
- the app does not compile
- the targeted flow was not actually exercised
- tests were skipped without saying so

## Version control rules

- Use descriptive commits.
- Do not dump unrelated changes into one commit.
- Use conventional commit style when possible.
- Keep architecture/docs/bootstrap commits distinct from feature commits.

## Skills policy

- Use repository skills when they clearly match the task.
- Prefer explicit invocation for important workflows.
- For new recurring workflows, use `$skill-creator` to generate a first draft, then refine it manually.
- Keep skills narrow, triggerable, and easy to audit.

## When to use multi-agents

Use multi-agents for:
- architecture exploration
- codebase mapping
- comparing two implementation strategies
- PR review and risk analysis
- documentation validation against external docs

Do not use multi-agents for tiny edits.

## Current priority

1. clean Codex-native repo setup
2. stable architecture and control plane
3. slice-based product implementation
4. source plugin integration
5. playback pipeline
6. offline/download stack
