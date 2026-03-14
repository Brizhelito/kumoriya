Resolver Runtime Audit Report

- Request: ingenieria inversa del reproductor y la proteccion de Anime Nexus.
- Target flows: `https://anime.nexus/watch/:episodeId/:slug`, bootstrap API, CDN firmado y control plane websocket.
- Tools used: `Playwright MCP`, `adb`, `Chrome DevTools remote debugging`, `curl`, `node`.

Resolver Runtime Audit Scope
- Request: ingenieria inversa del reproductor y la proteccion de Anime Nexus
- Target flows (episode/source/host): `anime.nexus/watch/...`, bootstrap API, CDN firmado y canal websocket de reproduccion
- In scope: inventario estatico del resolver, runtime DOM/JS/network, cookies/storage, firma de manifests/segments, riesgos concretos para el plugin
- Out of scope (must mention player if excluded): cambios de UI y del player de Kumoriya; solo se audita su contrato de entrada/salida
- Evidence required to close: requests/responses decisivos, estado de sesion/fingerprint, evidencia del flujo de tokens y un informe accionable

Static Inventory
- source plugin paths:
  - `packages/kumoriya_source_anime_nexus/lib/src/anime_nexus_source_plugin.dart`
- resolver plugin paths:
  - `packages/kumoriya_resolver_anime_nexus/lib/src/anime_nexus_resolver_plugin.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/models/nexus_browser_session.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/page_scraper.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/stream_data_fetcher.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/signed_hls_builder.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/ws_client.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/playback_proxy_server.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/services/playback_session_worker.dart`
  - `packages/kumoriya_resolver_anime_nexus/lib/src/utils/nexus_constants.dart`
- host aliases currently accepted:
  - `anime.nexus`
  - API hosts and `*.cdn.nexus` are used internally by the resolver after bootstrap
- parser/extractor functions:
  - `NexusPageScraper.scrape()`: extrae `attestRef` del HTML SSR con regex
  - `NexusStreamDataFetcher.fetch()`: ejecuta `auth/session`, `episode/view`, `episode/stream`
  - `NexusSignedHlsBuilder.build()`: descarga el HLS API, sondea edges y monta manifests firmados locales
  - `NexusWsClient`: autentica el websocket y pide tokens de manifest/segment
- existing fixtures/tests:
  - cobertura parcial en resolver; el contrato real depende de runtime, no solo de fixtures estaticos
- known contract gaps:
  - el resolver sintetiza `fingerprint` UUID y `sid` cookie localmente
  - el sitio real persiste `sid`, `ws_session_id` y `device_fingerprint` en browser storage
  - si el backend acopla mas fuerte SSR/session/ws/fingerprint, la implementacion actual se volvera fragil

Technical Diagnosis

1. HTML SSR y bootstrap inicial
- El watch page devuelve `attestRef` en el HTML SSR. No es fiable buscarlo solo en el DOM post-hydration.
- Evidencia runtime:
  - `fetch(location.href).text()` sobre `https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/episode-10-c9b0cd86068190028be1`
  - `attestRef`: `d8d9e489997bf88eeebb76e9d42dccad121ccd14356d6d2b04980b5129103239`
- Implicacion:
  - la estrategia actual del resolver de leer HTML crudo es correcta
  - leer solo DOM hidratado seria un error

2. Estado de sesion y dispositivo
- En el browser real, `sid` cookie y `ws_session_id` en `localStorage` coinciden.
- Evidencia runtime:
  - `sid=d40f8d7330b948f224fc18d7ddaca89a`
  - `ws_session_id=d40f8d7330b948f224fc18d7ddaca89a`
  - `device_fingerprint=3245ccb0-2d24-4d21-9573-d394bfcf503f`
  - `current_fingerprint=3245ccb0-2d24-4d21-9573-d394bfcf503f`
  - `ws_session_expiry=1773394683458`
- Tambien queda persistido:
  - `cdnEdgeConfig` con `selectedEdge`, pings y fallos por POP
- Implicacion:
  - la proteccion no depende solo del token de segmento
  - hay identidad de sesion y dispositivo persistida en el cliente

3. Bootstrap API real
- Requests observados en watch flow:
  - `GET https://anime.nexus/api/auth/session` -> `204`
  - `POST https://api.anime.nexus/api/anime/details/episode/view` -> `200`
  - `GET https://api.anime.nexus/api/anime/details/episode/stream?id=019cdcfe-dc32-7328-9747-0e6ef96dbd06&fillers=true&recaps=true` -> `200`
  - `GET https://api.anime.nexus/api/anime/video/019cde22-458d-73b8-9baa-6873c2f00438/stream/video.m3u8` -> `200`
  - `GET https://us1.cdn.nexus/api/edges` -> `200`
  - varios `HEAD https://<edge>.cdn.nexus/ping`
- Stream payload observado:
  - `hls=https://api.anime.nexus/api/anime/video/019cde22-458d-73b8-9baa-6873c2f00438/stream/video.m3u8`
  - `chapters=https://api.anime.nexus/api/anime/video/019cde22-458d-73b8-9baa-6873c2f00438/stream/cues.vtt`
  - `thumbnails=https://api.anime.nexus/api/anime/video/019cde22-458d-73b8-9baa-6873c2f00438/stream/thumbnails.vtt`
  - varias pistas `.ass` en `assets.anime.nexus`
- Implicacion:
  - el endpoint `episode/stream` no entrega URLs CDN finales; entrega un HLS API intermedio y metadatos auxiliares

4. CDN firmado y anti-replay
- Requests observados:
  - manifest:
    - `https://us1.cdn.nexus/...mkv_4400-0.m3u8?token=...&requestType=manifest&sessionId=d40f8d7330b948f224fc18d7ddaca89a`
    - `https://us1.cdn.nexus/...mkv_4400-1.m3u8?token=...&requestType=manifest&sessionId=d40f8d7330b948f224fc18d7ddaca89a`
  - init segment:
    - `..._init-0.mp4?token=...&requestType=segment&sessionId=...&segmentPath=%2Fanime%2Fstreams%2F...`
  - media segment:
    - `..._0000-1.m4s?token=...&requestType=segment&sessionId=...&segmentPath=%2Fanime%2Fstreams%2F...`
- Evidencia fuerte de anti-replay:
  - un `segment` concreto devolvio `200`
  - el mismo URL repetido despues devolvio `403`
  - un URL nuevo para el mismo path con token distinto devolvio `200`
- Implicacion:
  - los tokens de segmento no son reutilizables de forma segura
  - servir URLs CDN firmadas directamente al player es fragil
  - el proxy HLS local del resolver tiene sentido tecnico real

5. Edge selection
- El browser sondea POPs y persiste resultados:
  - `us1`, `br1`, `eu1`, `in1`, `kr1`, `jp1`, `ml1`, `sg1`, `cl1`, `au1`
- Evidencia runtime:
  - `cdnEdgeConfig={"selectedEdge":"auto","lastPingResults":{"us1":71,"br1":173,"eu1":186,"in1":295,"kr1":226,"jp1":207,"ml1":289,"sg1":284,"cl1":170,"au1":299},...}`
- Implicacion:
  - el edge no es fijo
  - usar solo un POP hardcodeado seria un punto de fallo innecesario

6. Player runtime
- El `video.currentSrc` observado es un `blob:` interno:
  - `blob:https://anime.nexus/b4048dac-5350-4640-b417-410d2cdcf219`
- `readyState=4`, `paused=true`, `error=null`
- Implicacion:
  - el player no expone directamente el CDN final al DOM
  - el plano de reproduccion real vive en fetch/XHR, no en un simple `<video src>`

7. Bundle del player
- El bundle minificado `https://anime.nexus/assets/player.jkwBxCsE.js` contiene referencias directas a:
  - `attestRef`
  - `getToken`
  - `getSessionId`
  - `getFingerprint`
  - `requestSegmentToken`
  - `requestManifestToken`
  - `getChallengeRef`
  - `waitForChallengeReset`
  - `requestType`
  - `sessionId`
  - `cdn.nexus`
- Evidencia extraida por inspeccion de strings:
  - `getToken':()=>...,'getSessionId':()=>...,'getFingerprint':()=>...,'requestSegmentToken':...,'requestManifestToken':...,'getChallengeRef':()=>...,'waitForChallengeReset':async()=>`
- Implicacion:
  - el sitio real tambien modela el player como broker de tokens y sesion
  - la arquitectura actual del resolver de Kumoriya esta alineada conceptualmente con el sitio

Host/Resolver Inventory
- Browser watch host:
  - `https://anime.nexus/watch/...`
- Bootstrap/API hosts:
  - `https://anime.nexus/api/auth/session`
  - `https://api.anime.nexus/api/anime/details/episode/view`
  - `https://api.anime.nexus/api/anime/details/episode/stream`
  - `https://api.anime.nexus/api/anime/video/.../stream/video.m3u8`
- Asset hosts:
  - `https://assets.anime.nexus/...`
- Edge/CDN hosts:
  - `https://us1.cdn.nexus/...`
  - mas POPs bajo `*.cdn.nexus`

Root Cause Matrix
- resolver/host: Anime Nexus player contract
  - failing step: asumir que el HLS API ya es estable/final
  - layer: `runtime-payload`
  - evidence: manifests y segments reales salen de `*.cdn.nexus` con `token`, `requestType`, `sessionId`, `segmentPath`
  - confidence: high
  - blast radius: total si se intenta bypass del control plane

- resolver/host: Anime Nexus token lifecycle
  - failing step: reutilizar segment URLs o cachearlas demasiado tiempo
  - layer: `runtime-payload`
  - evidence: mismo segment URL dio `200` y luego `403`; token nuevo restauro `200`
  - confidence: high
  - blast radius: buffering, errores intermitentes, fallos de seek/resume

- resolver/host: Anime Nexus attestation
  - failing step: buscar `attestRef` en DOM hidratado o inferirlo
  - layer: `resolver-parser`
  - evidence: `attestRef` sale del HTML SSR crudo y no es fiable en el DOM ya hidratado
  - confidence: high
  - blast radius: fallo total de autenticacion websocket/token broker

- resolver/host: Anime Nexus session identity
  - failing step: desacoplar `sid`, `ws_session_id` y fingerprint sin confirmar tolerancia del backend
  - layer: `runtime-payload`
  - evidence: browser real mantiene `sid == ws_session_id` y fingerprint persistido
  - confidence: medium
  - blast radius: fragilidad ante cambios futuros del backend

Prioritized Fix Plan
- priority: P0
  - resolver/host: Anime Nexus
  - change: mantener proxy HLS local como via obligatoria; no exponer CDN URLs firmadas directo al player
  - why now: el anti-replay ya esta probado
  - tests/fixtures to add: test de expiracion/reintento de segment token; fixture de manifest firmado con `requestType`, `sessionId`, `segmentPath`

- priority: P0
  - resolver/host: Anime Nexus
  - change: preservar extraccion de `attestRef` desde HTML SSR crudo y endurecer tests para reject claro si no aparece
  - why now: es condicion necesaria para autenticacion real
  - tests/fixtures to add: fixture HTML SSR con `attestRef` y fixture negativa sin `attestRef`

- priority: P1
  - resolver/host: Anime Nexus
  - change: dejar explicito en el modelo de sesion que `sid`, `ws_session_id` y fingerprint forman parte del contrato real observado
  - why now: el sitio ya persiste esos valores y el resolver deberia reflejarlo mejor
  - tests/fixtures to add: tests de serializacion/consistencia de `NexusBrowserSession`

- priority: P1
  - resolver/host: Anime Nexus
  - change: agregar hardening de rotacion de token y re-fetch puntual para seek/replay
  - why now: el anti-replay ya se manifiesta en segmentos repetidos
  - tests/fixtures to add: tests del worker/proxy ante `403` de segmento y renovacion de token

- priority: P2
  - resolver/host: Anime Nexus
  - change: capturar artefactos runtime reproducibles para fixtures del canal websocket y challenge reset
  - why now: la arquitectura actual ya coincide, pero falta fixture real para futuros cambios del host
  - tests/fixtures to add: fixture de frames websocket y transiciones `connected/reset-challenge/authentication-error`

Validation
- format: no aplica; no hubo cambios de codigo, solo auditoria documental
- analyze: no aplica
- tests: no aplica
- runtime re-check:
  - Playwright contra `anime.nexus/` y watch page real
  - Chrome remoto via `adb forward tcp:9222 localabstract:chrome_devtools_remote`
  - confirmada disponibilidad de Chrome Android remoto
- residual risk:
  - no se capturo un dump crudo de frames websocket desde navegador en esta pasada
  - no se inspecciono APK nativo porque el target auditado fue la web/player runtime
  - `mitmproxy` y `frida` estan disponibles, pero no fueron necesarios para probar el contrato principal

Conclusions
- Anime Nexus usa una proteccion por capas:
  - HTML SSR con `attestRef`
  - bootstrap API
  - identidad de sesion/dispositivo persistida
  - seleccion dinamica de edge CDN
  - manifests y segmentos firmados por request
  - rotacion o no reutilizacion segura de tokens de segmento
  - plano de control en el player para pedir tokens
- El resolver actual de Kumoriya esta conceptualmente bien orientado.
- El punto critico no es descubrir un URL final "secreto", sino respetar el contrato de sesion y renovacion de tokens.
