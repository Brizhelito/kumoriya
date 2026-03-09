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
    final ranked = rankAvailable(sources);
    return ranked.isEmpty ? null : ranked.first;
  }

  List<SourceAvailability> rankAvailable(List<SourceAvailability> sources) {
    final available = sources
        .where((source) => source.status == SourceAvailabilityStatus.available)
        .toList(growable: false);
    final ranked = [...available];
    ranked.sort(
      (left, right) => priorityIndex(
        left.manifest.id,
      ).compareTo(priorityIndex(right.manifest.id)),
    );
    return ranked;
  }

  int priorityIndex(String pluginId) {
    final index = priority.indexOf(pluginId);
    return index == -1 ? priority.length + 100 : index;
  }
}
