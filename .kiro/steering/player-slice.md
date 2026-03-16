---
inclusion: always
---

# Player Slice (Kumoriya)

Construye slices de player con media_kit. Consume inputs ya resueltos, no resuelve links.

## Cuándo activar este skill

Úsalo cuando:
- Implementes o endurezcas flujos de sesión/orquestador del player
- Trabajes en controles, switching de servidor/calidad, progreso/resume
- Definas comportamiento de fallback y estados de error del player
- Valides UX mínima del player con inputs de playback pre-resueltos

## Restricciones absolutas

1. Mantener el player separado de source scraping y resolver plugins.
2. Requerir candidatos de playback pre-resueltos antes de que comience la orquestación del player.
3. No agregar lógica de resolver/scraper en UI/providers/controllers del player.
4. Mantener slices estrechos y entregables verticalmente.
5. Si las precondiciones faltan, agregar un seam/typed error y detenerse antes de lógica de resolución falsa.

## Bloque de scope (publicar antes de codificar)

```md
Player Slice Scope
- Request:
- In scope:
- Out of scope (must include scraping/resolution):
- Preconditions (resolved pipeline input):
- Done when:
```

## Diseño de sesión y orquestador

```md
Player Architecture Slice
- orchestrator/session responsibilities:
- media_kit boundary:
- UI boundary:
- external dependencies:
```

El orquestador/sesión posee:
- Candidato fuente activo (ya resuelto)
- Selección de servidor y calidad activos
- Estado del ciclo de vida de playback

UI consumers son thin: watch provider/state, dispatch actions. Interacción con media_kit centralizada en orquestador/service layer.

## Responsabilidades del player (solo estas)

1. Ciclo de vida: load, play, pause, seek, stop.
2. Controles: transport, duration/progress indicators, mute/volume.
3. Server switch: mover a otro candidato de servidor pre-resuelto de forma segura.
4. Quality switch: elegir otra variante de calidad pre-resuelta.
5. Progress/resume: persistir y restaurar posición del playhead con guardrails.
6. Fallback básico: intentar siguiente candidato/calidad/servidor según política explícita.

## Política de errores y fallback

```md
Player Error Policy
- error type:
- retry/fallback behavior:
- terminal condition:
- user-visible state:
```

1. Distinguir: precondición inválida, fallo de carga/playback, fallo de switch, timeout/stall.
2. Definir orden de fallback determinísticamente.
3. Limitar intentos de fallback y exponer estado de fallo final.
4. Estados de error visibles al usuario: mínimos y claros.

## Integración de progreso e historial

1. Persistir progreso periódicamente y en eventos clave del ciclo de vida.
2. Resumir solo cuando el progreso guardado supera umbral mínimo y está por debajo del umbral near-end.
3. Escribir historial/progreso a través de contratos application/storage, no directamente en widgets UI.
4. Evitar escrituras duplicadas en ticks frecuentes de posición (throttle/debounce o política de checkpoint).

## Tests mínimos requeridos

1. Tests de transición de estado del orquestador.
2. Tests de política de fallback (success path + exhausted path).
3. Tests de lógica progress/resume.
4. Tests de switching de servidor/calidad.
5. Test de sanidad a nivel widget para controles críticos (si el paquete usa widget tests).

Usar fakes/mocks para output de resolver y adaptadores de media_kit.

## Checklist de validación

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package or repo rule>
- [ ] dart test <player-related tests>
- [ ] run/build check for player flow when wiring/startup/navigation changed
```

No marcar slice como completo sin validación ejecutada.

## Plantilla de reporte final

```md
Player Slice Report
- Scope executed:
- Session/orchestrator changes:
- Controls/server/quality changes:
- Progress/history integration changes:
- Error/fallback behavior:
- Tests run:
  - command:
  - result:
- Known risks/limitations:
- Residual risk:
```
