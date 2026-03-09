---
name: uiux-review
description: Audit and improve Kumoriya Flutter UI/UX with concrete, implementable recommendations. Use when reviewing existing screens (Home, Search, Anime Detail, Episode List, Server Links, Resolve Result), diagnosing visual hierarchy, interaction clarity, loading/empty/error/retry/unavailable states, navigation, and design-system consistency. Do not use for business logic implementation, plugin/resolver/player work, or architecture refactors.
---

# UIUX Review

## Mission

Audit existing Kumoriya interfaces and propose clear, low-risk UI/UX improvements that can be implemented inside current Flutter and Material 3 constraints.

## Boundaries

Keep scope strictly in UI, layout, interaction, and visual clarity.
Do not implement features, business rules, source plugins, resolver plugins, playback, or architecture changes.
Do not rewrite large flows when targeted screen-level improvements solve the issue.
Prefer incremental, reviewable changes.

## Audit Workflow

1. Define audit target and user goal for the screen.
2. Inspect current structure, spacing, typography, interaction affordances, and state handling.
3. Identify concrete UX problems and explain why each problem increases confusion, friction, or failure risk.
4. Propose realistic UI changes tied to each problem.
5. Prioritize changes by impact and implementation effort.

## Kumoriya Context Rules

Treat AniList metadata as canonical context for labels and information hierarchy.
Design for plugin-first uncertainty: source unavailable, no match, no links, resolver failure are normal states and must be explicit.
Support Android-first interaction ergonomics while remaining usable on Windows.
Respect i18n for English and Spanish text length differences.
Keep proposals compatible with vertical-slice delivery.

## Required Checks Per Screen

Check visual hierarchy strength between page title, primary actions, and secondary metadata.
Check cognitive load: reduce simultaneous choices and remove non-essential UI noise.
Check spacing rhythm using design-system spacing tokens and consistent section grouping.
Check affordances so actions look tappable and intent is explicit.
Check navigation clarity so users always know the next step.
Check state quality for loading, empty, error, retry, and unavailable outcomes.
Check consistency with existing Kumoriya components and typography scale.

## State Quality Standards

For loading state, show progress intent and preserve page structure when possible.
For empty state, explain why data is missing and what action can recover.
For error state, name the failure source in user language and offer next action.
For retry state, provide explicit retry action with clear label.
For unavailable state, state what is unavailable now and what alternatives exist.

## Defensive UX Rules

Replace ambiguous actions like generic "Continue" with outcome-specific labels.
Show post-action feedback for operations that change user context.
Avoid dead ends where no clear next action exists.
Prefer no-result clarity over speculative or misleading UI.

## Output Contract

Always return the audit in this exact structure:

1. Screen diagnosis
2. Problems detected
3. UX impact
4. Concrete improvement proposals
5. Suggested UI-level changes

Keep proposals actionable for Flutter implementation.
Reference exact files and widgets when available.
State assumptions explicitly when screen context is incomplete.

## References

Use [references/uiux-audit-checklist.md](references/uiux-audit-checklist.md) as the fast checklist during audits.
