# AniList decorator — null-window guard en `fetchAiringCalendar`

Estado: **Pospuesto** — bug latente sin impacto actual. Arreglar cuando alguna
nueva feature vaya a consumir `fetchAiringCalendar` / `fetchAiringCalendarSlots`.

## Contexto

`BackendFirstAnilistMetadataGateway._backendAiringLoop`:

```dart
final fromDate = (from ?? DateTime.now()).toUtc();
final toDate   = (to ?? fromDate.add(const Duration(days: 7))).toUtc();
final greater  = fromDate.millisecondsSinceEpoch ~/ 1000;
```

Si un caller futuro llama `fetchAiringCalendar()` sin `from`/`to`, cada
invocación usa un `DateTime.now()` distinto al segundo → timestamps distintos
→ cache key distinta en el backend → **cache miss 100%**, efectivamente
golpeando AniList en cada llamada.

## Estado actual

- `calendarCatalogProvider` → pasa `from` explícito (`startOfLocalCalendarWeek`).
- `calendarMonthSlotsProvider` → pasa `from` explícito (`DateTime(y,m)`).
- No hay otros callers. La rama `?? DateTime.now()` **no se ejecuta hoy**.

## Qué falta

Endurecer el decorator para que el fallback sea predecible:

```dart
final fromDate = from?.toUtc() ?? _bucketedNowUtc();
final toDate   = to?.toUtc()   ?? fromDate.add(const Duration(days: 7));

/// Trunca `now()` al bucket de 5 min para que clientes coincidentes
/// compartan cache key en el backend aunque llamen sin `from`.
DateTime _bucketedNowUtc() {
  final now = DateTime.now().toUtc();
  final bucketMs = 5 * 60 * 1000;
  final truncated = (now.millisecondsSinceEpoch ~/ bucketMs) * bucketMs;
  return DateTime.fromMillisecondsSinceEpoch(truncated, isUtc: true);
}
```

Opcional (debug mode): `assert` que loggea un warning si alguien llama sin
`from` → fuerza a pensar en la ventana correcta antes de que llegue a prod.

## Tests

- Unit test: dos llamadas `fetchAiringCalendar()` sin args dentro del mismo
  bucket → misma URL enviada al backend (mismo `airingAtGreater`).
- Unit test: dos llamadas separadas por > 5 min → URLs distintas (bucket
  distinto).

## Enlaces

- `apps/kumoriya_app/lib/src/shared/anilist_backend/backend_first_anilist_gateway.dart:152-165`
- `apps/kumoriya_app/test/backend_first_anilist_gateway_test.dart`
