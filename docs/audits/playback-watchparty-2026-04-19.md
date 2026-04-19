# Auditoría — Resolvers, Pipeline de Reproducción y Watch Party

**Fecha:** 2026-04-19
**Alcance:** Resolvers habilitados (excluye AnimeNexus), pipeline de reproducción (Continue Watching, next/prev, orchestrator) y cambio de episodio del host en Watch Party.
**Fuentes:** Inventario de resolvers en `apps/kumoriya_app/lib/src/features/anime_catalog/application/services/plugin_runtime_catalog.dart:34-59`.

---

## 1. Resolvers — Problemas identificados

### 1.1 Transversales

- **Auto-queue paralelo sin presupuesto global.** `StartEpisodePlaybackUseCase` corre todos los candidatos del auto-queue en paralelo (`apps/kumoriya_app/lib/src/features/anime_catalog/application/use_cases/start_episode_playback_use_case.dart:120-184`). Si N resolvers fallan rápido y 1 es lento, el usuario espera el timeout completo del más lento sin feedback UI.
- **Caché de host en `ResolverRegistry` nunca se invalida** (`apps/kumoriya_app/lib/src/features/anime_catalog/application/services/resolver_registry.dart:28-69`). Un mirror nuevo o cambio de soporte exige reiniciar la app.
- **Errores de parse clasificados como transport.** En Okru y Filemoon el `jsonDecode` queda dentro del `try` externo que solo produce `*TransportError`. Contamina telemetría y engaña la lógica de retry.
- **Regex `_*DirectRe` demasiado laxos** en StreamWish/VidHide/Filemoon/YourUpload. Capturan URLs de ads/trackers con `.mp4` o `.m3u8`.
- **`http.Client` sin Cronet en rutas no-DI.** Solo `resolverHttpClientProvider` inyecta Cronet. Tests, CLI y flujos manuales quedan sin.

### 1.2 Por host

- **JKPlayer / JK UM**
  - `_jkDirectRe` captura cualquier URL, filtra por extensión después.
  - `JkPlayerJk` (`/jkplayer/jk`) usa `allowUnknownExtension: true` → acepta URLs que pueden no ser media.
  - `qualityLabel` suele quedar `unknown`/`auto` porque el CDN no expone resolución en path → ranking de calidad irrelevante.

- **Streamwish** (`packages/kumoriya_resolver_streamwish/lib/src/streamwish_resolver_plugin.dart`)
  - Fallback paralelo a mirrors dispara también en 410/451/404 — casi siempre inútil y duplica 6 requests para confirmar el fallo.
  - No desempaca el patrón `eval(function(p,a,c,k,e,d){…})` pese a existir `kumoriya_resolver_common/dean_edwards_unpacker.dart`.

- **Pixeldrain** (`packages/kumoriya_resolver_pixeldrain/lib/src/pixeldrain_resolver_plugin.dart`)
  - MIME forzado a `video/mp4` sin leer Content-Type.
  - Sin `User-Agent`/`Referer`.

- **Streamtape** (`packages/kumoriya_resolver_streamtape/lib/src/streamtape_resolver_plugin.dart`)
  - Único path fiable es `_stTokenRe`; rotaciones frecuentes del patrón sin fixture por variación.
  - `_stDirectRe` solo acepta `.mp4` (pierde eventuales `.m3u8`).
  - Streams emitidos sin `User-Agent`.

- **Doodstream** (`packages/kumoriya_resolver_doodstream/lib/src/doodstream_resolver_plugin.dart`)
  - Doble round-trip obligatorio (embed + pass_md5) con 2×8s → hasta 16s para declarar fallo.
  - URL final no se verifica (HEAD/Range) antes de entregarse.
  - `qualityLabel` siempre `unknown` pese a que `dsplayer` lo expone.

- **YourUpload** (`packages/kumoriya_resolver_yourupload/lib/src/yourupload_resolver_plugin.dart`)
  - Regex de URL muy amplio; filtra solo por extensión, no por host.
  - Sin validación de MIME real.

- **OK.ru** (`packages/kumoriya_resolver_okru/lib/src/okru_resolver_plugin.dart`)
  - `jsonDecode` sin try/catch local → cualquier cambio de esquema se reporta como `OkruTransportError`.
  - Sin detección de geobloqueo.

- **Upnshare** (`packages/kumoriya_resolver_upnshare/lib/src/upnshare_resolver_plugin.dart`)
  - Clave AES y IV hardcoded (`kiemtienmua911ca` / `1234567890oiuytr`). Rotación upstream requiere nueva release.
  - UA trivial (`Mozilla/5.0`), probable flag para endurecimientos futuros.

- **Zilla Networks** (`packages/kumoriya_resolver_zilla/lib/src/zilla_resolver_plugin.dart`)
  - GET completo del manifest M3U8 solo para validar `#EXTM3U`. `HEAD` o `Range` bastarían.
  - `Referer` inusual (`origin + path`).

- **Filemoon** (`packages/kumoriya_resolver_filemoon/lib/src/filemoon_resolver_plugin.dart`)
  - Flujo dinámico (`/api/videos/{code}/embed/playback`) gateado por lista estática de hosts. Mirror nuevo = no detectado.
  - Cipher AES-GCM construido cada invocación (coste bajo pero evitable).

- **VidHide** (`packages/kumoriya_resolver_vidhide/lib/src/vidhide_resolver_plugin.dart`)
  - No desempaca packer, aunque los hints lo detectan.
  - Sin Content-Length puede cargar más de 5 MB.

- **MediaFire** (`packages/kumoriya_resolver_mediafire/lib/src/mediafire_resolver_plugin.dart`)
  - Marcado como `streamResolution` pero es download-only. Ocupa slot del auto-queue con un MP4 sin Range confiable.
  - Hasta 5 redirects manuales × 8s = 40s peor caso.

---

## 2. Pipeline de reproducción — Problemas identificados

Archivo principal: `apps/kumoriya_app/lib/src/features/player/presentation/pages/player_page.dart`.

### 2.1 Continue Watching (Home)

- **Race en `_handleResumeTap`** (`apps/kumoriya_app/lib/src/features/anime_catalog/presentation/pages/home_page.dart:619-670`). Sin cancelación: si el usuario navega hacia atrás mid-preparo, la decisión sigue ejecutándose y puede dejar loaders colgados.
- **`allowAutomaticResolution: true` por defecto** rompe afinidad de servidor: si el preferido falla, salta a otro → posición de resume puede quedar descalibrada cuando los servidores cortan OP/ED distinto.

### 2.2 Botones Next / Prev en el player

- **`_openPreviousEpisode` requiere `int.tryParse` del número de episodio** (líneas 1265-1274). Episodios fraccionales (0.5, 7.5) no disparan el botón.
- **`_hasNextEpisode` devuelve `true` cuando `totalEpisodes == null`** (líneas 140-144). Si AniList falla en cargar el total, la app ofrece "next" inexistente.
- **`_openAdjacentEpisode` usa `allowAutomaticResolution: false`** (línea 1318). Next/Prev del player nunca auto-resuelven → siempre abren selector de servidor. Inconsistente con Continue Watching. **Principal causa de la sensación de "tosco"**.
- **Pausa pre-selector no persiste**. `_prepareForEpisodeReplacement` cancela `_positionSub` antes del flush → la última posición guardada es la del segundo previo al tap.
- **Auto-next residual (AniSkip ending)**: `_autoNextTriggeredByEndingResidual` no se resetea si el siguiente episodio falla (`unavailable`). Usuario no puede reintentar sin cerrar el player.
- **`_replaceWithResolvedPlayer` usa `Navigator.of(context).pushReplacement`** (no `rootNavigator: true`, línea 1492). Inconsistencia con el push inicial → navegación de retorno impredecible.
- **`_saveCurrentProgress` aún in-flight al montar el nuevo `PlayerPage`**: `_pendingProgressFlush` no se awaitea entre instancias → el nuevo instance puede leer valor obsoleto.

### 2.3 Orchestrator y engine

- **`_autoQualityDownshiftBuffering: 5s` agresivo** frente a `_autoQualityStableFor: 25s`. En redes con jitter provoca ciclos 360p↔auto percibidos como "tosco".
- **Tolerancia total de seek de 13s** (`_seekReadyBudget 8s` + `_seekVisualGateMax 5s`). Excesivo para `m3u8` de StreamWish y similares.

---

## 3. Watch Party — Cambio de episodio del host

Archivos:
- `apps/kumoriya_app/lib/src/features/watch_party/presentation/pages/party_episode_list_page.dart`
- `apps/kumoriya_app/lib/src/features/watch_party/presentation/pages/party_anime_page.dart`
- `apps/kumoriya_app/lib/src/features/watch_party/application/providers/party_providers.dart`
- `apps/kumoriya_app/lib/src/features/player/presentation/pages/player_page.dart`
- `infra/watch-party-realtime/src/durable-objects/PartyRoomDO.ts`

### 3.1 Secuencia actual

1. Host toca episodio → `notifier.changeMedia(...)` (`party_episode_list_page.dart:146-152`).
2. `changeMedia` actualiza estado local optimista, manda `media_change` intent al Worker y retorna (`party_providers.dart:466-526`).
3. Inmediatamente después el host llama `startEpisodePlaybackUseCase` y `handlePlaybackDecision` → abre un nuevo `PlayerPage`.
4. En paralelo, el Worker procesa `media_change`: resetea playback, resetea ready de todos y difunde `media_changed` (`PartyRoomDO.ts:893-925`).
5. Cada cliente recibe `media_changed` → `_handleRealtimeMediaChanged` invoca `onMediaChangeNavigation` (`party_providers.dart:896-916`) → pop+push `PartyAnimePage`.
6. El nuevo `PlayerPage` del host, en post-frame callback, emite `source_selected` (`player_page.dart:178-182`, `_broadcastSourceSelectionIfHost:197-238`).
7. Miembros en `PartyAnimePage` reciben `source_selected` y auto-resuelven.

### 3.2 Problemas identificados

- **Callback `onMediaChangeNavigation` es slot único global** (`party_providers.dart:191`). Si PlayerPage + PartyLobbyPage coexisten, el último en registrar callback gana → el otro pierde la navegación.
- **Race `source_selected` vs `PartyAnimePage.initState`** (confirmado). Host resuelve rápido → `source_selected` llega antes de que el miembro monte `PartyAnimePage` → callback aún null → evento perdido. **`_latestSourceSelection` se guarda pero `PartyAnimePage.initState` NO lo drena al registrar el callback.** Fix trivial, gran UX.
- **Optimistic update sin ack**. Si el Worker rechaza el intent (versión de room, rate limit, desconexión), el host avanza solo; los miembros siguen en el episodio viejo. Sin reconciliación.
- **Host no pausa el player viejo** antes de `changeMedia` en la ruta desde `party_episode_list_page` → parpadeo de audio hasta que monta el nuevo.
- **Doble navegación en miembros**: `media_changed` + `episode_changed` pueden coexistir → doble `pushReplacement`. El guard "already on target" (`player_page.dart:560-575`) solo cubre el caso de misma ruta.
- **Reset de ready vs `toggleReady(true)` del host**: el Worker emite `member_ready_changed=false` para todos; el host, al montar el nuevo `PlayerPage`, llama `toggleReady(true)` (`player_page.dart:646-656`). Según orden de llegada, el host puede verse momentáneamente como "no ready" → se activa pause hold y muestra "Esperando a que todos carguen".
- **`_broadcastSourceSelectionIfHost` en `addPostFrameCallback`** abre ventana de pérdida del `source_selected` si el miembro aún no monta la nueva página.
- **`_handlePartySourceSelected` con debounce de 1.5s** (`party_anime_page.dart:92-97`) puede tragarse el primer evento si el callback se registra justo después de llegar.
- **`episode_change` siempre resetea ready de todos** (`PartyRoomDO.ts:927-952`). Cada "next" del host en sesión larga obliga a re-ready a todos. Fricción innecesaria.
- **Sin diferencia entre iniciador y receptores del intent**. El host recibe el echo de su propio reset → UI del host confundida.

---

## 4. Ranking por impacto (mayor → menor)

1. Drenar `_latestSourceSelection` al registrarse el callback en `PartyAnimePage.initState` (fix trivial, resuelve el caso más visible de "tosco" en party).
2. Excluir MediaFire del auto-queue de streaming (mantenerlo solo en download pipeline).
3. Cambiar Next/Prev del player a `allowAutomaticResolution: true` para alinearlo con Continue Watching.
4. StreamWish: cortocircuito de fallback en 410/451/404 + activación del `dean_edwards_unpacker`.
5. Pausar el player viejo antes de `changeMedia` desde la lista de episodios.
6. No resetear el ready state del host cuando él mismo origina el `media_change` / `episode_change`.
7. Clasificar correctamente errores de parse vs transport (Okru, Filemoon dinámico).
8. Reducir timeouts de Doodstream (5s por salto) y validar la URL final antes de entregarla.
9. No cachear `ResolverNotFound` en `ResolverRegistry` si el host está en `supportedHosts` de algún resolver cargado.
10. Overall timeout del auto-queue con feedback UI ("probando servidor X…").

---

## 5. Siguientes pasos sugeridos

- Convertir los ítems 1, 3 y 5 del ranking en una primera PR pequeña (fixes con superficie baja y alto impacto UX).
- Tratar ítems 2, 4, 6 como slice independiente (tocan policy del auto-queue y semántica del Worker).
- Resto como backlog de hardening.

---

## 6. Estado de implementación (2026-04-19)

### Aplicado

| # | Fix | Archivos |
|---|-----|----------|
| 1 | Drenar `_latestSourceSelection` en `PartyAnimePage.initState` | `party_anime_page.dart:35-112` |
| 2 | Excluir MediaFire del auto-queue (solo download) | `start_episode_playback_use_case.dart:31-63,344-397` |
| 3 | Next/Prev del player: `allowAutomaticResolution: true` + parse de episodios fraccionales | `player_page.dart:1306-1388` |
| 4 | StreamWish: cortocircuito fallback en 403/404/410/451 | `streamwish_resolver_plugin.dart:37-135` |
| 4b | StreamWish: desempaquetado Dean-Edwards (vía `buildExtractionPayload`) ya activo también en VidHide | `streamwish_resolver_plugin.dart:138`, `vidhide_resolver_plugin.dart:121` |
| 5 | Pausar player stale cuando cambia la room (corta audio en host al iniciar `media_change`) | `player_page.dart:120-147,281-302` |
| 6 | Exentar al host del reset de ready en `media_change` / `episode_change` | `PartyRoomDO.ts:840-960,1073-1117` |
| 7 | Separar parse vs transport errors en Okru y Filemoon | `okru_resolver_plugin.dart:50-133`, `filemoon_resolver_plugin.dart:80-191` |
| 8 | Doodstream: timeouts 8s→6s por fase + separar parse/transport | `doodstream_resolver_plugin.dart:107-248` |
| 9 | `ResolverRegistry` no cachea `ResolverNotFound` | `resolver_registry.dart:39-71` |
| 10 | Auto-queue: timeout global 15s | `start_episode_playback_use_case.dart:344-397` |
| +  | Loader bloqueante fantasma: `hideBlockingLoader` incondicional en `_handleResumeTap` y rutas de player | `home_page.dart:612-685`, `player_page.dart:1413-1442` |

### Hardening aplicado (segunda pasada)

| Fix | Archivos |
|-----|----------|
| `_hasNextEpisode` devuelve `false` cuando `totalEpisodes == null` (no ofrece "next" fantasma) | `player_page.dart:146-157` |
| `_replaceWithResolvedPlayer` / `_openEpisodeListReplacement` usan `rootNavigator: true` | `player_page.dart:1564,1587` |
| `_prepareForEpisodeReplacement` drena `_pendingProgressFlush` antes de reemplazar | `player_page.dart:1604-1621` |
| Pixeldrain: UA/Referer en request + stream headers, separación transport/parse, extracción de `mime_type` real | `pixeldrain_resolver_plugin.dart:44-130,177-206` |
| Streamtape: UA en headers compartidos, separación transport/parse, `_stDirectRe` acepta `.m3u8` | `streamtape_resolver_plugin.dart:93-167,175-179` |
| YourUpload: allow-list de hosts (`yourupload.com` + `vidcache.net`) en extractor + separación transport/parse | `yourupload_resolver_plugin.dart:63-137,181-195` |
| Zilla: `Range: bytes=0-1023` en vez de GET completo del manifest + acepta 206 | `zilla_resolver_plugin.dart:57-115` |

### Pendiente (backlog de hardening)

- **Continue Watching**: token de cancelación en `_handleResumeTap` (refactor amplio; hoy cubierto en UX por loader raíz + `mounted` guards).
- **`_autoNextTriggeredByEndingResidual`**: resetear cuando el siguiente episodio queda `unavailable`.
- **Orchestrator**: `_autoQualityDownshiftBuffering` 5s→10s y revisar `_seekVisualGateMax` 5s→3s.
- **Doodstream**: validar URL final con `HEAD`/`Range` antes de entregarla.
- **Filemoon**: descubrimiento dinámico de hosts en vez de lista estática.
- **Watch Party**: ack de `changeMedia` con reconciliación si el Worker rechaza.
- **Watch Party**: deduplicar `media_changed` + `episode_changed` con un único push.
- **Watch Party**: callback `onMediaChangeNavigation` como stream en vez de slot único.

