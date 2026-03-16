---
name: uiux-review
description: >-
  This skill should be used when auditing or improving Kumoriya Flutter screens
  and UX flows. Covers visual hierarchy, loading/empty/error/retry/unavailable
  states, interaction clarity, navigation flow, design system consistency,
  spacing rhythm, affordance quality, and prioritized actionable findings.
  Triggers on mentions of UI review, UX audit, screen review, visual hierarchy,
  state handling, loading state, error state, empty state, design consistency,
  interaction clarity, or user experience improvement in Kumoriya.
---

# uiux-review

## Purpose

Audit existing Kumoriya interfaces and produce concrete, implementable UI/UX improvement recommendations. This skill evaluates screens for visual hierarchy, state handling quality, interaction clarity, navigation flow, and design system consistency. It produces prioritized findings with specific implementation suggestions. It does not redesign entire flows or implement business logic -- it identifies and prioritizes concrete UX problems that can be fixed in vertical slices.

## Use When

- Reviewing an existing screen for UX quality (Home, Search, Anime Detail, Episode List, Player, Server Links).
- Diagnosing user-facing problems with state handling (loading, empty, error, retry, unavailable).
- Evaluating visual hierarchy and information architecture of a screen.
- Checking interaction affordances (buttons look tappable, actions have clear labels, feedback is visible).
- Assessing navigation clarity (users know where they are, where they can go, what happens next).
- Verifying design system consistency (typography, spacing, component behavior across screens).
- Prioritizing UI issues by user impact.

## Do Not Use When

- Implementing feature logic or business rules (use `flutter-vertical-slice`).
- Working on source plugins or resolvers (use `resolver-plugin`, `source-plugin-jkanime`).
- Working on player internals (use `player-slice`).
- Making architecture decisions (use `kumoriya-architecture`).
- Working on storage (use `storage-drift`).
- The task is a full design system creation or brand redesign (out of scope for this skill).

## What This Skill Does

1. Defines the audit target (specific screen or flow) and the user goal for that screen.
2. Inspects current widget structure, spacing, typography, interaction affordances, and state handling.
3. Evaluates state quality for all five mandatory states: loading, empty, error, retry, unavailable.
4. Checks visual hierarchy strength: primary action dominance, information order, spacing rhythm.
5. Checks interaction clarity: affordances, labels, feedback, dead ends.
6. Checks navigation clarity: user orientation, next-step visibility, back navigation.
7. Checks consistency with existing Kumoriya design system (theme, typography scale, component patterns).
8. Produces prioritized findings: critical (blocks user), important (causes confusion), cosmetic (polish).
9. Provides specific implementation suggestions referencing exact widgets and files.
10. Respects plugin-first uncertainty: source unavailable, no match, no links, resolver failure are normal states that must be handled explicitly.

## Required Inputs

- Target screen or flow to audit.
- Access to presentation code under `apps/kumoriya_app/lib/src/features/`.
- Access to shared widgets in `apps/kumoriya_app/lib/src/shared/widgets/`.
- Access to theme definition in `apps/kumoriya_app/lib/src/shared/theme/kumoriya_theme.dart`.
- Knowledge of the user goal for the target screen (what the user is trying to accomplish).

## Preconditions

- The target screen exists in code and can be located.
- The agent has read the screen's widget code before producing findings.
- The agent knows the Kumoriya design system basics (Material 3, project theme, spacing tokens).

## Procedure

1. **Define audit target.**
   ```
   Audit Target
   - Screen: [name and file path]
   - User goal: [what the user is trying to accomplish on this screen]
   - Scope: [full screen review | specific area | specific state]
   ```

2. **Read the screen code.** Open the target widget file and all directly used child widgets. Read the theme file. Understand current layout, state handling, and component usage.

3. **Evaluate visual hierarchy.**
   - Is the primary action visually dominant?
   - Is information order aligned with the user decision flow?
   - Is spacing rhythm consistent (using theme spacing tokens)?
   - Are section boundaries clear?

4. **Evaluate state quality.** For each applicable state:
   - **Loading**: Is progress visible? Is page structure preserved? Or is it a blank screen?
   - **Empty**: Is absence explained? Is there a recovery action? Or is it just blank?
   - **Error**: Is the failure source named in user language? Is there a next action? Or is it a generic "Something went wrong"?
   - **Retry**: Is retry visible and clearly labeled? Is it safe to repeat?
   - **Unavailable**: Is what's unavailable stated? Are alternatives offered?

5. **Evaluate interaction clarity.**
   - Do tappable elements look tappable (proper affordances)?
   - Are action labels specific to outcomes (not generic "Continue" or "OK")?
   - Is post-action feedback visible?
   - Are there dead ends where no clear next action exists?

6. **Evaluate navigation.**
   - Does the user know where they are?
   - Is the next step always visible?
   - Is back navigation safe and predictable?

7. **Evaluate consistency.**
   - Typography follows Material 3 intent and project tokens.
   - Buttons, cards, chips, list items behave consistently across screens.
   - Similar flows use similar interaction patterns.
   - EN/ES text lengths considered.

8. **Produce findings.** Each finding must include:
   ```
   Finding
   - Problem: [what is wrong]
   - Location: [file, widget, or section]
   - Impact: critical | important | cosmetic
   - UX consequence: [what the user experiences]
   - Suggestion: [specific implementable change]
   ```

9. **Prioritize findings.** Order by: critical first, then important, then cosmetic. Within each level, order by breadth of user impact.

10. **Produce audit report.**
    ```
    UX Audit Report
    - Screen: [name]
    - User goal: [recap]
    - Diagnosis: [overall assessment in 2-3 sentences]
    - Findings: [ordered list]
    - Implementation notes: [any dependencies or sequencing needed]
    ```

## Required Checks

- [ ] Every finding references a specific file or widget.
- [ ] Every finding has a concrete suggestion (not "improve this").
- [ ] All five states (loading, empty, error, retry, unavailable) were evaluated or explicitly marked as not applicable.
- [ ] Findings are prioritized (critical/important/cosmetic).
- [ ] No finding requires business logic implementation (UX-only scope).
- [ ] Plugin-first failure states were considered (source unavailable, no match, no links, resolver error).

## Expected Outputs

- Screen diagnosis (overall assessment).
- Prioritized findings with specific location, impact, and implementation suggestion.
- Implementation notes if findings have dependencies on each other.

## Anti-Patterns

- **Vague findings.** "The UI looks bad" is not a finding. Specify what is wrong, where, and what to do about it.
- **Redesigning everything.** Do not propose a full redesign when targeted fixes solve the problems.
- **Ignoring failure states.** Loading, empty, error, retry, and unavailable states are where most UX problems live.
- **Business logic in UX review.** Do not propose changes to matching, resolver, or data flow as UX findings.
- **Cosmetic-only focus.** Do not spend all findings on color tweaks when critical state handling is broken.
- **Ignoring plugin-first uncertainty.** In Kumoriya, "no data" and "source failed" are normal, expected states, not edge cases.
- **Platform-blind suggestions.** Remember Android-first with Windows support; touch targets and navigation patterns matter.

## Constraints

- Findings must be implementable within existing Flutter + Material 3 constraints.
- Do not propose third-party design libraries not already in the project.
- Do not propose changes that require architecture refactoring (escalate to `kumoriya-architecture` instead).
- Respect vertical-slice delivery: findings should be fixable in independent slices, not one massive PR.
- Treat AniList metadata as canonical for labels and information hierarchy.
- EN/ES bilingual text length differences must be considered.

## Minimal Example

Task: "Review the anime detail page UX."

1. Target: `apps/kumoriya_app/lib/src/features/anime_catalog/presentation/pages/anime_detail_page.dart`. User goal: understand anime info and navigate to episodes.
2. Read widget code and theme.
3. Findings:
   - Critical: Error state shows raw exception message instead of user-friendly text. File: `anime_detail_page.dart`. Suggestion: map `KumoriyaError` types to user messages, add retry button.
   - Important: Loading state is a centered `CircularProgressIndicator` without page structure. Suggestion: add shimmer skeleton matching the detail layout.
   - Cosmetic: Synopsis text has no max-lines with expand/collapse. Suggestion: add `maxLines: 4` with "Show more" toggle.
4. Report: ordered findings, note that error state fix should come before shimmer.

## Definition of Done

- All applicable states were evaluated.
- Findings are specific, located, prioritized, and actionable.
- No finding requires out-of-scope work (business logic, architecture changes).
- Plugin-first failure states were addressed.

## Project Assumptions

- Material 3 is the design system base. The project has a custom theme in `kumoriya_theme.dart`.
- Shared widgets exist in `apps/kumoriya_app/lib/src/shared/widgets/` including state views for loading, error, and empty states.
- The app targets Android-first with Windows support. Touch targets (48dp minimum) and mouse interaction both matter.
- **Risk: the shared widget library may not cover all needed states. Findings may require creating new shared widgets.**
- **Risk: some screens may have incomplete state handling that requires application-layer changes, not just UI fixes. These should be escalated as out-of-scope.**

Consult [references/uiux-audit-checklist.md](references/uiux-audit-checklist.md) as the fast checklist during audits.
