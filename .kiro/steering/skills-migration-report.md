---
inclusion: manual
---

# Skills Migration Report: Codex → Kiro Native

## Sistema destino

Kiro usa steering files en `.kiro/steering/*.md` con frontmatter YAML.
Modos de inclusión disponibles:
- `inclusion: auto` — incluido en todo contexto
- `inclusion: fileMatch` + `fileMatchPattern` — incluido cuando ciertos archivos están en contexto
- `inclusion: manual` — activado explícitamente por el usuario con `#nombre-skill` en el chat

Todos los skills fueron adaptados con `inclusion: always`, que es el equivalente funcional a la activación automática de Codex — los skills se aplican en todo contexto sin invocación explícita.

---

## Tabla de adaptación por skill

| Skill origen | Artefacto creado | Estado |
|---|---|---|
| anilist-matching | `.kiro/steering/anilist-matching.md` | Adaptado |
| flutter-vertical-slice | `.kiro/steering/flutter-vertical-slice.md` | Adaptado |
| kumoriya-architecture | `.kiro/steering/kumoriya-architecture.md` | Adaptado |
| player-slice | `.kiro/steering/player-slice.md` | Adaptado |
| resolver-plugin | `.kiro/steering/resolver-plugin.md` | Adaptado |
| resolver-runtime-audit | `.kiro/steering/resolver-runtime-audit.md` | Adaptado |
| source-plugin-jkanime | `.kiro/steering/source-plugin-jkanime.md` | Adaptado |
| storage-drift | `.kiro/steering/storage-drift.md` | Adaptado |
| uiux-review | `.kiro/steering/uiux-review.md` | Adaptado |
| validate-task | `.kiro/steering/validate-task.md` | Adaptado |

---

## Detalle por skill

### anilist-matching
- Conservado: propósito, restricciones absolutas, bloque de scope, reglas de normalización, política de decisión heurística, requisitos de explicabilidad, estrategia de tests, checklist de validación, reporte de limitaciones, plantilla de reporte final.
- Adaptado: frontmatter Codex (`name`, `description`) convertido a frontmatter Kiro (`inclusion: manual`). Sección "Cuándo activar" añadida explícitamente como guía de activación nativa.
- Omitido: `agents/openai.yaml` — el `display_name` y `default_prompt` no tienen equivalente directo en Kiro steering; la intención queda cubierta por la sección "Cuándo activar" y el título del archivo.

### flutter-vertical-slice
- Conservado: restricciones, bloque de scope, mapeo de paquetes/capas, plan incremental, disciplina de targeting de archivos, checklist de validación, versionado por milestones, plantilla de reporte.
- Adaptado: referencia a `AGENTS.md` convertida en regla operativa real ("Leer y respetar los non-negotiables del proyecto").
- Omitido: `agents/openai.yaml` — misma razón que arriba.

### kumoriya-architecture
- Conservado: todas las restricciones arquitectónicas, checklist de revisión, separación de responsabilidades por capa, reglas plugin-first, output esperado.
- Adaptado: skill fuente era muy conciso; se expandió con la tabla de capas y dirección de dependencias para hacerlo operativamente útil como steering file.
- Omitido: nada con pérdida de intención.

### player-slice
- Conservado: restricciones de boundary, bloque de scope, diseño de sesión/orquestador, responsabilidades del player, política de errores/fallback, integración de progreso, tests mínimos, checklist de validación, plantillas de reporte y decisiones/riesgos.
- Adaptado: referencias a `AGENTS.md` convertidas en reglas operativas. Sección "Cuándo activar" añadida.
- Omitido: `agents/openai.yaml`.

### resolver-plugin
- Conservado: restricciones de boundary, bloque de scope, implementación contract-first, política de hosts, normalización de URL, hardening de parsing, errores/retries/timeouts, política de fixtures, tests mínimos, checklist, documentación de riesgos, plantilla de reporte.
- Adaptado: referencias a `AGENTS.md` convertidas en reglas operativas.
- Omitido: `agents/openai.yaml`.

### resolver-runtime-audit
- Conservado: reglas de auditoría no-negociables, bloque de scope, flujo completo de 7 pasos (inventario estático, decisión runtime, captura de evidencia, comparación, matriz de causa raíz, plan de fix priorizado, validación), plantilla de reporte final.
- Adaptado: referencias a `AGENTS.md` convertidas en restricciones absolutas del skill.
- Omitido: `agents/openai.yaml`.

### source-plugin-jkanime
- Conservado: restricciones, bloque de scope, revisión de contratos, scraping robusto/parsing defensivo, política de fixtures, tests requeridos, checklist de validación, logging de limitaciones, plantilla de reporte.
- Adaptado: referencias a `AGENTS.md` convertidas en reglas operativas.
- Omitido: `agents/openai.yaml`.

### storage-drift
- Conservado: restricciones de boundary, bloque de scope, clasificación durable vs cache, diseño de schema/DAO/repositorio, estrategia de migración, integración Riverpod, consideraciones de plataforma, tests mínimos, checklist, logging de decisiones/limitaciones, plantilla de reporte.
- Adaptado: referencias a `AGENTS.md` convertidas en reglas operativas.
- Omitido: `agents/openai.yaml`.

### uiux-review
- Conservado: misión, restricciones de boundary, flujo de auditoría, reglas de contexto Kumoriya, checks requeridos por pantalla, estándares de calidad de estados, reglas de UX defensiva, contrato de output. El contenido de `references/uiux-audit-checklist.md` fue integrado directamente como checklist rápida dentro del steering file.
- Adaptado: checklist de referencia externa incorporada al steering file (Kiro no tiene sistema de referencias externas en steering). Sección "Cuándo activar" añadida.
- Omitido: `agents/openai.yaml`. El archivo `references/uiux-audit-checklist.md` como archivo separado — su contenido fue absorbido directamente.

### validate-task
- Conservado: checklist de cierre, reglas de no-completitud, formato de output obligatorio.
- Adaptado: skill fuente era muy conciso; se expandió con sección "Cuándo activar" y reglas de no-completitud explícitas para hacerlo más operativo como steering file.
- Omitido: nada con pérdida de intención.

---

## Tabla de compatibilidad

| Capacidad Codex | Equivalente Kiro | Tipo de mapeo |
|---|---|---|
| Frontmatter `name` + `description` | Título H1 del steering file + sección "Cuándo activar" | Mapeo aproximado |
| Invocación explícita `$skill-name` | `inclusion: always` (activo en todo contexto, igual que Codex) | Mapeo 1:1 |
| Secciones de instrucciones operativas | Secciones markdown del steering file | Mapeo 1:1 |
| Bloques de scope/output como plantillas | Bloques de código markdown en steering file | Mapeo 1:1 |
| Checklists de validación | Checklists markdown en steering file | Mapeo 1:1 |
| Plantillas de reporte final | Bloques markdown en steering file | Mapeo 1:1 |
| Referencias a `AGENTS.md` como texto | Reglas operativas reales dentro del skill | Mapeo aproximado |
| `agents/openai.yaml` (display_name, default_prompt) | Sección "Cuándo activar" + título del archivo | Mapeo aproximado |
| Archivo de referencia externo (`uiux-audit-checklist.md`) | Contenido integrado directamente en el steering file | Mapeo aproximado |
| Inclusión condicional por fileMatch | `inclusion: fileMatch` + `fileMatchPattern` (disponible, no usado) | No usado (manual es más apropiado para skills) |
| Composición/dependencias entre skills | No implementado — Kiro steering no tiene dependencias entre archivos | No soportado |
| Activación automática por evento | `inclusion: auto` o `fileMatch` (disponible pero no apropiado para estos skills) | No usado intencionalmente |

---

## Notas de decisión

- `inclusion: manual` fue elegido para todos los skills porque refleja la intención de invocación explícita de Codex. Los skills son herramientas especializadas, no contexto global permanente.
- La composición entre skills (ej. `flutter-vertical-slice` que podría invocar `validate-task`) no fue implementada porque Kiro steering no soporta dependencias entre archivos. La intención se preserva documentando en cada skill cuándo activar `#validate-task` al cierre.
- Los `openai.yaml` no tienen equivalente directo en Kiro. Su intención (nombre visible, prompt por defecto) queda cubierta por el título del steering file y la sección "Cuándo activar".
