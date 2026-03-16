---
name: storage-drift
description: >-
  This skill should be used when implementing or maintaining local persistence
  with Drift in Kumoriya. Covers table design, DAOs, repositories, cache vs
  durable data classification, migration planning, Riverpod integration, and
  storage-focused tests. Triggers on mentions of Drift, database, tables, DAOs,
  migrations, AppDatabase, kumoriya_storage, favorites persistence, watch
  history, progress storage, offline cache, or local data layer in Kumoriya.
---

# storage-drift

## Purpose

Implement and maintain the Drift-based local persistence layer in `packages/kumoriya_storage/`. This skill covers table design, DAO implementation, repository contracts, data classification (durable vs cache), migration strategy, Riverpod integration, and storage-specific testing. Storage is a separate architectural concern: it does not leak Drift-generated classes into UI or domain layers, and it does not store UI view models.

## Use When

- Designing new database tables for a feature (favorites, history, progress, settings, offline cache).
- Implementing or modifying DAOs (data access objects) for query operations.
- Creating or updating repository implementations that bridge storage and domain.
- Planning or implementing schema migrations.
- Integrating storage providers into Riverpod DI.
- Writing storage-focused tests (insert/read/update/delete, query behavior, migration).
- Classifying data as durable vs cache and defining retention/invalidation policies.

## Do Not Use When

- Working on UI components (use `uiux-review` or `flutter-vertical-slice`).
- Working on matching logic (use `anilist-matching`).
- Working on player features (use `player-slice`).
- Working on resolver/source plugins (use `resolver-plugin`, `source-plugin-jkanime`).
- Making package-level architecture decisions (use `kumoriya-architecture`).
- The change is purely a domain model change with no storage impact.

## What This Skill Does

1. Classifies every persisted entity as **durable** (survives cleanup, user-intent data) or **cache** (re-fetchable, TTL-based invalidation).
2. Designs normalized tables with explicit primary keys, indexes, and nullable-only-when-intentional columns.
3. Implements DAOs focused on query operations and mapping to storage DTOs.
4. Implements repositories that expose domain-facing abstractions, never Drift-generated classes.
5. Plans forward-only migrations with explicit version steps, backfill defaults for new non-null columns, and data-loss risk documentation.
6. Integrates storage into Riverpod with thin providers at the infrastructure boundary.
7. Validates schema changes with migration tests.
8. Keeps platform-specific concerns (file paths, database location) isolated from schema/query logic.
9. Tests DAO operations, query behavior, repository mapping, and cache invalidation.
10. Documents storage decisions, tradeoffs, and compatibility risks.

## Required Inputs

- Access to `packages/kumoriya_storage/`.
- Knowledge of `AppDatabase` class and existing table definitions.
- Knowledge of existing DAOs and repository patterns.
- Knowledge of domain models in `packages/kumoriya_domain/` that storage maps to/from.
- Knowledge of Riverpod provider patterns used in the app.
- The feature or data domain being persisted (favorites, history, progress, settings, cache).

## Preconditions

- `packages/kumoriya_storage/` compiles.
- Existing storage tests pass.
- The agent has read the current `AppDatabase` definition and relevant DAOs before modifying them.
- The agent understands the current schema version.

## Procedure

1. **Publish scope lock.**
   ```
   Storage Slice Scope
   - Request: [what to implement/fix]
   - Data domains: [favorites/history/progress/cache/settings/offline]
   - In scope: [tables, DAOs, repos, migrations]
   - Out of scope: [UI, domain models, plugins]
   - Done when: [acceptance criteria]
   ```

2. **Classify the data.**
   ```
   Storage Classification
   - Entity: [name]
   - Type: durable | cache
   - Retention/invalidation: [policy]
   - Rationale: [why this classification]
   ```

   Durable examples: favorites, watch progress, user settings, core watch history.
   Cache examples: source catalog listings, transient metadata, search result cache.

3. **Design schema.**
   - Define table with explicit primary key and relevant indexes.
   - Use clear column names and types. Nullable only when the data is genuinely optional.
   - For cache tables, include TTL or version columns for invalidation.
   ```
   Schema Plan
   - Table: [name]
   - Columns: [list with types]
   - Primary key: [column(s)]
   - Indexes: [column(s) + reason]
   - Used by DAO: [name]
   - Exposed via repository: [name]
   ```

4. **Implement DAO.**
   - Query operations: insert, read (by key, by filter, ordered), update, delete.
   - Map between Drift-generated row classes and storage DTOs.
   - Keep DAO focused on data operations, no business logic.

5. **Implement repository.**
   - Expose domain-facing methods (e.g., `getFavorites()`, `saveProgress()`).
   - Map storage DTOs to domain models from `kumoriya_domain`.
   - Never expose Drift-generated classes above the repository boundary.

6. **Plan migration (if schema changed).**
   ```
   Migration Plan
   - From version: [N]
   - To version: [N+1]
   - Schema changes: [added/modified/removed columns/tables]
   - Data transform/backfill: [defaults for new non-null columns]
   - Rollback note: [forward-only, document impact]
   - Risk: [data loss potential]
   ```

7. **Integrate with Riverpod.**
   - Provide database and repositories via Riverpod providers.
   - Keep providers thin: no SQL or query logic in providers.
   - Expose use-case-friendly methods and streams from repositories.
   - Keep database lifecycle (init, dispose) explicit.

8. **Write tests.**
   - DAO: insert/read/update/delete for touched tables.
   - Query behavior: ordering, filtering, pagination for key flows.
   - Cache: invalidation/TTL behavior.
   - Repository: storage DTO to domain model mapping.
   - Migration: test schema version transitions (at minimum, fresh DB + one migration hop).
   - Use in-memory or temporary database for tests.

9. **Run validation.**
   ```
   dart format packages/kumoriya_storage/
   dart analyze packages/kumoriya_storage/
   dart test packages/kumoriya_storage/
   ```
   If startup/bootstrap wiring changed, run a build check.

10. **Report.**
    ```
    Storage Drift Report
    - Scope executed: [recap]
    - Tables/DAOs/repositories: [touched]
    - Classification: [durable vs cache decisions]
    - Migration: [version changes]
    - Riverpod integration: [changes]
    - Tests: [commands + results]
    - Limitations: [documented]
    - Residual risk: [honest assessment]
    ```

## Required Checks

- [ ] `dart format` passes on storage package.
- [ ] `dart analyze` reports no issues.
- [ ] All storage tests pass.
- [ ] No Drift-generated class is imported outside the storage package.
- [ ] New tables have explicit primary keys and relevant indexes.
- [ ] New non-null columns have migration backfill defaults.
- [ ] Cache tables have invalidation policy defined.
- [ ] Repository methods return domain models, not Drift row types.

## Expected Outputs

- Table definitions, DAOs, and repositories.
- Migration code (if schema changed).
- Riverpod provider wiring (if new repository added).
- Tests for DAO operations, queries, mapping, and migration.
- Data classification documentation.
- Validation evidence.

## Anti-Patterns

- **Leaking Drift types.** Never export Drift-generated row classes outside `kumoriya_storage`.
- **Storing UI models.** Storage persists domain data, not view state or widget configuration.
- **Skipping migrations.** Never modify a table schema without a versioned migration step.
- **Global singletons.** Always provide database instances through Riverpod, not static globals.
- **Business logic in DAOs.** DAOs execute queries; business rules live in application/domain layer.
- **Unbounded cache.** Cache tables without TTL or invalidation grow indefinitely.
- **Nullable-by-default.** Make columns nullable only when the data is genuinely optional; use defaults otherwise.
- **Testing only happy path.** Include tests for empty results, duplicate key conflicts, and migration edge cases.

## Constraints

- Storage lives in `packages/kumoriya_storage/`. It does not import app, UI, or plugin packages.
- Domain models live in `packages/kumoriya_domain/`. Storage maps to/from them but does not own them.
- Riverpod is the DI framework. Database and repository providers live at the infrastructure boundary.
- `Result<T, KumoriyaError>` at repository boundaries when errors are possible.
- Migrations are forward-only. Document data-loss risks explicitly.
- Android-first platform target with Windows support. Database file location must work on both.

## Minimal Example

Task: "Add persistence for anime watch progress (episode number, position in seconds, timestamp)."

1. Scope: add `watch_progress` table, DAO, repository, migration. In scope: storage. Out of scope: UI, player (consumes via repository contract).
2. Classify: durable (user intent to resume, survives cleanup).
3. Schema: `watch_progress(anime_id TEXT PK, episode_number REAL, position_seconds INTEGER, updated_at INTEGER)`.
4. DAO: `upsertProgress()`, `getProgress(animeId)`, `deleteProgress(animeId)`.
5. Repository: `WatchProgressRepository` exposing `saveProgress(AnimeProgress)`, `getProgress(String animeId) -> AnimeProgress?`.
6. Migration: version N -> N+1, create table `watch_progress`.
7. Test: insert + read, upsert overwrites, delete removes, empty result returns null.
8. Validate: format, analyze, test.

## Definition of Done

- Tables, DAOs, and repositories are implemented and tested.
- Migration is versioned and tested.
- No Drift types leak outside storage package.
- Validation passes.
- Data classification is documented.

## Project Assumptions

- `AppDatabase` in `packages/kumoriya_storage/` is the single Drift database instance.
- Drift code generation is used (`drift_dev` and `build_runner`). Schema changes require re-running code generation.
- **Risk: Drift code generation may produce compilation errors if table definitions conflict. Always re-run `dart run build_runner build` after schema changes.**
- Database location defaults are handled by platform-specific bootstrap code.
- **Risk: migration testing on Windows may not catch Android-specific path issues. Note this as a residual risk when relevant.**
