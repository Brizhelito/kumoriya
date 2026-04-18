# AniList Airing Calendar — canonical window + cross-TZ cache sharing

Estado: **Pospuesto** — el SWR cache actual funciona bien dentro de una misma
timezone cluster. Este trabajo solo se justifica cuando la base de usuarios
abandone LatAm o cuando las métricas muestren hit ratio bajo.

## Contexto

El cliente Flutter construye la ventana del calendar con
`DateTime(year, month)` (hora local) y la convierte a UTC antes de mandarla
al backend:

```dart
final from = DateTime(year, month);          // local midnight
final to   = DateTime(year, month + 1);      // local midnight next month
// decorator:
final greater = from.toUtc().millisecondsSinceEpoch ~/ 1000;
```

Resultado: dos usuarios en TZ distintas que piden "Junio 2026" mandan
timestamps distintos → cache keys distintas en el backend → **cada TZ paga
su propio cold-cache**.

Ejemplo:

| TZ        | `from` enviado (unix seconds) |
|-----------|------------------------------|
| UTC-6 MX  | `1764547200` (1 jun 06:00 UTC) |
| UTC-3 AR  | `1764536400` (1 jun 03:00 UTC) |
| UTC+9 JP  | `1764504000` (31 may 15:00 UTC) |

Hoy (usuarios en LatAm) esto agrupa a todos en 2-3 clusters, aceptable. Si
abrimos a Europa / Japón / USA-PST, la fragmentación crece.

## Qué hay hecho

- Endpoint `/v1/anilist/home/airing-calendar` ya acepta `airingAtGreater` y
  `airingAtLesser` como enteros arbitrarios.
- Decorator Flutter paginea contra el backend con fallback limpio a AniList
  directo.
- SWR prewarm caliente automáticamente la ventana `days=7` por defecto.

## Qué falta

### 1. Nuevo parámetro canónico de mes

Aceptar `?month=2026-06` en el handler. El server resuelve:

```go
startYear, startMonth := parseMonth("2026-06")
greater := time.Date(startYear, startMonth, 1, 0, 0, 0, 0, time.UTC).Unix()
lesser  := time.Date(startYear, startMonth+1, 1, 0, 0, 0, 0, time.UTC).Unix()
```

Cache key derivada de `month` → **una sola entrada global**.

Extender el contrato de `AiringCalendarRequest`:
- Nuevo campo `Month string` (formato `YYYY-MM`).
- Precedencia: `Month` > `AiringAtGreater/Lesser` > `Days`.
- Cache key: `calendar:m=2026-06:p1:n50`.

### 2. Cliente Flutter usa el nuevo parámetro

`AnilistHomeBackendClient.fetchAiringCalendar`:
- Nuevo método `fetchAiringCalendarByMonth(month: DateTime, page, perPage)`.
- `BackendFirstAnilistMetadataGateway.fetchAiringCalendar` detecta si
  `from`/`to` cubren exactamente un mes natural (`DateTime(y,m)` →
  `DateTime(y,m+1)` en local) y redirige al método por-mes; si no, usa el
  path por timestamps.

### 3. Prewarm ampliado en el backend

`Prewarmer` calienta `month=prev`, `month=current`, `month=next` cada 10 min.
Costo: ~18 páginas × 3 meses × 1 vez por refresh = ~54 AniList calls cada
10 min, bajo el budget de 85/min.

## Consideraciones

- **Semana del Home**: `calendarCatalogProvider` usa `startOfLocalCalendarWeek`,
  que NO es un mes. Se queda en el path por timestamps (día-preciso, TZ-sensible).
  Impacto bajo porque la ventana es solo 7 días y los clusters TZ ya absorben.
- **Compatibilidad**: el endpoint mantiene las 3 formas
  (`month` → `airingAt*` → `days`) con precedencia. Rollout sin breaking change.
- **Cache key migration**: al subir, las entradas antiguas (por timestamp)
  quedan huérfanas y expiran. No requiere invalidación manual.

## Enlaces

- Handler: `kumoriya-api/internal/anilist/handler/home_handler.go`
- Service: `kumoriya-api/internal/anilist/service/home_service.go`
- Client: `apps/kumoriya_app/lib/src/shared/anilist_backend/anilist_home_backend_client.dart`
- Decorator: `apps/kumoriya_app/lib/src/shared/anilist_backend/backend_first_anilist_gateway.dart`
- Arquitectura: `docs/architecture/notifications_and_auto_download.md`
