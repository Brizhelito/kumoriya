# TODO — Voice chat en la Watch Party

- **Estado:** Pospuesto (saturación de scope actual).
- **Área:** `apps/kumoriya_app/lib/src/features/watch_party`
- **Dependencias nuevas probables:** `permission_handler` (ya evaluable),
  TURN de producción (Coturn propio / Twilio / Metered).
- **Riesgo principal:** calidad de TURN y manejo de background en Android.

## Contexto

La Watch Party ya tiene toda la infraestructura P2P (signaling + WebRTC full-mesh
+ DataChannels) funcionando para sync de reproducción, reacciones, ready y kick.
El único rastro de voice chat en el código es un comentario en
`party_sync_engine.dart` indicando que reemplazaría al chat de texto eliminado.
**No hay nada de audio implementado.**

## Lo que ya está hecho (reutilizable)

- **Signaling WebSocket** con reconexión exponencial y keepalive cada 20s:
  `apps/kumoriya_app/lib/src/features/watch_party/infrastructure/signaling_client.dart`
- **Relay** en Cloudflare Durable Object:
  `infra/watch-party-realtime/src/durable-objects/PartyRoomDO.ts`
- **WebRTC peer manager full-mesh (máx 4 peers)** con STUN + TURN (OpenRelay),
  ICE buffering, onConnectionState, onDataChannel:
  `apps/kumoriya_app/lib/src/features/watch_party/infrastructure/webrtc_peer_manager.dart`
- **Sync engine y modelo `P2PMessage`** para sync/reactions/ready/kick/mediaChange:
  `apps/kumoriya_app/lib/src/features/watch_party/application/party_sync_engine.dart`
  `apps/kumoriya_app/lib/src/features/watch_party/application/models/p2p_message.dart`
- `flutter_webrtc` ya está instalado — la API `MediaStream` / `addTrack` está
  disponible sin nuevas dependencias nativas.
- UI de lobby y player-page con callbacks wired:
  `apps/kumoriya_app/lib/src/features/watch_party/presentation/pages/party_lobby_page.dart`

## Lo que falta

### 1. Captura de audio local

- Añadir `permission_handler` (o usar el de `flutter_webrtc`) y solicitar
  `Permission.microphone`.
- Declarar permisos nativos:
  - **Android:** `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT`
    en `AndroidManifest.xml`.
  - **iOS:** `NSMicrophoneUsageDescription` en `Info.plist`.
  - **Windows:** capability de micrófono en el manifest.
- `navigator.mediaDevices.getUserMedia({audio: {echoCancellation, noiseSuppression, autoGainControl}, video: false})`.

### 2. Negociación WebRTC con tracks

Hoy `WebRtcPeerManager` **solo crea DataChannels**. Para audio:

- Antes de `createOffer` / `createAnswer`, hacer
  `pc.addTrack(audioTrack, localStream)` para cada peer.
- Manejar `pc.onTrack` para recibir el `MediaStreamTrack` remoto y enrutarlo a
  reproducción.
- Renegociación cuando un peer activa/desactiva su mic (offer/answer extra, o
  `replaceTrack` con null).
- Garantizar SDP con `m=audio` Opus y que la política ICE siga funcionando con
  TURN. **OJO: STUN-only fallará en NAT simétricas; ExpressTurn free no es
  confiable para producción de audio.**

### 3. Playout del audio remoto

- En móvil `flutter_webrtc` reproduce audio remoto en cuanto `onTrack` llega y
  el stream se mantiene referenciado (guardar el `MediaStream` para evitar GC).
- **Ducking**: decidir si se baja el volumen de `media_kit` cuando alguien
  habla, o se deja al usuario.
- **Ruteo de salida** (auricular/altavoz/BT): exponer
  `Helper.setSpeakerphoneOn` de `flutter_webrtc`.

### 4. Control de sesión y UX

- Estado por peer: `isMuted`, `isSpeaking` (vía `getStats()` con `audioLevel`).
- Botones: toggle mic, mute-all (host), indicador de "hablando" en los avatares
  del lobby y del player.
- Nuevo tipo en `P2PMessage`: `voiceState` (muted/unmuted/speaking) para UI. El
  track va por SDP, no por DataChannel.
- Política de entrada: **mute por defecto**, toggle manual. (Push-to-talk
  opcional v2.)

### 5. Calidad y robustez

- Máx 4 peers en mesh soporta audio sin problema (3 uplinks Opus ~96 kbps).
- Hoy si `onConnectionState` → `failed` solo se marca desconectado. Para voz
  hay que reintentar ICE restart o recrear el offer.
- **TURN de producción** obligatorio antes de lanzar: cambiar
  `relay1.expressturn.com` por Coturn propio / Twilio / Metered.

### 6. Plataformas

- **Windows** con `flutter_webrtc`: funciona pero requiere validación, no
  asumir que sale gratis.
- **Background en Android**: si el usuario minimiza la app, el audio debe
  seguir. Requiere `foreground service` con tipos `microphone` y
  `mediaPlayback` (Android 14+ obliga a declararlos).

### 7. Pruebas

- Unit test de `VoiceChatController` (mute/unmute, addTrack/replaceTrack).
- Integración con dos peers locales (o smoke manual entre dos dispositivos).
- Smoke de permisos denegados: debe degradar a "sin voz", no romper la party.

## Propuesta de implementación (cuando se retome)

Tratarlo como **vertical slice propio** en un `VoiceChatController` nuevo que
**componga** al `WebRtcPeerManager` existente sin tocar la lógica de sync.

- Nuevo archivo: `apps/kumoriya_app/lib/src/features/watch_party/infrastructure/voice_chat_controller.dart`
- Extender `WebRtcPeerManager` con hooks opcionales para `addTrack` antes de
  crear offer/answer, y un callback `onRemoteTrack`.
- Nuevo provider Riverpod `voiceChatProvider` enlazado al `partySessionProvider`.
- UI: widget de mic toggle en `party_lobby_page.dart` y en el overlay del player.

## Estimación

~3-5 días de trabajo enfocado, asumiendo TURN de producción ya contratado.

## Decisiones pendientes (bloqueantes antes de retomar)

1. ¿Qué TURN se usará en producción? (coste/host)
2. ¿Voice chat entra en v0.2 o se difiere a v0.3?
3. ¿Push-to-talk en v1 o solo mute toggle?
4. ¿Se implementa ducking automático del player o se deja manual?
