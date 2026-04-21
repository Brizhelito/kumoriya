---
name: flutter-vertical-slice
description: Implement bounded Flutter vertical slices in Kumoriya (Riverpod + clean architecture). Use for scoped feature or bugfix slices requiring package mapping, validation (format/analyze/tests) and versioning milestones.
---

# Flutter Vertical Slice (Kumoriya)

Execute one requested slice only. Keep changes small, testable, and architecture-safe.

## Apply hard constraints first

1. Read `AGENTS.md` and honor project non-negotiables before planning code.
2. Implement only the explicitly requested slice.
3. Reject implicit expansion. If a needed dependency is out of scope, add a minimal seam/TODO instead of broadening work.
4. Respect modular boundaries: UI must not depend on concrete plugins; contracts stay in plugin-facing packages.
5. Prefer conservative behavior over unsafe guesses (matching/streaming rules).

## Slice intake and scope lock

1. Restate slice in one sentence: user goal + boundary.
2. Define in-scope items:
   - capability to add/change
   - acceptance criteria
   - target package(s)
3. Define out-of-scope items explicitly (features, refactors, migrations, unrelated cleanup).
4. If requirement is ambiguous, choose the narrowest safe interpretation.

Output this block before coding:

```md
Slice Scope
- Goal:
- In scope:
- Out of scope:
- Done when:
```

## Map packages and layers

Identify touched modules before edits.

1. Locate affected package(s) in monorepo.
2. Map impacted layers only where needed:
   - presentation (widgets/controllers/providers)
   - application (use-cases/orchestration)
   - domain (entities/value objects/contracts)
   - data/plugin/storage adapters
3. Keep dependency direction clean; do not leak infra concerns into domain.

Output this block:

```md
Affected Areas
- package:
- layer(s):
- why touched:
```

## Incremental implementation plan

Use the smallest sequence that delivers working behavior.

1. Create a short plan (3-6 steps max).
2. Order by vertical usefulness (domain/app/presentation wiring only as needed).
3. Prefer additive, reviewable commits over mixed large diffs.
4. For each step, state expected artifact (code/test/wiring).

Output this block:

```md
Execution Plan
1. ...
2. ...
3. ...
```

## File targeting discipline

Before editing, list probable files to touch. Keep list tight.

```md
Probable Files
- path/to/file_a.dart (reason)
- path/to/file_b.dart (reason)
```

If new files are required, place them in the correct package/layer and keep naming consistent with existing conventions.

## Validation is mandatory

Run real checks; never claim stability without execution evidence.

Minimum validation checklist:

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze (affected package or repo rule)
- [ ] relevant tests (unit/widget/integration for slice)
- [ ] run/build check when slice affects runtime wiring, startup, navigation, platform, or generated code
```

Rules:
- If a command cannot run, say exactly why.
- Report failures and residual risk explicitly.
- Do not mark checklist items complete without command execution.

## Versioning by milestones

Require clear checkpoints aligned with slice steps.

1. Use concise conventional commits when committing.
2. Keep unrelated edits out of the milestone.
3. Describe milestone intent in one line.

Use this structure:

```md
Versioning Milestones
1. <type(scope): message> - <intent>
2. <type(scope): message> - <intent>
```

## Final report format

Return a compact, auditable report:

```md
Slice Delivery Report
- Scope recap:
- Implemented:
- Files changed:
- Validation run:
  - command: <cmd>
  - result: <pass/fail>
- Residual risk:
- Suggested next slice:
```

Do not include speculative future roadmap unless user asks.
