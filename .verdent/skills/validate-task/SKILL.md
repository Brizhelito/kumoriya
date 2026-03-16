---
name: validate-task
description: >-
  This skill should be used when closing a Kumoriya task and performing strict
  validation before declaring it done. Covers formatting verification, static
  analysis, relevant test execution, affected flow verification, differentiation
  between local and live validation, honest reporting of what was NOT validated,
  residual risk documentation, and prevention of false "done" claims. Triggers
  on mentions of task validation, closing validation, pre-commit checks, done
  checklist, validation pass, task closure, format check, analyze check, or
  residual risk report in Kumoriya.
---

# validate-task

## Purpose

Perform strict, evidence-based validation before declaring any Kumoriya task complete. This skill prevents false "done" claims by requiring executed validation commands, honest reporting of what was and was not validated, and explicit documentation of residual risks. It is the final gate before a task can be considered closed. It does not implement features -- it validates that implemented features are correct, stable, and honestly reported.

## Use When

- A feature slice, bugfix, or any code change is believed to be complete.
- Before creating a commit for completed work.
- When the user asks to validate or close a task.
- As the final step of any other skill's procedure (all skills should end with validation).
- When reviewing whether a previous task was properly closed.

## Do Not Use When

- The task is still in progress (validate when done, not mid-work).
- No code was changed (nothing to validate).
- The task is purely a research or architecture decision (use `kumoriya-architecture`).
- The task is a UX audit without implementation (use `uiux-review`).

## What This Skill Does

1. Runs `dart format` on all affected file paths and reports pass/fail.
2. Runs `dart analyze` on affected packages and reports all issues.
3. Identifies and runs relevant tests for the changed code.
4. Verifies the affected user flow was actually exercised (not just compiled).
5. Distinguishes between local validation (format/analyze/test) and live validation (app actually runs, flow works end-to-end).
6. Reports exactly which commands were executed and their results.
7. Reports what was NOT validated and why (e.g., "live playback flow not tested because no device connected").
8. Documents residual risks: what could still break despite passing validation.
9. Checks that scope was not silently exceeded (no unrequested changes).
10. Prevents marking a task as "done" if build is broken, tests fail, or critical validation was skipped without acknowledgment.

## Required Inputs

- List of files/packages changed by the task.
- Description of the task and its acceptance criteria.
- Knowledge of which tests are relevant to the change.
- Knowledge of whether the change affects runtime behavior (requiring live validation) or is purely static.

## Preconditions

- The task implementation is believed to be complete.
- The agent knows which files and packages were modified.
- The agent can run `dart format`, `dart analyze`, and `dart test` commands.

## Procedure

1. **Identify validation scope.**
   ```
   Validation Scope
   - Task: [what was implemented]
   - Files changed: [list]
   - Packages affected: [list]
   - Acceptance criteria: [from original task]
   - Requires live validation: [yes/no + reason]
   ```

2. **Run formatting check.**
   ```
   dart format --set-exit-if-changed <affected paths>
   ```
   Report: command, exit code, any files that needed formatting.
   If formatting fails: fix and re-run before proceeding.

3. **Run static analysis.**
   ```
   dart analyze <affected package or repo root>
   ```
   Report: command, result, any issues found.
   If analysis fails: categorize issues as pre-existing vs new. Fix new issues before proceeding. Document pre-existing issues as not introduced by this task.

4. **Identify and run relevant tests.**
   - Determine which test files cover the changed code.
   - If uncertain, run all tests in the affected package.
   ```
   dart test <test paths or package>
   ```
   Report: command, pass count, fail count, skip count.
   If tests fail: fix failures. If a failure is pre-existing (existed before this task), document it clearly.

5. **Verify affected flow.**
   - If the change affects runtime behavior (UI, navigation, playback, network): state whether the flow was manually exercised or not.
   - If it was exercised: state how (device, emulator, specific steps).
   - If it was NOT exercised: state why and classify as residual risk.

6. **Check scope discipline.**
   - Review the list of changed files against the original task scope.
   - Flag any files changed that were not in scope.
   - If out-of-scope changes exist, document them and explain why they were necessary (or revert them).

7. **Produce validation report.**
   ```
   Task Validation Report
   - Task: [description]
   - What changed: [files/packages]
   
   Executed Checks:
   - Format: [command] -> [result]
   - Analyze: [command] -> [result]
   - Tests: [command] -> [pass/fail/skip counts]
   - Flow exercised: [yes/no + details]
   
   What was NOT validated:
   - [item] -- reason: [why]
   
   Residual risks:
   - [risk] -- trigger: [what could cause it] -- impact: [severity]
   
   Scope check:
   - All changes in scope: [yes/no]
   - Out-of-scope changes: [list or "none"]
   
   Verdict: [PASS | PASS WITH RISKS | FAIL]
   ```

8. **Determine verdict.**
   - **PASS**: all checks pass, flow was exercised or no runtime behavior changed, no residual risks.
   - **PASS WITH RISKS**: all checks pass, but live validation was not performed or known edge cases remain. Risks must be documented.
   - **FAIL**: format/analyze/tests fail, or the affected flow was not exercised when it should have been. Task cannot be closed.

## Required Checks

- [ ] `dart format` executed and passes.
- [ ] `dart analyze` executed and reports no new issues.
- [ ] Relevant tests executed and pass.
- [ ] Affected flow verification status documented (exercised or not, with reason).
- [ ] "What was NOT validated" section is filled in (even if empty).
- [ ] Residual risks documented (even if "none identified").
- [ ] Scope check performed (no unrequested changes).
- [ ] Verdict is stated explicitly.

## Expected Outputs

- Task validation report with all sections filled.
- Clear verdict (PASS / PASS WITH RISKS / FAIL).
- Honest documentation of what was and was not validated.
- Residual risk list.

## Anti-Patterns

- **Claiming "done" without running commands.** Every check must have an executed command and observed result.
- **Hiding skipped tests.** If tests were skipped, state which ones and why.
- **Ignoring pre-existing failures.** Separate pre-existing issues from new ones. Do not let pre-existing failures mask new problems.
- **Vague "it works" claims.** State specifically how the flow was exercised: which device/emulator, which steps, what was observed.
- **Conflating local and live validation.** `dart test` passing does not mean the app runs correctly. Distinguish between them.
- **Reporting only success.** The "What was NOT validated" section is mandatory. If everything was validated, state that explicitly.
- **Silent scope creep.** If files outside the original scope were changed, flag them in the scope check.
- **Marking PASS when tests fail.** If any relevant test fails and was not pre-existing, the verdict is FAIL. No exceptions.

## Constraints

- Validation must use real executed commands, not hypothetical ones.
- Format, analyze, and test are the minimum mandatory checks. Additional checks (build, code generation) are required when applicable.
- The validation report format is fixed and all sections are mandatory.
- Verdict must be one of: PASS, PASS WITH RISKS, FAIL. No ambiguous statuses.
- Pre-existing issues must be clearly labeled as such, not hidden or attributed to the current task.
- This skill does not implement fixes -- it validates. If validation fails, the fix is a separate action before re-validating.

## Minimal Example

Task: "Added shimmer loading to anime detail page."

1. Scope: `anime_detail_page.dart` changed, `shared/widgets/shimmer_widget.dart` created. Package: `apps/kumoriya_app`.
2. Format: `dart format apps/kumoriya_app/lib/src/features/anime_catalog/presentation/pages/anime_detail_page.dart apps/kumoriya_app/lib/src/shared/widgets/shimmer_widget.dart` -> pass.
3. Analyze: `dart analyze apps/kumoriya_app/` -> pass, 0 issues.
4. Tests: `dart test apps/kumoriya_app/test/ --name "anime_detail"` -> 3 passed, 0 failed.
5. Flow: not exercised on device (no emulator available). Residual risk: shimmer layout may not match actual page structure at runtime.
6. Scope: 2 files changed, both in scope.
7. Verdict: PASS WITH RISKS. Risk: visual verification pending.

## Definition of Done

- All sections of the validation report are filled.
- Verdict is stated explicitly with justification.
- No check was claimed without an executed command.
- Residual risks are documented.

## Project Assumptions

- `dart format`, `dart analyze`, and `dart test` are the standard validation commands for the Dart/Flutter monorepo.
- Tests can be targeted by package or by name filter.
- **Risk: some packages may have flaky tests or incomplete coverage. Document this when encountered.**
- **Risk: live flow validation requires a connected device or emulator, which may not always be available. This is an expected gap -- document it, do not skip the entire validation.**
- Build checks (`flutter build`) are needed when platform-specific code, startup wiring, or generated code was changed.
- Code generation (`dart run build_runner build`) is needed when Drift tables, JSON serialization, or Riverpod code generation annotations were modified.
