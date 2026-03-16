---
name: flutter-vertical-slice
description: >-
  This skill should be used when implementing a bounded Flutter vertical slice
  in the Kumoriya modular monorepo. Covers scope locking, affected-file mapping,
  incremental implementation planning, Riverpod wiring, layer discipline
  (presentation/application/domain/data), validation (format/analyze/test/build),
  milestone commits, and residual risk reporting. Triggers on mentions of
  vertical slice, feature slice, bugfix slice, incremental step, bounded change,
  slice implementation, or scoped Flutter task within the Kumoriya monorepo.
---

# flutter-vertical-slice

## Purpose

Execute one explicitly requested vertical slice in the Kumoriya Flutter monorepo. A vertical slice is a small, bounded, end-to-end change that delivers a single user-visible capability or fixes a single concrete problem. This skill enforces scope discipline, layer boundaries, incremental delivery, and honest validation. It prevents scope creep, mixed concerns, and unvalidated "done" claims.

## Use When

- Implementing a new feature slice that touches presentation, application, and/or domain layers.
- Fixing a bug that spans multiple files within a single feature.
- Adding a new screen, provider, use case, or widget as part of a bounded task.
- Any task where the request is "implement X" and X maps to a single feature slice.
- Integrating a new package or wiring into the app within a scoped boundary.

## Do Not Use When

- Making architecture decisions about package boundaries (use `kumoriya-architecture`).
- Working exclusively on matching logic (use `anilist-matching`).
- Working exclusively on player features (use `player-slice`).
- Working exclusively on resolver plugins (use `resolver-plugin`).
- Working exclusively on storage/Drift (use `storage-drift`).
- Doing UI/UX audits without implementation (use `uiux-review`).
- Performing task closure validation only (use `validate-task`).
- The change is a broad horizontal refactor affecting 10+ files across unrelated features.

## What This Skill Does

1. Forces explicit scope definition before any code is written.
2. Maps all packages, layers, and files affected by the slice.
3. Reads existing code in affected areas before editing to understand conventions, imports, and patterns.
4. Creates an incremental implementation plan with 3-6 steps maximum.
5. Enforces layer discipline: UI does not depend on concrete plugins; domain stays framework-light; contracts live in plugin-facing packages.
6. Enforces Riverpod patterns consistent with existing providers.
7. Rejects implicit expansion: if something is needed but out of scope, adds a minimal seam or TODO instead of broadening work.
8. Runs validation (format, analyze, test, build check) and reports results with exact commands.
9. Reports residual risk honestly: what was not tested, what could break, what needs follow-up.
10. Produces conventional commits aligned with slice milestones.

## Required Inputs

- Clear description of the slice to implement (user goal + acceptance criteria).
- Access to the Kumoriya monorepo at `C:\Users\Reny\Documents\Kumoriya`.
- Knowledge of the monorepo structure: `apps/kumoriya_app/` (main app), `packages/` (shared packages).
- Knowledge of feature-first structure under `apps/kumoriya_app/lib/src/features/`.
- Knowledge of Riverpod as the state management and DI framework.
- Knowledge of `Result<T, KumoriyaError>` error handling at domain/application boundaries.

## Preconditions

- The repo compiles (`dart analyze` on affected packages reports no pre-existing errors in the scope).
- The agent has read the files it intends to modify before making changes.
- The slice request is specific enough to define a clear "done when" condition.

## Procedure

1. **Restate the slice** in one sentence: user goal + boundary. If the request is ambiguous, choose the narrowest safe interpretation.

2. **Publish scope lock.**
   ```
   Slice Scope
   - Goal: [one sentence]
   - In scope: [capabilities/files/layers to change]
   - Out of scope: [explicitly excluded concerns]
   - Done when: [acceptance criteria]
   ```

3. **Map affected areas.** List every package, layer, and file that will be touched, with a one-line reason for each.
   ```
   Affected Areas
   - package: [name]
   - layer(s): [presentation/application/domain/data]
   - why touched: [reason]
   ```

4. **Read existing code.** Before editing any file, read it to understand: imports, naming conventions, existing patterns, Riverpod provider style, error handling approach. Do not guess conventions.

5. **Create implementation plan.** 3-6 steps maximum, ordered by vertical usefulness. Each step states the expected artifact (code/test/wiring).
   ```
   Execution Plan
   1. [step] -> [artifact]
   2. [step] -> [artifact]
   3. [step] -> [artifact]
   ```

6. **Implement each step.** Follow existing code style. Use `Result<T, KumoriyaError>` at boundaries. Wire providers following existing Riverpod patterns. Keep new files in the correct package/layer with consistent naming.

7. **Handle out-of-scope dependencies.** If implementation reveals a needed dependency outside scope, add a minimal typed seam (interface, TODO, or stub) and document it. Do not expand scope.

8. **Run validation.**
   ```
   dart format <affected paths>
   dart analyze <affected package or full repo>
   dart test <relevant test paths>
   ```
   If a build check is needed (wiring, startup, navigation, platform, generated code changed), run it and report the result.

9. **Report results.**
   ```
   Slice Delivery Report
   - Scope recap: [what was done]
   - Files changed: [list]
   - Validation: [commands + results]
   - Residual risk: [what was not validated]
   - Suggested next slice: [if applicable]
   ```

## Required Checks

- [ ] `dart format` passes on all affected paths.
- [ ] `dart analyze` reports no new issues in affected packages.
- [ ] Relevant tests pass (existing + new).
- [ ] No file was edited without being read first.
- [ ] Layer discipline verified: no UI -> concrete plugin dependency, no domain -> infra leakage.
- [ ] Out-of-scope items documented, not silently implemented.
- [ ] If generated code was affected, code generation was re-run.

## Expected Outputs

- Implemented slice code (models, providers, widgets, use cases as applicable).
- Tests for new logic (unit or widget level).
- Validation evidence (exact commands and pass/fail).
- Residual risk statement.
- Conventional commit(s) with clear message(s).

## Anti-Patterns

- **Scope inflation.** Implementing features, refactors, or cleanups not requested.
- **Editing without reading.** Modifying a file without reading its current content and understanding its conventions.
- **Layer violation.** UI importing concrete plugin implementations, domain importing Drift classes, or providers containing SQL.
- **Mixed commits.** Combining unrelated changes in a single commit.
- **Claiming "done" without validation.** Marking the slice complete without running format/analyze/test.
- **Silent expansion.** Adding an out-of-scope dependency without documenting it.
- **Broad refactoring as a slice.** Treating a horizontal refactor as a vertical slice.

## Constraints

- One slice at a time. Do not batch multiple unrelated slices.
- Changes must be reviewable: small diff, clear intent.
- Riverpod is the only DI/state management framework. Do not introduce alternatives.
- `Result<T, KumoriyaError>` at all domain/application/plugin boundaries.
- UI must not depend on concrete plugin implementations.
- Plugin contracts live in `packages/kumoriya_plugins/`, not in app packages.
- Domain models in `packages/kumoriya_domain/` must stay clean and framework-light.
- Storage is a separate concern in `packages/kumoriya_storage/`.

## Minimal Example

Task: "Add a loading shimmer to the anime detail page while fetching data."

1. Scope: Goal = add shimmer loading state to anime detail page. In scope = presentation layer of anime_catalog. Out of scope = data fetching logic, matching, player. Done when = shimmer shows during load, real content replaces it.
2. Map: `apps/kumoriya_app/lib/src/features/anime_catalog/presentation/pages/anime_detail_page.dart` (add shimmer), possibly `shared/widgets/` (if shimmer widget exists).
3. Read existing anime_detail_page.dart and shared widgets.
4. Plan: (1) Check if shimmer widget exists in shared -> reuse or create, (2) Add loading state branch in anime detail page, (3) Test widget rendering.
5. Implement, validate with `dart format` + `dart analyze` + `dart test`.
6. Report: files changed, validation passed, no residual risk.

## Definition of Done

- The slice's acceptance criteria are met.
- All validation commands pass with zero new issues.
- Residual risk is stated honestly (even if it's "none identified").
- No out-of-scope work was done silently.
- Commit(s) are clean and follow conventional style.

## Project Assumptions

- The monorepo uses `melos` or workspace-level `pubspec.yaml` for package management. Commands like `dart analyze` and `dart test` can target individual packages.
- Feature directories follow the pattern `features/<name>/{presentation,application,domain}/`.
- Riverpod providers are defined in dedicated `providers/` files within each feature.
- The project targets Android-first with Windows support; platform-specific considerations may apply.
- **Risk: some packages may have incomplete test coverage, so "all tests pass" may not catch all regressions.**
