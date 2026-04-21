INSERT INTO app_releases (
    tag,
    version,
    channel,
    release_date,
    manifest_release_notes,
    summary_es,
    summary_en,
    notes_es_markdown,
    notes_en_markdown,
    android_url,
    android_file_name,
    android_r2_key,
    windows_url,
    windows_file_name,
    windows_r2_key,
    is_latest,
    created_at,
    updated_at
)
VALUES
(
    'v0.1.0',
    '0.1.0',
    'alpha',
    DATE '2026-03-30',
    'Initial public alpha release for Android and Windows.',
    'Primer lanzamiento publico alpha con distribucion para Android y Windows.',
    'Initial public alpha release for Android and Windows.',
    $es_v010$
# Lanzamiento v0.1.0

Fecha: 2026-03-30

## Resumen
- Primer lanzamiento publico alpha con distribucion para Android y Windows.

## Agregado
- Flujo inicial de actualizacion de app basado en `update.json` remoto.
- Aviso de actualizacion dentro de la app con notas de version.
- Descarga de APK en Android + transferencia a instalador del sistema.
- Transferencia a instalador EXE en Windows con cierre seguro de app.

## Cambios
- El proceso de release ahora tiene una convencion estandar de nombres por plataforma.
- Los metadatos de release ahora se centralizan mediante un manifiesto de version.

## Corregido
- Ninguno para el lanzamiento base.

## Notas de Migracion
- Ninguna.
$es_v010$,
    $en_v010$
# Release v0.1.0

Date: 2026-03-30

## Summary
- First public alpha release with Android and Windows distribution.

## Added
- Initial app update flow based on remote `update.json`.
- In-app update prompt with release notes.
- Android APK download + install handoff.
- Windows EXE installer handoff with safe app close.

## Changed
- Release process now has a standard artifact naming convention per platform.
- Release metadata is now centralized through a version manifest.

## Fixed
- None for baseline release.

## Migration Notes
- None.
$en_v010$,
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.0/kumoriya-0.1.0.apk',
    'kumoriya-0.1.0.apk',
    'artifacts/android/v0.1.0/kumoriya-0.1.0.apk',
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.0/Kumoriya-0.1.0-windows-x64-setup.exe',
    'Kumoriya-0.1.0-windows-x64-setup.exe',
    'artifacts/windows/v0.1.0/Kumoriya-0.1.0-windows-x64-setup.exe',
    FALSE,
    now(),
    now()
),
(
    'v0.1.1',
    '0.1.1',
    'alpha',
    DATE '2026-03-31',
    'Update, permissions, and download performance improvements.',
    'Mejoras de update, permisos y rendimiento de descarga.',
    'Update, permissions, and download performance improvements.',
    $es_v011$
# Lanzamiento v0.1.1

Fecha: 2026-03-31

## Resumen

Versión de parche enfocada en la identidad de Android, rendimiento de descarga,
flujo de permisos, localización, y mejoras internas de almacenamiento.

## Agregado

- **Descargador paralelo** — el APK de actualización ahora se descarga usando
  hasta 4 conexiones HTTP simultáneas con rangos de bytes (se divide
  automáticamente; si el servidor no soporta `Accept-Ranges: bytes`, vuelve
  al modo de descarga secuencial).
- **Cliente HTTP Cronet en Android** — el descargador de actualizaciones ahora
  usa el motor de red Cronet de Chrome en lugar del cliente HTTP integrado de
  Dart, lo que ofrece un rendimiento muy superior para archivos binarios grandes.
- Permiso `REQUEST_INSTALL_PACKAGES` declarado en `AndroidManifest.xml`.
- Permiso de almacenamiento de Android solicitado en el primer inicio, antes de
  mostrar el diálogo de selección de carpeta de descargas.
- Diálogo forzado de actualización en Ajustes (solo en builds de depuración) —
  permite probar el flujo completo de descarga e instalación sin necesitar una
  versión más reciente disponible en el servidor.
- Almacenamiento: cinco nuevas columnas en la caché de AniList —
  `synonyms`, `season`, `popularity`, `nextAiringEpisode`, `nextAiringAt`.
- Almacenamiento: cuatro nuevos métodos de consulta en el DAO —
  `getRecent`, `getByStatus`, `getByYearAndStatus`, `searchByTitle`.

## Cambios

- ID de aplicación de Android cambiado de `com.example.kumoriya_app` a
  `dev.kumoriya.app`.
- Nombre visible de la app cambiado de `kumoriya_app` a `Kumoriya`.
- Categoría de la app de Android configurada como `video`.
- Las builds de depuración usan `applicationIdSuffix = ".debug"`, lo que permite
  instalar la versión de depuración y la de producción al mismo tiempo en el
  mismo dispositivo. La etiqueta de depuración muestra `Kumoriya (DEBUG)`.
- El diálogo de carpeta de descargas en el primer inicio ahora está
  completamente localizado (ES + EN).
- Todas las peticiones HTTP de descarga de actualizaciones incluyen
  `Accept-Encoding: identity` para evitar que la CDN comprima el binario
  (garantiza un `Content-Length` correcto para el particionado en rangos).

## Corregido

- El instalador de actualizaciones fallaba en silencio cuando se denegaba el
  permiso `REQUEST_INSTALL_PACKAGES`. Ahora la app detecta la denegación y
  dirige al usuario a la configuración de permisos del sistema.
- El diálogo de selección de carpeta de descargas mostraba texto en inglés
  sin importar el idioma del dispositivo.

## Notas de Migración

- Las instalaciones existentes identificadas como `com.example.kumoriya_app`
  **no** se migran automáticamente a `dev.kumoriya.app`. Se requiere una
  desinstalación limpia y una reinstalación para adoptar la nueva identidad
  de paquete.
$es_v011$,
    $en_v011$
# Release v0.1.1

Date: 2026-03-31

## Summary

Patch release focused on Android identity, download performance, permissions flow,
localization, and internal storage improvements.

## Added

- **Parallel download accelerator** — update APK is now downloaded using up to 4
  simultaneous HTTP range requests (splits automatically, falls back to
  single-stream if the server does not advertise `Accept-Ranges: bytes`).
- **Cronet HTTP client on Android** — the in-app update downloader now uses
  Chrome's Cronet network engine instead of Dart's built-in HTTP client,
  providing significantly better throughput on large binary files.
- `REQUEST_INSTALL_PACKAGES` permission declared in `AndroidManifest.xml`.
- Android storage access permission requested on first launch, before showing
  the download folder selection dialog.
- Debug forced-update dialog in Settings (debug builds only) — allows testing
  the full download/install flow without needing a real newer version available.
- Storage: five new AniList cache columns — `synonyms`, `season`, `popularity`,
  `nextAiringEpisode`, `nextAiringAt`.
- Storage: four new DAO query methods — `getRecent`, `getByStatus`,
  `getByYearAndStatus`, `searchByTitle`.

## Changed

- Android application ID changed from `com.example.kumoriya_app` to
  `dev.kumoriya.app`.
- Android app display name changed from `kumoriya_app` to `Kumoriya`.
- Android app category set to `video`.
- Debug builds use `applicationIdSuffix = ".debug"` so debug and release
  packages can be installed side-by-side on the same device. Debug label
  displays as `Kumoriya (DEBUG)`.
- Download path dialog on first launch is now fully localized (ES + EN).
- All update download HTTP requests include `Accept-Encoding: identity` to
  prevent CDN-level compression on binary payloads (ensures accurate
  `Content-Length` for range splitting).

## Fixed

- Update installer failing silently when `REQUEST_INSTALL_PACKAGES` was denied.
  The app now detects the denial and directs the user to the system permission
  settings.
- First-launch download folder dialog showing English text regardless of device
  locale.

## Migration Notes

- Existing installs identified as `com.example.kumoriya_app` are **not**
  automatically migrated to `dev.kumoriya.app`. A clean uninstall and
  reinstall is required to adopt the new package identity.
$en_v011$,
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.1/kumoriya-0.1.1.apk',
    'kumoriya-0.1.1.apk',
    'artifacts/android/v0.1.1/kumoriya-0.1.1.apk',
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.1/Kumoriya-0.1.1-windows-x64-setup.exe',
    'Kumoriya-0.1.1-windows-x64-setup.exe',
    'artifacts/windows/v0.1.1/Kumoriya-0.1.1-windows-x64-setup.exe',
    FALSE,
    now(),
    now()
),
(
    'v0.1.2',
    '0.1.2',
    'alpha',
    DATE '2026-03-31',
    'Patch release focused on update visibility and release UX clarity.',
    'Version de parche enfocada en visibilidad de actualizacion y claridad en UX de release.',
    'Patch release focused on update visibility and release UX clarity.',
    $es_v012$
# Lanzamiento v0.1.2

Fecha: 2026-03-31

## Resumen

Versión de parche enfocada en visibilidad de actualización y claridad en UX de release.

## Agregado

- Configuración ahora muestra la versión instalada de la app en la sección **Aplicación**.

## Cambios

- Versión de la app actualizada a `0.1.2+3`.

## Corregido

- La verificación automática de actualización ahora se ejecuta al inicio en Android y Windows,
  para que usuarios en release detecten nuevas versiones sin depender de acciones solo debug.

## Notas de Migración

- Ninguna.
$es_v012$,
    $en_v012$
# Release v0.1.2

Date: 2026-03-31

## Summary

Patch release focused on update visibility and release UX clarity.

## Added

- Settings now shows the installed app version in the **App** section.

## Changed

- App version bumped to `0.1.2+3`.

## Fixed

- Automatic update check now runs at startup on Android and Windows,
  so release users can detect new versions without debug-only actions.

## Migration Notes

- None.
$en_v012$,
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.2/kumoriya-0.1.2.apk',
    'kumoriya-0.1.2.apk',
    'artifacts/android/v0.1.2/kumoriya-0.1.2.apk',
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.2/Kumoriya-0.1.2-windows-x64-setup.exe',
    'Kumoriya-0.1.2-windows-x64-setup.exe',
    'artifacts/windows/v0.1.2/Kumoriya-0.1.2-windows-x64-setup.exe',
    FALSE,
    now(),
    now()
),
(
    'v0.1.3',
    '0.1.3',
    'alpha',
    DATE '2026-04-01',
    'Alpha release with improvements in discovery, player behavior, matching, and AniList catalog flow.',
    'Version alpha con mejoras en exploracion, reproductor, matching y catalogo AniList.',
    'Alpha release with improvements in discovery, player behavior, matching, and AniList catalog flow.',
    $es_v013$
# Kumoriya v0.1.3 — Notas de Versión Alpha

**Fecha:** 2026-04-01

## Novedades

### Explorar y Descubrir
- **Página de Explorar Anime** — filtra por género, formato y orden con selección múltiple de géneros.
- **Buscador por Tags de AniList** — explora todos los tags de AniList organizados por categoría y encuentra anime que coincidan.
- **Descubrimiento Estacional Consolidado** — anime de temporada actual, próximos y recomendados en una sola consulta.

### Soporte y Feedback
- **Botón de Reporte de Bug** en Configuración — envía feedback directamente al equipo de desarrollo con contexto de errores automático.
- **Monitoreo de errores con Sentry** — rastreo silencioso de errores para diagnóstico más rápido.

### Mejoras del Reproductor
- **Acumulación de seek** — las zonas de doble-tap izquierda/derecha acumulan saltos de ±10s con indicador visual del Delta total. Las flechas del teclado también lo soportan.
- **Auto-next más seguro** — evita re-activaciones durante transiciones de página.
- **Mejor cierre del reproductor** — corrige condiciones de carrera al disponer el player.

### Matching de Anime
- **Normalización de honoríficos con guión** — "Hime-sama" ahora coincide correctamente con "Himesama".
- **Fallback de espejos StreamWish** — 3 nuevos hosts espejo para mejor disponibilidad de streams.

### AniList y Almacenamiento
- Consultas de colecciones de géneros y tags.
- Carga masiva de metadata de anime por IDs.
- Gestión de historial de reproducción (ver, eliminar, limpiar).
- Menos peticiones de red con consultas GraphQL consolidadas.

## Plataformas
- Android (APK)
- Windows (Instalador)
$es_v013$,
    $en_v013$
# Kumoriya v0.1.3 — Alpha Release Notes

**Date:** 2026-04-01

## What's New

### Browse & Discovery
- **Browse Anime Page** — filter by genre, format, and sort type with multi-genre selection.
- **Tag-Guided Anime Finder** — explore all AniList tags by category and find matching anime.
- **Consolidated Seasonal Discovery** — current-season, upcoming, and recommended anime in a single request.

### Support & Feedback
- **Bug Report Button** in Settings — send feedback directly to the dev team with automatic error context.
- **Sentry crash monitoring** — silent error tracking for faster bug diagnosis.

### Player Improvements
- **Seek accumulation** — double-tap left/right zones accumulate ±10s seeks with visual Delta indicator. Keyboard arrows also supported.
- **Safer auto-next** — prevents re-triggering during page transitions.
- **Better teardown** — fixes race conditions on player disposal.

### Anime Matching
- **Honorific-hyphen normalization** — "Hime-sama" now matches "Himesama" correctly.
- **StreamWish mirror fallback** — 3 new mirror hosts for improved stream availability.

### AniList & Storage
- Genre and tag collection queries.
- Batch anime metadata fetch by IDs.
- Watch history management (view, delete, clear).
- Fewer network round-trips with consolidated GraphQL queries.

## Platforms
- Android (APK)
- Windows (Installer)
$en_v013$,
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.3/kumoriya-0.1.3.apk',
    'kumoriya-0.1.3.apk',
    'artifacts/android/v0.1.3/kumoriya-0.1.3.apk',
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.3/Kumoriya-0.1.3-windows-x64-setup.exe',
    'Kumoriya-0.1.3-windows-x64-setup.exe',
    'artifacts/windows/v0.1.3/Kumoriya-0.1.3-windows-x64-setup.exe',
    FALSE,
    now(),
    now()
),
(
    'v0.1.4',
    '0.1.4',
    'alpha',
    DATE '2026-04-02',
    'Patch release focused on download cancellation, orphan cleanup, and HLS robustness.',
    'Version de parche enfocada en cancelacion de descargas, limpieza de huerfanos y robustez HLS.',
    'Patch release focused on download cancellation, orphan cleanup, and HLS robustness.',
    $es_v014$
# Kumoriya v0.1.4 — Notas de Versión Alpha

**Fecha:** 2026-04-02

## Resumen

Versión de parche enfocada en el comportamiento de la cola de descargas, la confiabilidad de la limpieza y un manejo más seguro en los resolvers.

## Agregado

- **Botón para limpiar la cola de descargas** — la pestaña de cola ahora incluye una acción con confirmación para eliminar todas las tareas pendientes y fallidas.

## Cambios

- **Feedback inmediato al cancelar** — las acciones de cancelar y limpiar ahora eliminan primero las tareas de la UI y del almacenamiento, mientras la limpieza de archivos sigue en segundo plano.

## Corregido

- **Retraso al cancelar en Descargas sobre Windows** — las tareas canceladas desaparecen de inmediato en lugar de esperar a que termine el borrado de carpetas grandes de segmentos HLS.
- **Limpieza de huérfanos HLS al iniciar** — las carpetas `*_segments` obsoletas se eliminan cuando ya no están asociadas a tareas activas.
- **Decodificación más segura en resolvers** — los plugins resolver usan UTF-8 tolerante a errores para evitar caídas con respuestas embed no UTF-8.
- **Refresh de descargas seguro tras unmount** — el refresh ahora protege `ref.invalidate()` después de gaps async para evitar `StateError` con widgets desmontados.

## Plataformas
- Android (APK)
- Windows (Instalador)
$es_v014$,
    $en_v014$
# Kumoriya v0.1.4 — Alpha Release Notes

**Date:** 2026-04-02

## Summary

Patch release focused on download queue behavior, cleanup reliability, and safer resolver handling.

## Added

- **Clear download queue button** — queue tab now includes a confirmation action to remove all pending and failed tasks.

## Changed

- **Immediate cancel feedback** — cancel and clear actions now remove tasks from the UI and store first, while artifact cleanup continues in the background.

## Fixed

- **Windows cancel delay in Downloads UI** — cancelled tasks now disappear immediately instead of waiting for large HLS segment folder deletion.
- **Startup orphan cleanup for HLS segments** — stale `*_segments` folders are pruned when they are no longer associated with active download tasks.
- **Safer resolver response decoding** — resolver plugins use malformed-safe UTF-8 decoding to avoid crashes on non-UTF-8 embed responses.
- **Unmount-safe downloads refresh** — downloads refresh now guards `ref.invalidate()` after async gaps to avoid `StateError` on unmounted widgets.

## Platforms
- Android (APK)
- Windows (Installer)
$en_v014$,
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.4/kumoriya-0.1.4.apk',
    'kumoriya-0.1.4.apk',
    'artifacts/android/v0.1.4/kumoriya-0.1.4.apk',
    'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.4/Kumoriya-0.1.4-windows-x64-setup.exe',
    'Kumoriya-0.1.4-windows-x64-setup.exe',
    'artifacts/windows/v0.1.4/Kumoriya-0.1.4-windows-x64-setup.exe',
    FALSE,
    now(),
    now()
)
ON CONFLICT (tag) DO UPDATE SET
    version = EXCLUDED.version,
    channel = EXCLUDED.channel,
    release_date = EXCLUDED.release_date,
    manifest_release_notes = EXCLUDED.manifest_release_notes,
    summary_es = EXCLUDED.summary_es,
    summary_en = EXCLUDED.summary_en,
    notes_es_markdown = EXCLUDED.notes_es_markdown,
    notes_en_markdown = EXCLUDED.notes_en_markdown,
    android_url = EXCLUDED.android_url,
    android_file_name = EXCLUDED.android_file_name,
    android_r2_key = EXCLUDED.android_r2_key,
    windows_url = EXCLUDED.windows_url,
    windows_file_name = EXCLUDED.windows_file_name,
    windows_r2_key = EXCLUDED.windows_r2_key,
    updated_at = now();

UPDATE app_releases
SET is_latest = TRUE,
    updated_at = now()
WHERE tag = 'v0.1.4'
  AND NOT EXISTS (
      SELECT 1
      FROM app_releases
      WHERE is_latest = TRUE
        AND tag <> 'v0.1.4'
  );
