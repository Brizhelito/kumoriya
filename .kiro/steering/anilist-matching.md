---
inclusion: always
---

# AniList Matching (Kumoriya)

Construye matching conservador únicamente. Prefiere no-match sobre falso positivo.

## Cuándo activar este skill

Úsalo cuando:
- Estés diseñando o refinando heurísticas de matching AniList → fuente
- Implementes normalización de strings para comparación de títulos
- Definas reglas de confianza (confidence) y decisiones match/no-match
- Escribas tests de matching, incluyendo casos de rechazo obligatorio

## Restricciones absolutas

1. AniList es la fuente canónica de metadatos. Nunca al revés.
2. No auto-vincular con evidencia débil.
3. Rechazar lógica fuzzy agresiva sin guardrails claros.
4. Usar normalización determinista y decisiones explicables.
5. Si la confianza es incierta, retornar no-match.

## Bloque de scope (publicar antes de codificar)

```md
Matching Scope
- Target flow:
- In scope:
- Out of scope:
- Acceptance rule:
```

## Preparación de candidatos

1. Construir conjunto de candidatos desde registros de la fuente scrapeada.
2. Normalizar candidato y strings de AniList antes de comparar.
3. Usar solo aliases/sinónimos razonables:
   - Títulos native/romaji/english de AniList
   - Sinónimos confiables ya presentes en metadatos de AniList
4. No inventar aliases sintéticos desde transformaciones no relacionadas.

## Reglas de normalización (conservadoras)

Aplicar estos pasos en orden:
1. Unicode normalize y lowercase.
2. Trim y colapsar whitespace.
3. Remover puntuación de bajo valor semántico.
4. Normalizar separadores (`-`, `_`, `/`, `:`) a espacios donde sea seguro.
5. Evitar transformaciones destructivas que borren significado semántico.

Documentar exactamente qué operaciones de normalización están activas.

## Política de decisión heurística

Evidencia ponderada pero conservadora:

- Señal fuerte: alta similitud en título primario post-normalización
- Señal de apoyo: alineación de alias/sinónimo, acuerdo de año (si disponible), acuerdo de formato/tipo (TV, movie, OVA) cuando disponible
- Señal de rechazo: año/tipo conflictivo en near-title match, solo hit de alias débil sin soporte de título, empates ambiguos entre múltiples candidatos

Regla de decisión:
- Aceptar solo cuando existe señal fuerte y no hay conflicto material.
- De lo contrario rechazar con no-match.

## Requisitos de explicabilidad

Cada decisión debe ser auditable. Usar esta estructura:

```md
Match Decision
- AniList id/title:
- Candidate source id/title:
- Signals for acceptance:
- Signals for rejection:
- Confidence:
- Verdict: match | no-match
- Reason:
```

Confianza categórica y conservadora:
- `high`: alineación única clara, sin conflictos
- `medium`: alineación parcial; generalmente rechazar salvo política explícita
- `low`: evidencia débil/ruidosa; rechazar

## Estrategia de tests (incluir casos no-match obligatoriamente)

Tests mínimos requeridos:
1. Verdadero positivo exacto/casi-exacto con año/tipo consistente.
2. Verdadero positivo basado en alias con señales de apoyo fuertes.
3. Prevención de falso positivo por título similar (debe retornar no-match).
4. Caso de conflicto año/tipo (debe retornar no-match).
5. Empate ambiguo multi-candidato (debe retornar no-match).
6. Caso de metadatos fuente vacíos/parciales (debe retornar no-match de forma segura).

Preferir tests table-driven que enumeren:
- Input AniList
- Candidatos fuente
- Veredicto esperado
- Banda de confianza esperada
- Razón de rechazo esperada cuando no-match

## Checklist de validación

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package>
- [ ] dart test <matching tests>
```

No declarar robustez si las defensas de no-match no fueron testeadas.

## Reporte de limitaciones

Documentar siempre los límites actuales:

```md
Matching Limitations
- limitation:
- effect on verdicts:
- conservative fallback:
```

Ejemplos: año/tipo faltante en fuente, escasez de aliases en entrada AniList, títulos genéricos en franquicias.

## Plantilla de reporte final

```md
AniList Matching Report
- Scope executed:
- Heuristics implemented/changed:
- Decision policy:
- Tests added/updated:
- Validation run:
  - command:
  - result:
- False-positive defenses:
- Known limitations:
- Residual risk:
```
