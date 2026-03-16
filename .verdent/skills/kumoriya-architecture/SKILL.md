---
name: kumoriya-architecture
description: >-
  This skill should be used when making, reviewing, or evaluating structural
  decisions for the Kumoriya project. Covers package boundary enforcement,
  plugin-first architecture protection, contract design, dependency direction
  validation, coupling detection, responsibility ownership, vertical-slice vs
  horizontal-refactor decisions, and compatibility with project priorities.
  Triggers on mentions of architecture, package boundaries, contracts,
  coupling, dependency direction, plugin-first, modular monolith, structural
  decision, or package reorganization in Kumoriya.
---

# kumoriya-architecture

## Purpose

Evaluate, enforce, and evolve the structural architecture of the Kumoriya monorepo. This skill is the decision framework for any change that affects package boundaries, contracts, dependency directions, or responsibility ownership. It protects the plugin-first modular monolith from accidental coupling, premature abstraction, and architecture erosion. It is not for implementing features -- it is for deciding whether a structural change is safe, necessary, and aligned with project priorities.

## Use When

- A change introduces a new package or moves code between packages.
- A change adds a dependency between packages that did not exist before.
- A change modifies or creates a contract (interface, abstract class) used across package boundaries.
- Evaluating whether a refactor should be vertical (slice) or horizontal (cross-cutting).
- Reviewing whether a PR respects architecture boundaries.
- Deciding where new functionality should live (which package, which layer).
- Resolving disputes about responsibility ownership between packages.
- Evaluating whether a new abstraction is justified or premature.

## Do Not Use When

- Implementing a feature slice within existing boundaries (use `flutter-vertical-slice`).
- Working on matching logic (use `anilist-matching`).
- Working on player specifics (use `player-slice`).
- Working on resolver/source plugin implementation (use `resolver-plugin`, `source-plugin-jkanime`).
- Working on storage implementation (use `storage-drift`).
- The change is purely cosmetic or local to a single file within a single package.

## What This Skill Does

1. Identifies which packages and boundaries a proposed change affects.
2. Validates dependency direction: no upward dependencies (UI -> domain is ok, domain -> UI is not), no lateral coupling between independent plugins.
3. Detects accidental coupling: UI depending on concrete plugin implementations, domain importing infrastructure, storage leaking into presentation.
4. Evaluates contract quality: are interfaces minimal, are they in the right package, do they use `Result<T, KumoriyaError>`?
5. Determines responsibility ownership: which package owns a capability, and whether a proposed change moves ownership correctly.
6. Decides vertical-slice vs horizontal-refactor: prefers vertical slices unless the horizontal change is provably necessary and bounded.
7. Evaluates alignment with project priorities (plugin-first, offline-first, Android-first, AniList canonical).
8. Produces a structured architectural decision record with rationale, risks, and recommendation.
9. Verifies that real seams exist in code before claiming a boundary exists.
10. Prevents architecture inflation: rejects abstractions that add complexity without clear payoff.

## Required Inputs

- Description of the proposed structural change or question.
- Access to the Kumoriya monorepo source code.
- Knowledge of the current package map:
  - `packages/kumoriya_core/` -- shared utilities, Result type, errors.
  - `packages/kumoriya_domain/` -- domain models, repository interfaces.
  - `packages/kumoriya_plugins/` -- plugin contracts (SourcePlugin, ResolverPlugin), plugin models.
  - `packages/kumoriya_matching/` -- entity resolution pipeline.
  - `packages/kumoriya_storage/` -- Drift persistence.
  - `packages/kumoriya_anilist/` -- AniList API client.
  - `packages/kumoriya_source_*/` -- source plugin implementations.
  - `packages/kumoriya_resolver_*/` -- resolver plugin implementations.
  - `apps/kumoriya_app/` -- Flutter app with feature-first structure.

## Preconditions

- The agent has read the actual code involved in the structural change (not just assumed it exists).
- The agent understands the current dependency graph between involved packages.

## Procedure

1. **Identify the structural change.** State precisely: what package/boundary/contract is being created, modified, or removed.

2. **Map current dependencies.** Read `pubspec.yaml` of affected packages. Draw the dependency direction. Identify which packages currently depend on which.

3. **Validate dependency direction.** Check:
   - Domain packages do not depend on infrastructure/UI packages.
   - Plugin contracts live in `kumoriya_plugins`, not in app or UI packages.
   - Source plugins do not depend on resolver plugins or vice versa.
   - The player does not depend on scraping/resolution logic directly.
   - Storage does not depend on UI models.

4. **Check for accidental coupling.** Search for:
   - Concrete plugin class imports in UI code.
   - Drift-generated class imports above the repository boundary.
   - Direct HTTP client usage in domain/application layers.
   - Provider implementations containing infrastructure details.

5. **Evaluate the proposed change against architectural rules:**
   - Does it maintain plugin-first design?
   - Does it keep vertical slice boundaries clean?
   - Does it introduce a new dependency that could be avoided?
   - Does it create an abstraction with clear consumers, or is it speculative?
   - Is the contract minimal and testable?

6. **Determine if vertical slice or horizontal refactor is appropriate:**
   - Vertical slice: change is bounded to one feature, touches few packages, delivers user value directly.
   - Horizontal refactor: change affects 5+ files across multiple features, is necessary for unblocking future slices, and has a clear stopping point.
   - Default to vertical slice unless horizontal refactor is provably necessary.

7. **Produce architectural decision record.**
   ```
   Architecture Decision
   - Change: [what is being changed]
   - Packages affected: [list]
   - Dependency direction: [validated/violated]
   - Coupling risk: [none/low/medium/high + details]
   - Contract impact: [new/modified/none]
   - Alignment with priorities: [yes/partial/no + explanation]
   - Recommendation: [accept/reject/modify + rationale]
   - Risks: [identified risks]
   - Minimal next step: [concrete action]
   ```

## Required Checks

- [ ] Dependency direction validated by reading `pubspec.yaml` files.
- [ ] No concrete plugin class imported in UI code.
- [ ] No Drift class leaking above repository boundary.
- [ ] Contract interfaces use `Result<T, KumoriyaError>`.
- [ ] New abstractions have at least two concrete consumers or a clear imminent need.
- [ ] The change was evaluated against all non-negotiable rules.

## Expected Outputs

- Architectural decision record with rationale.
- Dependency direction validation results.
- Coupling risk assessment.
- Concrete recommendation (accept/reject/modify) with minimal next step.
- Risk documentation.

## Anti-Patterns

- **Rubber-stamping.** Approving a structural change without reading the actual code.
- **Architecture astronautics.** Adding layers, abstractions, or packages without concrete consumers.
- **Boundary theatre.** Claiming a boundary exists when the code has direct imports that violate it.
- **Horizontal sprawl.** Doing a broad refactor when a vertical slice would suffice.
- **Plugin contract bloat.** Adding methods to plugin contracts that only one plugin needs.
- **Coupling denial.** Ignoring a dependency violation because "it works for now."
- **Decision without evidence.** Making structural claims without reading pubspec.yaml and import statements.

## Constraints

- Plugin-first architecture is non-negotiable.
- UI must not depend on concrete plugin implementations.
- Plugin contracts live in `packages/kumoriya_plugins/`.
- Domain models live in `packages/kumoriya_domain/` and must stay framework-light.
- Storage is a separate concern in `packages/kumoriya_storage/`.
- The player does not resolve links.
- Resolvers are independent and individually testable.
- AniList is the canonical metadata source.
- Prefer no match over false match; prefer no stream over wrong stream.
- Every structural decision must protect long-term maintainability.

## Minimal Example

Task: "Should the player package import `kumoriya_resolver_anime_nexus` directly to handle HLS signing?"

1. Read `pubspec.yaml` of player feature and `kumoriya_resolver_anime_nexus`.
2. Dependency direction check: player should consume `ResolvedStream` from `kumoriya_plugins`, not import concrete resolvers.
3. Coupling risk: HIGH -- player would become coupled to a specific resolver implementation.
4. Recommendation: REJECT. The player consumes `ResolvedStream` which already includes headers. If HLS signing requires runtime state, expose it through the `ResolvedStream.headers` map or a resolver-side proxy, not through a direct import.
5. Minimal next step: verify that `ResolvedStream.headers` carries the required authentication; if not, extend the resolver to include it.

## Definition of Done

- The structural question has a clear, justified recommendation.
- The recommendation is backed by evidence from actual code (not assumptions).
- Dependency direction has been validated.
- Risks are documented.
- The recommendation is actionable (not vague "consider refactoring").

## Project Assumptions

- The monorepo uses a workspace pubspec with path dependencies between packages.
- Feature-first structure under `apps/kumoriya_app/lib/src/features/` with `presentation/`, `application/`, `domain/` layers.
- Riverpod providers wire packages at the app level.
- **Risk: some packages may have undeclared transitive dependencies through barrel exports, which could mask coupling.**
- **Risk: the boundary between `kumoriya_domain` and `kumoriya_plugins` may need refinement as more plugin types are added (e.g., manga sources).**
