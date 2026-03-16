---
inclusion: always
---

# Resolver Runtime Audit (Kumoriya)

Ejecuta auditorías de resolver con evidencia real, no suposiciones. Parte del inventario de código, contrasta con comportamiento runtime observado, aísla causa raíz por capa, y propone fixes mínimos de alto impacto.

## Cuándo activar este skill

Úsalo cuando:
- Diagnostiques por qué un resolver falla en producción/runtime
- Descubras aliases reales de hosts o dominios CDN/mirror
- Entiendas links expuestos dinámicamente desde source plugins
- Compares por qué un host funciona y otro falla
- Decidas si el fallo está en source extraction, host gating, parser logic, redirects/referer policy, o payload shape

## Restricciones absolutas

1. Preferir ningún link sobre link fabricado; nunca inventar URLs, tokens o headers.
2. No asumir que un botón o anchor visible equivale a la URL real de media.
3. No asumir que el HTML inicial contiene la verdad runtime final.
4. Evitar rewrites masivos antes de que la causa raíz esté probada.
5. Mantener comportamiento del player fuera de fixes de resolver/source salvo que la tarea lo incluya explícitamente.
6. Priorizar fixes por impacto observado en usuario y confianza del diagnóstico.

## Bloque de scope (publicar antes de investigar)

```md
Resolver Runtime Audit Scope
- Request:
- Target flows (episode/source/host):
- In scope:
- Out of scope (must mention player if excluded):
- Evidence required to close:
```

## Flujo de auditoría

### Paso 1: Inventario estático primero

```md
Static Inventory
- source plugin paths:
- resolver plugin paths:
- host aliases currently accepted:
- parser/extractor functions:
- existing fixtures/tests:
- known contract gaps:
```

Inspeccionar código y contratos existentes antes de cualquier sondeo runtime.

### Paso 2: Decidir si la inspección runtime es obligatoria

Usar inspección runtime cuando:
- Link/token aparece solo después de ejecución JS o llamadas XHR/fetch
- Existen múltiples redirects/referer/cookie constraints
- HTML estático carece del manifest final o URL firmada
- Host funciona en browser pero falla en código resolver
- Se sospecha mismatch de alias/dominio (mirror/cdn/embed domains)

Si ninguno aplica, continuar con análisis estático + fixtures primero.

### Paso 3: Capturar evidencia runtime

```md
Runtime Evidence
- page/step:
- observed host/domain:
- decisive request URL:
- decisive response type:
- required headers/context:
- redirect chain summary:
- proof artifact path:
```

1. Abrir el flujo real de episodio/embed.
2. Capturar DOM después de que los scripts ejecuten.
3. Recolectar timeline de red.
4. Identificar requests/responses decisivos: bootstrap payload del embed, endpoints API retornando listas de fuentes/manifests, cadena de redirects y URL final efectiva, headers necesarios.
5. Guardar artefactos reproducibles (HTML/JSON/JS snippets) para actualización de fixtures.

### Paso 4: Comparar verdad runtime vs código/fixtures

1. Comparar hostnames reales con allowlist y normalización de aliases.
2. Comparar forma del payload con suposiciones del parser.
3. Comparar requisitos de redirect/referer/cookie con política de request del resolver.
4. Comparar fixtures actuales contra artefactos capturados.
5. Marcar cada mismatch como probado, sospechado, o rechazado.

### Paso 5: Aislar causa raíz por capa

```md
Root Cause Matrix
- resolver/host:
- failing step:
- layer:
- evidence:
- confidence (low/medium/high):
- blast radius:
```

Capas posibles:
- `source-extraction`: source plugin falla en exponer embed/context correcto
- `host-aliasing`: resolver rechaza o enruta mal por normalización de alias faltante
- `resolver-parser`: parser del resolver falla para payload/JS shape real
- `redirect-policy`: resolver pierde referer/origin/cookies requeridos en redirects
- `runtime-payload`: contrato runtime del host cambió (token/signature/endpoint schema)
- `non-resolver`: problema pertenece a player/session/orchestration después de resolución exitosa

Requerir evidencia concreta para cada causa raíz asignada.

### Paso 6: Plan de fix mínimo de alto impacto

Priorización:
- `P0`: Host ampliamente usado y actualmente roto; evidencia alta.
- `P1`: Impacto medio o flujo parcialmente roto; evidencia alta.
- `P2`: Hardening/refactor; sin rotura inmediata para usuario.

```md
Prioritized Fix Plan
- priority:
- resolver/host:
- change:
- why now:
- tests/fixtures to add:
```

### Paso 7: Validar y cerrar

```md
Validation
- format:
- analyze:
- tests:
- runtime re-check:
- residual risk:
```

No marcar issue como fixed sin evidencia de checks a nivel código Y verificación runtime cuando el comportamiento runtime es parte del fallo.

## Plantilla de reporte final

```md
Resolver Runtime Audit Report
- Technical diagnosis:
- Host/resolver inventory:
- Root cause per problematic resolver:
- Prioritized fix plan:
- Validation results:
- Residual risks / unknowns:
```
