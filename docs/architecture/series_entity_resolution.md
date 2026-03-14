# 1. Resumen ejecutivo

Se implemento una libreria pura `kumoriya_matching` para record linkage interpretable entre AniList y multiples sources. La arquitectura separa normalizacion, blocking, scoring hibrido, policy de decision y canonical mapping alrededor de `CanonicalSeries`, dejando el flujo actual del app como un adapter y evitando comparaciones globales `O(n²)`.

# 2. Arquitectura propuesta

Capas:

- Ingesta: `SourceSeriesRecord` y `CanonicalSeries`.
- Normalizacion: `SeriesFingerprintBuilder`.
- Candidate generation / blocking: `SeriesCandidateIndex`.
- Scoring: `HybridSeriesScorer`.
- Decision policy: `SeriesEntityResolver`.
- Canonical mapping: `CanonicalMappingEngine`.

AniList sigue siendo la metadata canonica. Las sources solo se vinculan a traves de `CanonicalSeries`.

# 3. Modelo de datos

- `CanonicalSeries`: representa la entidad canonica y agrupa `CanonicalSourceBinding`.
- `SourceSeriesRecord`: encapsula provider, id externo, titulo, aliases, anio, tipo, episodios y season info.
- `SeriesSeasonInfo`: modela season/part/cour/final season.
- `MatchReason`: razon estructurada e interpretable.
- `SeriesMatchDecision`: contiene veredicto, score y shortlist de candidatos.

# 4. Pipeline detallado

1. Ingerir metadata canonica AniList y records de sources.
2. Normalizar todos los titulos y aliases en fingerprints reproducibles.
3. Generar blocking keys exact/root/token/year/season.
4. Resolver candidatos via indice por key.
5. Calcular score hibrido solo sobre el bloque recuperado.
6. Aplicar decision policy `auto_match`, `review_needed`, `reject`.
7. Persistir o exponer el binding canonico y la explicacion.

# 5. Algoritmo de scoring

El score mezcla:

- token set similarity
- token sort similarity
- Jaro-Winkler
- trigram similarity
- alias overlap
- year closeness
- type match
- season/part consistency
- episode consistency

Ademas aplica bonuses discretos por alias exacto, titulo exacto y raiz compartida, y penalties por metadata dispersa o conflictos.

# 6. Reglas heuristicas del dominio

- Preferir no-match ante ties o metadata insuficiente.
- No auto-linkear cuando hay conflicto fuerte de season/part.
- Reboots con mismo titulo pero anio distante caen a review o reject.
- Entradas agrupadas por franquicia/temporada reciben bonus controlado, no auto-aceptacion ciega.

# 7. Estrategia de performance

- Fingerprints precomputables.
- Candidate generation basado en blocking keys, no full scan global.
- Recalculo incremental por overlap de blocking keys.
- Pesos y thresholds externos al algoritmo para recalibracion sin reescritura.

# 8. Estrategia de calidad y evaluacion

- Tests unitarios sobre true positives, false positives, ambiguities y grouped entries.
- Razones estructuradas auditan cada decision.
- Scores top-3 disponibles para revision manual.
- Thresholds permiten tuning offline con datasets etiquetados.

# 9. Casos de prueba

- Alias exacto con metadata consistente.
- Falso positivo de secuela con overlap parcial.
- Empate exacto que debe ir a review.
- Catalog entry agrupada sin season explicita.
- Plan incremental de recalculo.

# 10. Implementacion completa

Archivos principales:

- `packages/kumoriya_matching/lib/src/normalization/series_fingerprint_builder.dart`
- `packages/kumoriya_matching/lib/src/blocking/series_candidate_index.dart`
- `packages/kumoriya_matching/lib/src/scoring/hybrid_series_scorer.dart`
- `packages/kumoriya_matching/lib/src/pipeline/series_entity_resolver.dart`
- `packages/kumoriya_matching/lib/src/pipeline/canonical_mapping_engine.dart`

# 11. Riesgos y mejoras futuras

- Algunas sources hoy no entregan aliases o episode count; el motor ya tolera faltantes, pero mejora cuando las plugins llenen esos campos.
- Falta persistencia dedicada para cola manual de review.
- El modelo puede endurecerse con datasets etiquetados, calibracion ROC/PR y señales de relacion AniList prequel/sequel/spin-off.
