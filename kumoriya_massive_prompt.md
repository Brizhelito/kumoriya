# Kumoriya — Mega Prompt de Consolidación Total

## Rol del agente
Actúa como **lead engineer + systems architect + debugging specialist + product integrator** para Kumoriya.

Tu misión es ejecutar una **fase masiva de consolidación end-to-end** del proyecto, usando al máximo las capacidades del entorno, los skills ya instalados, las rules del proyecto, las memorias/contexto disponible y las herramientas/MCPs configurados.

No quiero una respuesta superficial ni una lluvia de cambios desordenados.
Quiero una ejecución grande, profunda, bien auditada, con prioridades correctas, límites claros, validación real y entregables serios.

---

## Objetivo global
Llevar Kumoriya a un estado mucho más completo y usable cubriendo, de forma coordinada y arquitectónicamente correcta, estas áreas:

1. **Cerrar JKAnime por completo**
   - extractor dinámico robusto
   - cobertura amplia de hosts reales
   - resolvers funcionales
   - clasificación clara de hosts bloqueados o avanzados

2. **Expandir fuentes**
   - **AnimeFLV**
   - **AnimeAV1**
   con integración correcta a la arquitectura actual

3. **Reutilizar resolvers entre fuentes**
   - resolvers por host real, no por fuente
   - una sola familia de resolvers reutilizable para JKAnime, AnimeFLV, AnimeAV1 y futuras fuentes

4. **Storage / Progress foundations**
   - progreso por episodio
   - resume position
   - último servidor usado
   - último stream exitoso
   - persistencia mínima correcta

5. **Download foundations**
   - modelado correcto de descargas
   - soporte inicial para fuentes descargables relevantes (por ejemplo Mediafire si aplica)
   - no romper arquitectura de reproducción

6. **Mantener la arquitectura limpia**
   - source plugins extraen
   - resolver plugins resuelven hosts
   - player reproduce
   - storage persiste estado
   - downloads siguen su propio pipeline

---

## Contexto confirmado del proyecto
Ya existe y funciona al menos parcialmente:

- bootstrap real del monorepo
- app Flutter
- slices AniList
- JKAnime source plugin
- matching AniList ↔ JKAnime
- episodios reales
- extracción dinámica mejorada de fuentes
- resolver pipeline
- player básico funcional
- hardening inicial de player
- i18n base
- design system base
- resolver registry

También ya se investigó que:

- algunos hosts funcionan correctamente (por ejemplo JKPlayer, Mp4Upload, Streamwish en cierto estado)
- otros requieren hardening o aliases reales
- VOE puede entrar en flujos session-gated / browser-like más complejos
- Mixdrop, Filemoon, Doodstream y otros pueden requerir ajustes host-by-host
- JKAnime muestra más botones que los que aparecen solo en HTML estático, por lo que la auditoría runtime/DOM/network es crítica

---

## Lista de hosts / labels / familias prioritarias a cubrir
Quiero que cubras y cierres correctamente, con criterio técnico real, el universo de hosts / labels de JKAnime y su reutilización en otras fuentes.

### Universo inicial a revisar / soportar
- Desu
- Magi
- Streamwish
- VOE
- Vidhide
- Filemoon
- Mixdrop
- Mp4Upload
- Streamtape
- Doodstream

## Regla crítica
No asumas que cada label visual es un resolver distinto.
Debes mapear:

**label visible → URL real → host real → familia de resolver**

Ejemplo:
- si “Magi” termina en `jkanime.net/jkplayer/...`, eso puede ser una familia real específica de JKAnime
- si “Filemoon” termina en `bysekoze.com`, eso debe enrutar a Filemoon si la evidencia real lo confirma
- si “Mixdrop” termina en `mxdrop.to`, eso debe enrutar a Mixdrop si la evidencia real lo confirma
- si un label lleva a wrapper intermedio, debes decidir correctamente si ese wrapper es el host final o solo una capa intermedia

---

## Fuentes a integrar en esta fase
Además de JKAnime, integra correctamente:

### 1. AnimeFLV
Quiero:
- source plugin real
- búsqueda
- detalle mínimo útil
- episodios reales
- extracción de server links
- reuso máximo del ecosistema actual de resolvers

### 2. AnimeAV1
Quiero:
- source plugin real
- búsqueda
- detalle mínimo útil
- episodios reales
- extracción de server links
- reuso máximo del ecosistema actual de resolvers

## Restricción importante
No quiero tres ecosistemas separados por fuente.
Quiero:
- **source plugins por fuente**
- **resolvers por host real reutilizables**

---

## Storage / Progress foundations
Quiero que esta fase también deje lista la base real de persistencia de progreso.

### Debe incluir como mínimo
- progreso por anime / episodio
- posición de reproducción (resume)
- fecha/hora de último acceso
- último source usado si aporta valor
- último server link exitoso si aporta valor
- último resolver exitoso si aporta valor
- estado watched / partially watched / completed si aplica

### Objetivo
Cuando el usuario vuelva:
- pueda retomar reproducción
- se sepa qué episodio va
- se recuerde el contexto útil sin mezclar lógica de player y storage

### Restricción
No quiero tracking premium gigantesco.
Quiero foundations limpias y útiles.

---

## Download foundations
Quiero que en esta fase se avance también en la base de descargas.

### Debe incluir como mínimo
- modelado claro entre:
  - stream source
  - download source
- clasificación correcta de links de descarga
- pipeline mínimo de preparación de descargas
- evaluación seria de hosts como:
  - Mediafire
  - cualquier otro host de descarga real encontrado

### Objetivo
No necesariamente quiero terminar el sistema completo de descargas premium.
Quiero dejar:
- arquitectura correcta
- contratos
- casos básicos útiles
- integración suficiente para que el proyecto no tenga que rehacerse después

### Regla crítica
No mezclar descargas con playback.
Mediafire, por ejemplo, puede ser útil como download source aunque no sea un playback source fiable.
Si es posible usar Mediafire como download source, hazlo.
Si es posible usar otros hosts de descarga como download source, hazlo. Tipo Streamtape, etc.
---

## Qué espero del agente en esta fase
Quiero que ejecutes esta fase masiva como un **programa de trabajo estructurado**, no como una sola edición caótica de archivos.

### Debes trabajar internamente por subfases lógicas
Aunque el prompt sea masivo, tu ejecución debe ordenar el trabajo al menos en algo parecido a:

1. auditoría actual completa del estado real
2. matriz real de fuentes y hosts
3. cierre de JKAnime extractor + hosts
4. expansión / hardening de resolvers reales
5. integración de AnimeFLV
6. integración de AnimeAV1
7. storage/progress foundations
8. download foundations
9. validación end-to-end
10. cleanup final y documentación mínima necesaria

No quiero que me preguntes entre cada micro paso salvo bloqueo real.
Y si necesitas preguntar algo, hazlo de forma concisa y específica sin interrumpir el flujo de trabajo, con la herramienta que tienes para preguntas.
---

## Cómo quiero que uses las capacidades del entorno
Usa al máximo las herramientas del entorno y el contexto ya existente.

### Debes aprovechar correctamente
- rules del proyecto
- skills instaladas
- memorias/contexto local
- AGENTS / instrucciones del repo
- MCPs/herramientas configuradas
- inspección runtime cuando la web o el host lo requiera
- comparación entre comportamiento estático y dinámico
- validación con tests y build real

## Regla operacional importante
No te quedes solo en inspección estática cuando:
- un sitio carga links dinámicamente
- un host depende de JS runtime
- un payload real difiere del fixture
- un botón visible no implica URL real disponible

Quiero uso inteligente de auditoría runtime / browser / network cuando haga falta, pero sin convertirlo en dependencia de producción salvo que quede claramente justificado.

---

## Requisitos concretos por área

# A. JKAnime — cierre fuerte
Quiero que JKAnime quede lo más cerrado posible en esta fase.

### Debes revisar y corregir
- búsqueda
- detalle
- episodios
- server links
- fuentes dinámicas
- wrappers / aliases
- clasificación stream vs download

### Quiero una matriz clara de output
Por ejemplo, al final deberías saber algo como:
- Desu → JKPlayer family → resolver OK
- Magi → JKPlayer family → resolver OK
- Streamwish → host real X → resolver OK
- Filemoon → alias Y → resolver parcial/OK
- Mixdrop → alias Z → resolver OK
- VOE → session-gated / fallback / unsupported by current architecture si aplica
- Intenta arreglar los resolvers que no funcionan correctamente.

### Regla
No inventes links solo porque hay botón visible.

---

# B. Resolver ecosystem — cobertura real
Quiero que cierres la cobertura de resolvers con máxima utilidad real.

### Resolver philosophy
- resolvers por host real
- reutilizables entre fuentes
- `ResolvedStream` suficientemente rico
- headers/cookies/contexto cuando haga falta
- errores tipados y útiles

### Quiero cobertura seria de hosts frecuentes
Con prioridad por impacto real observado en las fuentes.

### Para cada resolver
Quiero que determines:
- host canónico
- aliases reales confirmados
- payload shapes soportados
- necesidades de headers
- si requiere cookies/sesión
- si se puede soportar con HTTP simple
- si requiere estrategia avanzada
- si es un host de descarga
- si se necesita de una estrategia avanzada, realizarla
### Si un host queda fuera
No lo tapes con ambigüedad.
Quiero clasificación explícita:
- supported
- partially supported
- unsupported for now
- browser-assisted candidate
- download-only candidate

---

# C. AnimeFLV source plugin
Quiero integración real, no placeholder.

### Debe incluir
- search
- anime detail mínimo útil
- episodes
- source links
- mapping razonable con AniList
- reuso de resolvers existentes
- crear resolvers para hosts que no existan

### Matching
Quiero matching conservador, igual que con JKAnime.
Prefiero no-match antes que match falso.

### Restricción
No quiero hacks específicos por resolver en AnimeFLV.
Si un host es Mixdrop, Filemoon, VOE, etc., debe usar el mismo resolver del ecosistema general.

---

# D. AnimeAV1 source plugin
Misma lógica que AnimeFLV.

### Debe incluir
- search
- anime detail mínimo útil
- episodes
- source links
- matching conservador con AniList
- reuso del ecosistema actual de resolvers
- crear resolvers para hosts que no existan
 
### Restricción
No crear ecosistema duplicado de resolvers por fuente.

---

# E. Storage / progress
Quiero foundations reales en esta fase.

### Debes dejar resuelto
- dónde persiste progreso
- cómo se representa el resume position
- cómo se representa el episodio actual
- cómo se actualiza al reproducir
- cómo se consulta al volver a entrar
- qué información de source/server/stream conviene persistir

### Restricción
No sobreingenierices.
No necesito analytics enterprise.
Necesito una base buena, usable y mantenible.

---

# F. Download foundations
Quiero que aquí quede la base correcta para descargas.

### Debes determinar
- qué hosts de descarga son realmente útiles
- cuáles son stream-only
- cuáles son download-only
- si Mediafire debe entrar como download source real
- si se puede iniciar una base de pipeline de descarga sin mezclar con playback
- Si consideras que se puede implementar sin mezclar con playback, hazlo.
- Si no es complicado implementar todo el sistema de descargas, hazlo.

### Si no completas todo el sistema de descargas
Está bien, pero quiero que dejes:
- contratos
- modelos
- clasificación
- wiring inicial correcto
- decisiones arquitectónicas cerradas

---

## Arquitectura que no debes romper
Debe seguir siendo cierto que:

### Source plugins
- buscan
- detallan
- listan episodios
- extraen server links / download links

### Resolver plugins
- resuelven hosts reales
- devuelven `ResolvedStream`
- incluyen headers/cookies/contexto necesarios cuando corresponda
- en resumen, deben ser reutilizables entre fuentes, no específicos de una sola fuente
- Si hay que agregar algo específico de una fuente, hazlo de manera que no afecte a las demás

### Player
- consume `ResolvedStream`
- no resuelve
- no scrapea

### Storage
- persiste progreso/estado
- no resuelve
- no scrapea

### Downloads
- usan sus propios modelos/pipeline
- no se mezclan con player ni con resolver salvo donde sea estrictamente lógico

---

## Reglas de implementación

### 1. No quiero una lluvia de cambios sin priorización
Debes priorizar por:
- valor real de playback
- frecuencia de host/fuente
- costo técnico
- reutilización futura

### 2. No quiero inventar soporte
Si algo no se puede soportar razonablemente hoy, dilo claramente. Pero si es posible, intenta implementarlo.

### 3. No quiero duplicación innecesaria
Si un resolver sirve para JKAnime y AnimeFLV, debe ser el mismo.

### 4. No quiero relajar demasiado `supports()`
Nada de matching laxo que rompa el registry.

### 5. Quiero degradación segura
Casos como:
- host no soportado
- payload inconsistente
- token/session-gated
- parse failure
- transport error
- no match
- no server links
- download-only

Deben quedar bien diferenciados.

### 6. Quiero validación real, no solo unit tests
Cuando sea razonable, valida:
- flujo real en app
- runtime real
- requests reales
- build real

---

## Qué NO debes hacer
No quiero que esta fase se descontrole.

### No hacer
- reescribir toda la app desde cero
- rediseño visual masivo
- premium player features avanzadas
- autoskip todavía
- auto-next complejo todavía
- segunda/tercera capa de abstracciones innecesarias
- mezclar browser runtime en producción salvo justificación muy fuerte y aislamiento arquitectónico claro

---

## Versionado obligatorio
Quiero checkpoints/commits serios por subfase útil.

Ejemplos razonables:
- audit/source-host matrix
- JKAnime extraction closeout
- resolver batch 1
- resolver batch 2
- AnimeFLV source integration
- AnimeAV1 source integration
- storage/progress foundations
- download foundations
- final validation / cleanup

No quiero un solo commit gigante y desordenado.

---

## Validación obligatoria al final
Debes ejecutar lo necesario para demostrar que esto no quedó en teoría.

### Quiero como mínimo
- `flutter pub get`
- `dart format`
- `dart analyze`
- tests relevantes por package afectado
- build real de Windows
- validación razonable del flujo en app

### Debes confirmar explícitamente
1. qué hosts/resolvers quedaron realmente funcionales
2. qué hosts quedaron parciales
3. qué hosts quedaron fuera y por qué
4. qué fuentes nuevas quedaron integradas realmente
5. si Storage/Progress quedó funcional
6. qué parte de Download quedó lista y qué no
7. si la arquitectura se mantuvo limpia

---

## Entregable obligatorio
Devuélveme un reporte en Markdown con esta estructura exacta:

# 1. MCPs / tools / project capabilities used
- what was used
- why it was used
- what value it added
- how skills/rules/context were leveraged

# 2. Overall execution plan actually followed
- what phases you executed
- what order you chose
- why that order was optimal

# 3. JKAnime closeout
- extractor changes
- dynamic source coverage
- host matrix
- what is now fully/partially supported

# 4. Resolver ecosystem
- which resolvers were added or fixed
- aliases covered
- payloads supported
- which hosts remain blocked and why

# 5. AnimeFLV integration
- what was implemented
- how matching works
- how resolvers are reused
- current limitations

# 6. AnimeAV1 integration
- what was implemented
- how matching works
- how resolvers are reused
- current limitations

# 7. Storage / progress foundations
- what models/contracts/services were added
- what user progress is persisted
- how resume works now

# 8. Download foundations
- what was implemented
- how download sources are modeled
- what hosts are useful for download
- what remains pending

# 9. Tests / fixtures / validation
- what tests were added or updated
- what fixtures were added
- what runtime validations were done
- what build/test/analyze results were obtained

# 10. Commits / checkpoints
- every major commit/checkpoint
- what each one did
- why history is organized that way

# 11. Coverage summary
Produce a clear matrix like:
- host/source
- extraction status
- resolver status
- playback status
- download usefulness
- confidence level

# 12. Risks
- remaining fragilities
- unstable hosts
- session-gated/browser-assisted candidates
- what still needs hardening

# 13. Next recommended step
Choose exactly one and justify it:
- harden unresolved high-value hosts before more features
- stabilize second-source UX + matching before downloads
- push download pipeline deeper now

---

## Final instruction
Implement this as a **massive but disciplined Kumoriya consolidation phase**.

Use the large available context intelligently.
Exploit the project skills, rules, context, existing architecture, and available tools to maximum effect.

I want a serious, high-value, long-horizon execution.
Not a shallow patch.
Not a chaotic rewrite.
A real consolidation step that moves Kumoriya significantly forward across:

- resolvers
- sources
- storage/progress
- downloads
- end-to-end usability
