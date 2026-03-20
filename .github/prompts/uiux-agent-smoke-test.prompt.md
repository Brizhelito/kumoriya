---
description: "Ejecuta una prueba de humo mínima para verificar conectividad y respuesta de los agentes UI/UX de Kumoriya."
agent: "product-uiux-master-orchestrator"
argument-hint: "Describe un smoke test breve para comprobar alcance y wiring de los agentes UI/UX"
---

Realiza una pasada minima de prueba de vida, no una auditoria completa de UI/UX.

Objetivo:

- Verificar que el orquestador puede alcanzar y recibir respuesta de la cadena UI/UX.
- Confirmar que el wiring de agentes esta operativo con un recorrido minimo y controlado.
- Mantener el alcance deliberadamente pequeno: una sola interaccion de contacto por agente, sin analisis profundo ni propuestas extensas.

Agentes que deben tocarse al menos una vez:

- visual-identity-concept-artist
- color-material-strategist
- motion-interaction-storyboarder
- flutter-ui-refactor-implementer
- design-system-enforcer
- interaction-states-implementer
- player-controls-interaction-designer
- player-motion-feedback-designer
- player-ui-integration-implementer

Instrucciones:

1. Haz un contacto minimo con cada agente de la lista anterior.
2. Pide solo una respuesta breve de estado o alcance a cada uno.
3. Si un agente no responde, marca el fallo con el motivo observable.
4. No conviertas esto en una revision visual, de arquitectura o de implementacion.
5. No reescribas pantallas, contratos ni estado de la UI.

Formato de salida requerido:

- Resumen de agentes contactados.
- Lista de agentes faltantes o sin respuesta.
- Errores de wiring o enrutamiento observados.
- Confirmacion de que esto fue solo un smoke test minimo.

Solicitud:

{{input}}