# Guía de uso — Pipeline Architect / Worker / Reviewer

Flujo diario para construir features en Kumoriya minimizando coste y evitando drift.

## 0. Mapa mental

| Rol        | Quién         | Modelo         | Qué hace                                  |
|------------|---------------|----------------|-------------------------------------------|
| Architect  | Cascade       | fuerte         | Descompone feature → tasks+contratos+tests |
| Worker     | Cascade       | barato         | Implementa UNA task, output estricto       |
| Reviewer   | Cascade       | medio o fuerte | Valida contra contrato, tests, anti-cheat  |
| Orchestrator | `kumoriya-orch` MCP | n/a     | Estado, preflight, runners, index          |

El worker NUNCA ve `system_index.json` ni otras tasks. Solo ve lo suyo.

---

## 1. Registrar el MCP en Windsurf (una vez)

En la config MCP de Windsurf añadir:

```json
{
  "kumoriya-orch": {
    "command": "/home/reny/Projects/Kumoriya/tools/kumoriya-orch/.venv/bin/kumoriya-orch",
    "args": [],
    "env": { "KUMORIYA_ROOT": "/home/reny/Projects/Kumoriya" }
  }
}
```

Reiniciar Cascade. Verás herramientas con prefijo `kumoriya-orch.*`.

Si el MCP no está disponible, los workflows funcionan igual en modo fallback
leyendo/escribiendo `.agents/` directamente.

---

## 2. Flujo completo para un feature nuevo

### Paso 1 — Planificar (modelo fuerte)

1. Selector de modelo: **fuerte** (Sonnet/GPT-5).
2. En el chat: `/architect-plan` + descripción del feature.
3. Cascade:
   - consulta `system_index.json` y reporta conflictos
   - invoca skills relevantes (`kumoriya-architecture`, `resolver-plugin`, etc.)
   - crea `.agents/tasks/TASK-XXXX.yaml`, `contracts/*.json`, `tests/*.spec.yaml`
   - si detecta ambigüedad, crea `.agents/tasks/_questions.md` y se detiene
4. Revisa los archivos generados. Ajusta si hace falta antes de seguir.

### Paso 2 — Ejecutar la siguiente task lista

1. `/run-next-task` — arranca el loop completo.
2. El workflow:
   - llama `kumoriya-orch.next_task()` (respeta DAG de `depends_on`)
   - corre `preflight(TASK_ID)`; si falla → `/escalate-task`
   - te pide cambiar a modelo **barato**
   - llama `/worker-run TASK_ID` con payload minimizado
   - persiste con `submit_attempt` → corre `flutter analyze`, `flutter test`,
     `go test`, etc. según los paths tocados
   - te pide cambiar a modelo **medio/fuerte**
   - llama `/reviewer-check TASK_ID ATTEMPT_NN`
   - según verdict: retry con contexto estructurado, escalate, o pass
   - si pass → corre `run_mutation`, luego `commit_task` (actualiza index)

### Paso 3 — Repetir

`/run-next-task` se puede invocar hasta que `next_task()` devuelva null.

---

## 3. Comandos útiles del MCP

Desde Cascade puedes pedir cosas tipo:

- "lista todas las tasks con estado ready" → `list_tasks(status="ready")`
- "muéstrame la task TASK-0003" → `get_task("TASK-0003")`
- "qué ve el worker para TASK-0003" → `worker_context("TASK-0003")`
- "reconstruye el index desde cero" → `index_rebuild()`
- "dame el slice del index para src.slugify" → `index_slice(["src.slugify"])`

---

## 4. Cambio de modelo — regla simple

| Acción                    | Modelo  |
|---------------------------|---------|
| `/architect-plan`         | fuerte  |
| `/escalate-task`          | fuerte  |
| `/worker-run`             | barato  |
| `/reviewer-check`         | medio o fuerte |
| `/run-next-task`          | empieza medio; te pide cambiar |
| `/index-refresh`          | medio   |

El workflow `run-next-task` explícitamente te dice cuándo cambiar. No necesitas
memorizar esto — respondé lo que pida.

---

## 5. Qué hacer cuando algo se rompe

### Preflight falla
Significa que el contrato o los tests están mal. Ejecuta `/escalate-task TASK_ID preflight_failed`. El architect reescribe el spec, nunca el código.

### Worker emite `ESCALATE: ...`
El worker detectó que no puede cumplir el contrato con las reglas. Va directo a `/escalate-task TASK_ID <reason>`.

### Reviewer da verdict `escalate` con C8 (anti-cheat)
El worker hizo trampa (hardcoded, branching por input de test). No se reintenta: el architect debe **endurecer** tests con casos adversarios. Nunca relajar.

### Reviewer da `retry`
El workflow ya construyó `retry-context.json`. El siguiente intento tendrá ese contexto automáticamente. Cap: 2 reintentos.

### Mutation falla
Se promueve el input que rompió a test permanente y se reintenta. Si sigue fallando → escalate.

### Drift entre lo que hay en código y `system_index.json`
Correr `/index-refresh`. Detecta módulos perdidos o contratos divergentes y crea `TASK-XXXX-drift-*` automáticamente.

---

## 6. Estados de una task

```
ready → in_progress → pass        (happy path, index actualizado)
                   ↓
                   → blocked      (escalado al architect)
                   
pass  → stale   (una dependencia rompió la API que consume)
stale → ready   (tras /escalate-task con patch)
```

Solo tasks en `ready` con todos los `depends_on` en `pass` son runnables.

---

## 7. Reglas que NUNCA debes relajar

- El worker no lee `system_index.json`, otros archivos, ni otras tasks.
- No se pasan drafts anteriores del worker en retries (solo `retry-context.json`).
- C8 (anti-cheat) nunca se coachea: siempre `escalate`, nunca `retry`.
- Tests no se eliminan ni se relajan: solo se pueden endurecer.
- `system_index.json` solo se actualiza atómicamente cuando una task pasa
  reviewer **y** mutation.

Si te ves tentado a saltarte una, escribe una task explícita que lo justifique.

---

## 8. Token strategy rápido

- **Architect** recibe: feature request + `system_index.json` + rules. Nunca código completo del repo.
- **Worker** recibe: 1 task + 1 contrato + 1 spec de tests + solo archivos en
  `files_allowed` (minimizados si >120 LoC) + `retry-context.json` si aplica.
- **Reviewer** recibe: task+contrato+tests + artefactos del run + slice del
  system_index. Nunca ve el feature request original ni otras tasks.

Resultado típico: >80% del coste lo paga el modelo barato, el fuerte solo
planifica y repara specs.

---

## 9. Primer smoke test recomendado

Para validar que todo funciona antes de usarlo en algo real:

```
/architect-plan

Feature: Añadir función `src.slugify.slugify(text, max_len)` al paquete
`tools/resolver_cli` que convierta texto a slug ascii. Ver docs/ejemplos en
README de la guía. Solo código Dart puro, sin deps nuevas.
```

Luego `/run-next-task` hasta que todas las tasks lleguen a `pass`. Si funciona,
tienes la pipeline lista para features reales.

---

## 10. Extensiones pendientes (known stubs)

- `mutation.py` devuelve `skipped: true` con razón. Reviewer C10 solo advierte.
  Implementar harness por lenguaje cuando haga falta rigor extra.
- `runners.py` matching por prefix. Si tu task toca varios paquetes, añadir
  granularidad en `_match_runner`.
- `architect-plan` podría validarse con un `validate_spec` tool MCP adicional.

Estas limitaciones no bloquean el flujo; solo bajan el techo de rigor.
