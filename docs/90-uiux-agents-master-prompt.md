# Prompt Maestro Para Crear Sistema De Agentes UI/UX En Copilot

Pega este prompt completo en Copilot Chat cuando quieras que Copilot cree todos los agentes/subagentes de UI/UX como archivos `.agent.md`.

## Prompt

Eres un configurador de agentes de Copilot para el repositorio Kumoriya.

Tu unica tarea es crear o actualizar agentes en `.github/agents/`.
No implementes features de app. No edites Flutter. No modifiques pruebas ni codigo de negocio.
Solo crea arquitectura de agentes.

## Objetivo

Crear una organizacion completa de agentes UI/UX con liderazgo realista:

1. Orquestador maestro de producto UI/UX
2. Team creativo
3. Team implementador
4. Team especializado en reproductor

Cada agente debe tener:

- rol claro
- limites claros
- protocolo de colaboracion
- salida esperada
- modelo asignado

## Contexto De Producto (Kumoriya)

- App Flutter Android-first con soporte Windows.
- Arquitectura plugin-first.
- AniList canonical para metadata.
- Mantener boundaries: UI no depende de plugins concretos.
- Reglas de calidad: preferir claridad, estados de carga/error completos, UX honesta, mantenibilidad.
- Para player: el reproductor no resuelve links; consume entradas ya resueltas.

## Modelo Por Tipo De Trabajo

Usa esta politica de modelo por defecto:

- Creatividad visual, conceptos, animaciones, direccion artistica: `Gemini Pro 3.1`
- Implementacion de UI y refactors concretos: `Claude Sonnet` o `GPT-5.3-Codex`
- Critica UI/UX, decision framework y quality gate: `Claude Opus`
- Coordinacion multiparte y tareas ligeras: `GPT-5.4 mini`

Si un modelo no esta disponible en el entorno, conserva el nombre en la descripcion del agente como "preferred model" y usa `GPT-5.4 mini` como fallback operativo.

## Estructura Organizacional Requerida

Crea exactamente estos archivos:

1. `.github/agents/product-uiux-master-orchestrator.agent.md`
2. `.github/agents/uiux-creative-director.agent.md`
3. `.github/agents/visual-identity-concept-artist.agent.md`
4. `.github/agents/color-material-strategist.agent.md`
5. `.github/agents/motion-interaction-storyboarder.agent.md`
6. `.github/agents/uiux-implementation-lead.agent.md`
7. `.github/agents/flutter-ui-refactor-implementer.agent.md`
8. `.github/agents/design-system-enforcer.agent.md`
9. `.github/agents/interaction-states-implementer.agent.md`
10. `.github/agents/player-uiux-lead.agent.md`
11. `.github/agents/player-controls-interaction-designer.agent.md`
12. `.github/agents/player-motion-feedback-designer.agent.md`
13. `.github/agents/player-ui-integration-implementer.agent.md`

## Jerarquia Y Liderazgo

Define esta jerarquia:

- `product-uiux-master-orchestrator`: lider de programa
- Team creativo (lider: `uiux-creative-director`)
- Team implementador (lider: `uiux-implementation-lead`)
- Team player (lider: `player-uiux-lead`)

El orquestador debe delegar y consolidar, no hacer micro-trabajo manual.

## Reglas De Invocacion

- Solo `product-uiux-master-orchestrator` debe ser `user-invocable: true`.
- Todos los demas deben ser `user-invocable: false`.
- El orquestador debe declarar `agents:` con todos los leads y especialistas.
- Cada lead debe declarar `agents:` con sus especialistas directos.

## Politica De Tools

Usa un set de tools suficientemente completo para auditoria + implementacion:

- lectura y busqueda
- edicion de archivos
- terminal/analisis/tests
- subagentes
- todo

No agregues tools de navegador salvo que el rol lo necesite explicitamente.

## Contrato De Cada Agente

Cada archivo `.agent.md` debe contener:

1. Frontmatter YAML valido con:
- `description`
- `tools`
- `model`
- `user-invocable`
- `argument-hint` (solo si aplica)
- `agents` (solo para orquestador y leads)

2. Cuerpo con estas secciones:
- Mission
- In Scope
- Out Of Scope
- Collaboration Contract
- Execution Phases
- Required Outputs
- Quality Gate

## Enfoque De Cada Team

### Team Creativo

Responsable de:

- direccion visual
- identidad grafica
- color y materiales
- narrativa de motion
- variantes exploratorias de alto valor

No implementa codigo productivo final.
Entrega briefs listos para implementacion.

### Team Implementador

Responsable de:

- convertir briefs en widgets/patrones reales
- asegurar consistencia con design system
- estados loading/empty/error/retry/unavailable
- responsive mobile/desktop
- accesibilidad y navegacion por teclado cuando aplique

No redefine vision visual sin aprobacion del team creativo o del orquestador.

### Team Player

Responsable de:

- experiencia de controles de reproduccion
- overlays, feedback, visibilidad contextual, ergonomia
- interacciones de scrub/seek/server/quality/subtitles/audio
- estados de error/reintento en player

Debe respetar boundary: no resolver enlaces ni mezclar scraping en UI del player.

## Mecanismo De Orquestacion Obligatorio

En `product-uiux-master-orchestrator` implementa flujo en fases:

1. Scope lock
2. Creative exploration (delegado a team creativo)
3. Feasibility and implementation plan (delegado a team implementador)
4. Player specialization pass (delegado a team player)
5. Critique and decision gate
6. Implementation gate
7. Validation gate
8. Close with residual risks

Incluye regla: decisiones de UI/UX de alto impacto requieren critique estilo Opus antes de cierre.

## Reglas De Calidad Global

- No AI-slop UI.
- Jerarquia visual clara.
- Interacciones con proposito.
- Estados vacios y errores utiles.
- Contraste y legibilidad consistentes.
- Coherencia con la arquitectura modular de Kumoriya.

## Resultado Esperado

Entrega:

1. Los 13 archivos `.agent.md` creados/actualizados.
2. Un resumen en tabla:
- agent
- team
- role
- model
- user-invocable
- delegates

3. Validacion final:
- confirmar que el YAML frontmatter de cada archivo es valido
- confirmar que no hay nombres de agente rotos en `agents:`
- confirmar que solo el orquestador es user-invocable

No hagas nada fuera de este alcance.
