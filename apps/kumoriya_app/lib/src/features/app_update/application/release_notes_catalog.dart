import 'dart:ui';

class LocalReleaseNotes {
  const LocalReleaseNotes({
    required this.version,
    required this.title,
    required this.summary,
    required this.added,
    required this.changed,
    required this.fixed,
  });

  final String version;
  final String title;
  final String summary;
  final List<String> added;
  final List<String> changed;
  final List<String> fixed;
}

LocalReleaseNotes? releaseNotesForVersion(String version, Locale locale) {
  final spanish = locale.languageCode.toLowerCase() == 'es';
  return switch (version) {
    '0.2.0' => spanish ? _v020Es : _v020En,
    '0.1.4' => spanish ? _v014Es : _v014En,
    _ => null,
  };
}

const LocalReleaseNotes _v020En = LocalReleaseNotes(
  version: '0.2.0',
  title: 'What changed in v0.2.0',
  summary:
      'Watch Party got dedicated collaborative screens, discovery moved further behind the backend, and release delivery is now API-driven.',
  added: <String>[
    'Dedicated Watch Party anime and episode pages focused on room context, readiness, and shared playback.',
    'Backend-powered AniList home cache and FCM episode notifications.',
    'Unified API-backed release feed for app and website metadata.',
  ],
  changed: <String>[
    'Party navigation now preserves room context through detail, episode list, and player routes.',
    'Profile page now highlights Watch Party and logout while de-emphasizing delete-account and UUID metadata.',
  ],
  fixed: <String>[
    'Release publishing now refreshes the backend snapshot immediately instead of relying on a stale one-shot cache.',
    'Android and backend notification channels are aligned under kumoriya_new_episodes.',
  ],
);

const LocalReleaseNotes _v020Es = LocalReleaseNotes(
  version: '0.2.0',
  title: 'Cambios en la v0.2.0',
  summary:
      'Watch Party ganó pantallas colaborativas dedicadas, el descubrimiento se apoya más en el backend y la distribución de releases ahora pasa por la API.',
  added: <String>[
    'Páginas dedicadas de anime y episodios para Watch Party con foco en sala, miembros, estado ready y reproducción compartida.',
    'Cache backend para el home de AniList y notificaciones FCM para episodios al aire.',
    'Feed unificado de releases por API para app y website.',
  ],
  changed: <String>[
    'La navegación de party ahora conserva mejor el contexto de sala entre detalle, episodios y reproductor.',
    'La pantalla de perfil ahora resalta Watch Party y logout, mientras borrar cuenta y el UUID quedan más discretos.',
  ],
  fixed: <String>[
    'El publish de releases ahora refresca el snapshot del backend de inmediato en lugar de depender de una cache vieja.',
    'Android y backend quedaron alineados en el canal kumoriya_new_episodes.',
  ],
);

const LocalReleaseNotes _v014En = LocalReleaseNotes(
  version: '0.1.4',
  title: 'What changed in v0.1.4',
  summary:
      'Patch release focused on download queue behavior, orphan cleanup, and safer resolver handling.',
  added: <String>['Clear queue action for pending and failed download tasks.'],
  changed: <String>[
    'Cancel and clear flows now update the UI immediately before background cleanup finishes.',
  ],
  fixed: <String>[
    'Windows cancellations disappear immediately instead of waiting for large HLS segment cleanup.',
    'Orphan *_segments folders are removed at startup when no task still references them.',
    'Resolver responses now tolerate non-UTF-8 embed payloads safely.',
    'Downloads refresh avoids StateError after async gaps on unmounted widgets.',
  ],
);

const LocalReleaseNotes _v014Es = LocalReleaseNotes(
  version: '0.1.4',
  title: 'Cambios en la v0.1.4',
  summary:
      'Versión de parche enfocada en la cola de descargas, la limpieza de huérfanos y un manejo más seguro de los resolvers.',
  added: <String>[
    'Acción para limpiar toda la cola de descargas pendientes y fallidas.',
  ],
  changed: <String>[
    'Cancelar y limpiar ahora actualiza la UI de inmediato antes de que termine la limpieza en segundo plano.',
  ],
  fixed: <String>[
    'Las cancelaciones en Windows desaparecen al instante en lugar de esperar la limpieza de segmentos HLS grandes.',
    'Las carpetas *_segments huérfanas se eliminan al iniciar cuando ya no están asociadas a tareas activas.',
    'Las respuestas embed no UTF-8 ya no rompen a los resolvers.',
    'El refresh de descargas evita StateError tras gaps async con widgets desmontados.',
  ],
);
