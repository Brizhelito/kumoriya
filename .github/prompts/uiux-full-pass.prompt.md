---
description: "Ejecuta una pasada generalista, sistematica y completa de revision/mejora UI/UX para toda la app Kumoriya con orquestacion multiagente."
agent: "product-uiux-master-orchestrator"
argument-hint: "Describe objetivo, restricciones y profundidad; por defecto cubre toda la app de forma sistematica"
---

Realiza una pasada generalista y sistematica de revision y mejora UI/UX para toda la aplicacion Kumoriya.

Requisitos no negociables:

- Cubre toda la aplicacion, no solo una pantalla aislada.
- Si falta mapa de pantallas/flows, construyelo primero y usalo como base de auditoria.
- Incluye evaluacion y mejoras para estados: loading, empty, error, retry, unavailable, success.
- No cierres la tarea con cobertura parcial sin declararlo explicitamente con porcentaje de cobertura.
- Prioriza claridad de jerarquia visual, navegacion, descubribilidad y consistencia.
- Respeta el sistema de diseno existente; no introduzcas cambios de identidad sin justificacion.
- Diferencia claramente hallazgos, mejoras propuestas e implementaciones efectivas.
- Evita recomendaciones vagas: cada mejora debe ser accionable en Flutter.

Flujo obligatorio:

1. Publica primero el alcance con este bloque:

```md
UIUX Full Pass Scope
- Audit mode: (full app por defecto)
- App modules in scope:
- App surfaces in scope:
- User journeys in scope:
- Out of scope:
- Device targets:
- Accessibility baseline:
- Constraints (tiempo/tecnico/producto):
- Acceptance rule:
```

2. Construye y publica una matriz de cobertura completa antes de evaluar:
   - modulo
   - pantalla/feature
   - flujo principal
   - estados requeridos
   - estado de auditoria (pending/in-review/done)
   - severidad maxima encontrada

3. Ejecuta auditoria sistematica para cada item de la matriz con la misma heuristica base:
   - jerarquia visual y legibilidad
   - estructura de informacion y escaneabilidad
   - claridad de CTA y affordances
   - navegacion, retorno y continuidad de flujo
   - feedback del sistema y tiempos de espera
   - estados de carga/vacio/error/retry/unavailable/success
   - consistencia con design system (tokens, spacing, tipografia, componentes)
   - accesibilidad (contraste, tamano tactil, foco, labels)
   - adaptabilidad responsive (mobile y desktop)

4. Coordina especialistas cuando aplique:
   - direccion visual y consistencia: uiux-creative-director
   - implementacion Flutter: uiux-implementation-lead y flutter-ui-refactor-implementer
   - estados de interaccion: interaction-states-implementer
   - compliance de design system: design-system-enforcer
   - color/material y contraste: color-material-strategist
   - motion narrativa y feedback: motion-interaction-storyboarder
   - player UX especifico: player-uiux-lead

5. Convierte hallazgos en backlog priorizado con impacto y esfuerzo:
   - P0: bloqueo UX o confusion critica
   - P1: friccion alta o inconsistencia notable
   - P2: polish con impacto moderado

6. Implementa una ronda de mejoras de mayor valor dentro del alcance permitido y valida:
   - coherencia visual
   - estados completos
   - navegacion y feedback
   - legibilidad y contraste
   - adaptacion mobile/desktop

7. Cierra con reporte final y plan de continuidad.

Formato de salida obligatorio:

- Scope publicado
- Matriz de cobertura completa con porcentaje auditado
- Hallazgos por modulo/pantalla/flujo con severidad y evidencia
- Backlog priorizado (P0/P1/P2)
- Cambios implementados (archivo por archivo)
- Resultados de validacion (analisis/tests/manual)
- Riesgos residuales
- Siguientes iteraciones recomendadas

Solicitud:

{{input}}