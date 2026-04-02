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
    '0.1.4' => spanish ? _v014Es : _v014En,
    _ => null,
  };
}

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
