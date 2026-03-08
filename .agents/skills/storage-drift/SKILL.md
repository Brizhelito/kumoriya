---
name: storage-drift
description: Implement and maintain Kumoriya local persistence with Drift under modular architecture constraints. Use when designing tables, DAOs, repositories, cache-vs-durable storage boundaries, migration plans, Riverpod integration seams, and storage-focused tests for favorites, history, progress, settings, and offline/cache data without leaking UI models into storage.
---

# Storage Drift (Kumoriya)

Implement Drift persistence as a modular storage layer, not as UI state storage.

## Hard boundaries first

1. Respect `AGENTS.md` architecture and package boundaries.
2. Keep storage separate from UI models and widgets.
3. Expose storage through repositories/contracts, not direct UI table access.
4. Keep domain/application decoupled from Drift specifics where practical.
5. Scope changes by vertical slice; avoid broad storage rewrites.

## Scope lock before implementation

Publish this block before coding:

```md
Storage Slice Scope
- Request:
- Data domains in scope:
- In scope:
- Out of scope:
- Done when:
```

Data domains usually include favorites, history, progress, cache, settings, offline.

## Data classification: durable vs cache

Classify each entity before schema work.

1. Durable data:
   - user intent/state that must survive cleanup/restarts
   - examples: favorites, watch progress, settings, core history
2. Cache/ephemeral data:
   - re-fetchable remote data with TTL/invalidation
   - examples: source listing cache, transient metadata cache
3. Define invalidation policy for cache tables (TTL/version/source key).

Output:

```md
Storage Classification
- entity:
- type: durable | cache
- retention/invalidation:
- rationale:
```

## Schema and DAO/repository design

1. Design normalized tables with explicit primary keys and relevant indexes.
2. Use clear column semantics and constraints (nullable only when intentional).
3. Keep DAO focused on query operations and mapping to storage DTOs.
4. Keep repository layer responsible for domain-facing abstractions.
5. Avoid leaking Drift generated classes above repository boundary.

Output:

```md
Schema Plan
- table:
- key/indexes:
- used by DAO:
- exposed via repository:
```

## Migration strategy (sustainable)

1. Treat migration as first-class work for every schema change.
2. Plan forward-only migrations with explicit version steps.
3. Backfill defaults for new non-null columns.
4. Add migration tests for critical version jumps.
5. Document data-loss risks explicitly when unavoidable.

Output:

```md
Migration Plan
- from -> to:
- schema changes:
- data transform/backfill:
- rollback note:
- risk:
```

## Riverpod integration without over-coupling

1. Provide storage/repository via Riverpod providers at infrastructure boundary.
2. Keep providers thin; avoid embedding SQL/query details in app/UI layers.
3. Expose use-case friendly methods/streams from repositories.
4. Keep lifecycle/disposal explicit for database instances.
5. Avoid global singletons that bypass dependency injection.

## Platform considerations (Android first, Windows second)

1. Use file/location strategy compatible with Android and Windows.
2. Keep path/bootstrap concerns isolated from schema/query logic.
3. Validate at least basic open/init behavior for both targets when touched.

## Testing expectations

Cover storage behavior with practical tests.

Minimum tests:
1. DAO insert/read/update/delete for touched tables.
2. Query behavior for key flows (favorites, progress, history ordering).
3. Cache invalidation/TTL behavior.
4. Repository mapping test (storage DTO -> domain model).
5. Migration test for touched schema versions.

Prefer in-memory or temporary DB tests where possible.

## Validation checklist

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package or repo rule>
- [ ] dart test <storage-related tests>
- [ ] run/build check if startup/bootstrap/storage init wiring changed
```

Do not claim storage stability without migration and query validation evidence.

## Decision and limit logging

Always document what was chosen and why.

```md
Storage Decisions
- decision:
- alternatives considered:
- tradeoff:
```

```md
Storage Limitations
- limitation:
- impact:
- mitigation/fallback:
```

## Final report template

```md
Storage Drift Report
- Scope executed:
- Tables/DAOs/repositories touched:
- Durable vs cache decisions:
- Migration changes:
- Riverpod integration changes:
- Tests run:
  - command:
  - result:
- Known limitations:
- Residual risk:
```
