# TODO — Sync cross-device vía FCM silent push (Fase B)

- **Estado:** Pospuesto (Fase A entregada 2026-04-23 cierra el 80% del caso).
- **Área:** `kumoriya-api` (backend Go) + `apps/kumoriya_app` (cliente Flutter).
- **Dependencias nuevas probables:** ninguna del lado cliente (FCM ya está
  montado vía `firebase_messaging`); backend necesita cliente FCM Admin SDK
  (Go) o llamada HTTP v1 directa.
- **Riesgo principal:** delivery best-effort de FCM en Doze; auto-notificación
  si no se implementa correctamente el self-echo protection por `device_id`.

## Contexto

Tras la Fase A del `SyncCoordinator`, un cambio hecho en el dispositivo A se
ve en el dispositivo B únicamente cuando B:

1. Abre la app (trigger resume → `triggerPull`), o
2. Está con la app abierta y llega al siguiente tick del timer periódico de
   30 min en foreground.

Hay un hueco de hasta ~29 min en el caso peor con app foreground, y
potencialmente ilimitado si B está backgrounded o dormido. FCM silent push
cierra ese hueco a latencia de segundos con coste batería casi cero.

Ya existe toda la infra FCM en el cliente:

- `apps/kumoriya_app/lib/src/shared/notifications/fcm_service.dart`
- `apps/kumoriya_app/lib/src/shared/notifications/fcm_topic_sync_service.dart`
- `kumoriyaFcmBackgroundHandler` ya registrado en `main.dart`
- `SyncCoordinator.triggerPull()` ya expuesto como hook

## Alcance propuesto

### Backend (`kumoriya-api`)

1. **Device registry**: tabla nueva.
   ```sql
   CREATE TABLE sync_devices (
     user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     device_id  TEXT NOT NULL,           -- hash estable del cliente
     fcm_token  TEXT NOT NULL,
     platform   TEXT NOT NULL,           -- 'android' | 'ios' | 'windows'
     last_seen  TIMESTAMPTZ NOT NULL,
     PRIMARY KEY (user_id, device_id)
   );
   ```
2. **Endpoint** `POST /api/v1/sync/devices/register` con
   `{device_id, fcm_token, platform}` — upsert, actualizar `last_seen`.
3. **Self-echo header** `X-Kumoriya-Device-Id` obligatorio en `/sync/push`.
4. **Fanout tras push exitoso**: enviar FCM data-only a todos los
   `sync_devices` del `user_id` **excepto** el `device_id` del origen. Payload:
   ```json
   {"type": "sync_invalidate", "seq": <push_request_id>}
   ```
   Data-only (sin `notification`) para no molestar al usuario y permitir
   wake-up en Android.
5. **Limpieza periódica**: cronjob que borra devices con `last_seen` > 60
   días.

### Cliente (`apps/kumoriya_app`)

1. **`device_id` estable**: generar en primer arranque con
   `installation_id` + hash + persistir en `SecureTokenStore`. No
   ANDROID_ID (no estable tras factory reset, y expone fingerprint).
2. **Registro en login + refresh FCM token**: llamar a
   `/api/v1/sync/devices/register` desde `FcmTopicSyncService` cuando haya
   token listo y sesión autenticada.
3. **Header en push**: `AuthenticatedHttpClient` añade `X-Kumoriya-Device-Id`
   a todas las requests (o solo a `/sync/push`; decidir al implementar).
4. **Handler FCM data-only**: `kumoriyaFcmBackgroundHandler` y el foreground
   handler ramifican por `data['type']`. Si `sync_invalidate`:
   - Si app en foreground → `ref.read(syncCoordinatorProvider).triggerPull()`.
   - Si backgrounded → `Workmanager().registerOneOffTask(kPushPendingSyncTask)`
     con variante `pullOnly` (requiere un segundo nombre de task o un
     flag en `inputData`).
5. **Deduplicación por `seq`**: guardar los últimos 16 seq vistos en memoria
   para ignorar entregas duplicadas (FCM garantiza al-menos-una-vez).

## Gate de aceptación

- Device A cambia favorito → device B (foreground o background, con red)
  muestra el cambio en <10 s p95.
- Device A **no** recibe su propia invalidación (self-echo filtrado por
  `device_id`).
- Factory reset en device A no deja fantasma en la tabla (cronjob limpia
  tras 60 días sin `last_seen`).
- Tests unitarios nuevos:
  - Backend: fanout excluye al origen; respeta `device_id`.
  - Cliente: handler FCM dedupe por `seq`; ramifica a `triggerPull` vs
    WorkManager según lifecycle.

## Lo que **no** entra en esta slice

- iOS (requiere APNs; no hay app iOS todavía).
- Windows: no hay camino razonable vía FCM/Flutter desktop. Queda cubierto
  por el timer de foreground ya existente. Abrir TODO separado si surge.
- SSE/WebSocket como alternativa. Ya descartados en Fase A con razonamiento
  de batería + Android Doze (ver `docs/dev-diary/2026-04-23.md`).

## Referencias

- Coordinador y hook listo: `apps/kumoriya_app/lib/src/shared/sync/sync_coordinator.dart`
  (método `triggerPull()`).
- Self-echo verificación Fase A:
  `kumoriya-api/internal/service/sync_service.go:133` (`pullCore`).
- Plan original con tradeoffs:
  `/home/reny/.windsurf/plans/sync-coordinator-slice-e096b6.md`
- Dev-diary Fase A: `docs/dev-diary/2026-04-23.md` (sección "Fase A").

## Estimación

- Backend: 2-3 días (tabla + endpoint + fanout + tests).
- Cliente: 1-2 días (device_id + register + handler + dedupe + tests).
- QA cross-device manual: 0.5 día.
