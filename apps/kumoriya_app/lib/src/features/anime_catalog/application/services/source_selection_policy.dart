import '../models/source_availability.dart';

final class SourceSelectionPolicy {
  const SourceSelectionPolicy({
    this.priority = const <String>[
      'kumoriya.source.jkanime',
      'kumoriya.source.animeflv',
      'kumoriya.source.animeav1',
    ],
  });

  final List<String> priority;

  SourceAvailability? selectRecommended(List<SourceAvailability> sources) {
    for (final pluginId in priority) {
      for (final source in sources) {
        if (source.manifest.id == pluginId &&
            source.status == SourceAvailabilityStatus.available) {
          return source;
        }
      }
    }

    for (final source in sources) {
      if (source.status == SourceAvailabilityStatus.available) {
        return source;
      }
    }

    return null;
  }
}
