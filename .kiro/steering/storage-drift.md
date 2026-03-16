---
inclusion: always
---

# Storage Drift (Kumoriya)

Drift es la capa de persistencia local de Kumoriya. Toda interacción con la base de datos ocurre a través de DAOs y repositorios — nunca directamente desde UI o providers de presentación.

## Restricciones absolutas

1. Storage separado de modelos UI y widgets. Las clases generadas por Drift no cruzan el boundary del repositorio.
2. Exponer storage únicamente a través de repositorios con contratos domain-facing.
3. Domain y application no dependen de tipos específicos de Drift.
4. Cambios por vertical slice; no rewrites amplios de storage.
5. Riverpod provee el repositorio en el boundary de infraestructura — providers thin, sin SQL embebido en capas app/UI.

## Bloque de scope (publicar antes de codificar)

```md
Storage Slice Scope
- Request:
- Data domains in scope:
- In scope:
- Out of scope:
- Done when:
```

Dominios de datos habituales: favorites, history, progress, cache, settings, offline.

## Clasificación de datos: durable vs cache

```md
Storage Classification
- entity:
- type: durable | cache
- retention/invalidation:
- rationale:
```

- Durable: intención/estado del usuario que debe sobrevivir cleanup/reinicios (favorites, watch progress, settings, core history).
- Cache/ephemeral: datos remotos re-fetchables con TTL/invalidación (source listing cache, transient metadata cache).
- Definir política de invalidación para tablas cache (TTL/version/source key).

## Diseño de schema y DAO/repositorio

```md
Schema Plan
- table:
- key/indexes:
- used by DAO:
- exposed via repository:
```

1. Diseñar tablas normalizadas con primary keys explícitas e índices relevantes.
2. Usar semántica de columnas clara y constraints (nullable solo cuando sea intencional).
3. DAO enfocado en operaciones de query y mapping a storage DTOs.
4. Capa de repositorio responsable de abstracciones domain-facing.

## Estrategia de migración (sostenible)

```md
Migration Plan
- from -> to:
- schema changes:
- data transform/backfill:
- rollback note:
- risk:
```

1. Tratar migración como trabajo de primera clase para cada cambio de schema.
2. Planificar migraciones forward-only con pasos de versión explícitos.
3. Backfill defaults para nuevas columnas non-null.
4. Agregar tests de migración para saltos de versión críticos.
5. Documentar riesgos de pérdida de datos explícitamente cuando sean inevitables.

## Integración Riverpod sin over-coupling

1. Proveer storage/repositorio vía Riverpod providers en el boundary de infraestructura.
2. Mantener providers thin; evitar embeber detalles SQL/query en capas app/UI.
3. Exponer métodos/streams use-case friendly desde repositorios.
4. Mantener lifecycle/disposal explícito para instancias de base de datos.
5. Evitar singletons globales que bypaseen dependency injection.

## Consideraciones de plataforma (Android first, Windows second)

1. Usar estrategia de file/location compatible con Android y Windows.
2. Mantener concerns de path/bootstrap aislados de lógica de schema/query.
3. Validar al menos comportamiento básico de open/init para ambos targets cuando se toquen.

## Tests mínimos requeridos

1. DAO insert/read/update/delete para tablas tocadas.
2. Comportamiento de query para flujos clave (favorites, progress, history ordering).
3. Comportamiento de invalidación/TTL de cache.
4. Test de mapping de repositorio (storage DTO → domain model).
5. Test de migración para versiones de schema tocadas.

Preferir tests con DB in-memory o temporal donde sea posible.

## Checklist de validación

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package or repo rule>
- [ ] dart test <storage-related tests>
- [ ] run/build check if startup/bootstrap/storage init wiring changed
```

No declarar estabilidad de storage sin evidencia de validación de migración y queries.

## Logging de decisiones y limitaciones

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

## Plantilla de reporte final

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
