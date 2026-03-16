---
inclusion: always
---

# Resolver Plugin (Kumoriya)

Implementa resolver plugins como módulos aislados y testeables. Mantén la lógica de resolver independiente de source plugins, pipeline de playback y UI.

## Cuándo activar este skill

Úsalo cuando:
- Implementes un nuevo resolver o endurezcas uno existente
- Definas contratos de resolver, normalización de URLs, manejo de headers/referer/cookies/timeouts
- Agregues fixtures HTML/JS y escribas tests enfocados en resolver
- Definas reglas conservadoras de aceptación/rechazo de hosts

## Restricciones absolutas

1. Tratar resolvers como plugins separados de las fuentes.
2. No agregar comportamiento de playback o UI en tareas de resolver.
3. Usar WebView solo como último recurso explícito y documentar por qué.
4. Preferir rechazo sobre manejo inseguro de hosts.
5. Mantener source plugins y resolver plugins independientes entre sí.

## Bloque de scope (publicar antes de codificar)

```md
Resolver Scope
- Request:
- Resolver target (new or existing):
- In scope:
- Out of scope (must include playback/UI):
- Done when:
```

## Implementación contract-first

```md
Resolver Contract Review
- interface/model:
- required inputs:
- required outputs:
- failure types:
```

1. Localizar contratos de resolver plugin y modelos result/error requeridos.
2. Validar expectativas de input: hosts aceptados, formas de URL aceptadas, contexto de request requerido.
3. Validar expectativas de output: payload de stream/link resuelto, metadata para capas downstream, razones de fallo tipadas.

## Política de aceptación y rechazo de hosts

1. Definir allowlist de hostnames para el resolver.
2. Normalizar y validar host antes de cualquier trabajo de red.
3. Rechazar si: host no está en allowlist, forma de URL no soportada, tokens/contexto requeridos faltantes.
4. Retornar errores explícitos estilo unsupported-host/invalid-url.

No intentar guessing cross-host.

## Normalización de URL y contexto de request

1. Canonicalizar scheme/host/path de forma segura.
2. Preservar query params relevantes requeridos por el host.
3. Eliminar ruido de tracking solo si se prueba irrelevante.
4. Construir contexto de request explícitamente: headers, referer/origin, cookies, user-agent o headers extra cuando se requieran.
5. Mantener política de request específica del host localizada en el módulo resolver.

## Hardening de parsing y extracción

1. Separar pasos de fetch/decode/parse.
2. Usar parsing defensivo para respuestas HTML/JS: guards null/empty, límites de regex con comportamiento fail-safe, múltiples estrategias de extracción solo cuando sean deterministas.
3. Evitar lógica frágil de un-selector cuando existan alternativas más seguras.
4. Emitir fallos de parse tipados en lugar de excepciones no manejadas.

## Errores, retries y timeouts

1. Configurar presupuestos de timeout explícitos por etapa de request.
2. Distinguir timeout, network, parse y errores unsupported.
3. Reintentar solo llamadas idempotentes seguras y mantener conteo de retry acotado.
4. En fallo repetido, retornar error tipado con diagnósticos mínimos.

## Fixtures y tests por resolver

```md
Fixture Plan
- fixture file:
- host scenario:
- scenario covered:
```

Fixtures de edge obligatorias: token faltante, forma de script ofuscada/cambiada, página de acceso denegado/captcha.

Tests mínimos:
1. Aceptación de host exitosa.
2. Rechazo de host para dominio no soportado.
3. Comportamiento de normalización de URL.
4. Parsing exitoso en fixture estándar.
5. Fallo de parsing en fixture cambiada/inválida.
6. Comportamiento de timeout/error-path.

## Checklist de validación

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <resolver package>
- [ ] dart test <resolver tests>
```

No declarar estabilidad del resolver sin tests ejecutados.

## Documentación de riesgos

```md
Resolver Risks
- host/resolver:
- risk:
- trigger:
- mitigation:
- fallback behavior:
```

Ejemplos: anti-bot challenges, tokens rotativos, scripts inline inestables, dependencias obligatorias de referer/cookie.

## Plantilla de reporte final

```md
Resolver Plugin Report
- Scope executed:
- Contracts touched:
- Host policy (accept/reject):
- URL/context handling changes:
- Fixtures added/updated:
- Tests run:
  - command:
  - result:
- Risks documented:
- Residual risk:
```
