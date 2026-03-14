import '../normalization/series_fingerprint_builder.dart';

final class SeriesCandidate<T> {
  const SeriesCandidate({required this.fingerprint, required this.matchedKeys});

  final SeriesFingerprint<T> fingerprint;
  final Set<String> matchedKeys;
}

final class SeriesCandidateIndex<T> {
  SeriesCandidateIndex(Iterable<SeriesFingerprint<T>> fingerprints)
    : _fingerprints = {
        for (final fingerprint in fingerprints)
          fingerprint.identifier: fingerprint,
      } {
    for (final fingerprint in _fingerprints.values) {
      for (final key in fingerprint.blockingKeys) {
        _idsByKey
            .putIfAbsent(key, () => <String>{})
            .add(fingerprint.identifier);
      }
    }
  }

  final Map<String, SeriesFingerprint<T>> _fingerprints;
  final Map<String, Set<String>> _idsByKey = <String, Set<String>>{};

  List<SeriesCandidate<T>> lookup(SeriesFingerprint<dynamic> query) {
    final matchedKeysById = <String, Set<String>>{};
    for (final key in query.blockingKeys) {
      for (final id in _idsByKey[key] ?? const <String>{}) {
        matchedKeysById.putIfAbsent(id, () => <String>{}).add(key);
      }
    }
    if (matchedKeysById.isEmpty) {
      if (_fingerprints.length <= 50) {
        return _fingerprints.values
            .map(
              (fingerprint) => SeriesCandidate<T>(
                fingerprint: fingerprint,
                matchedKeys: const <String>{'fallback-scan'},
              ),
            )
            .toList(growable: false);
      }
      return _fingerprints.values
          .where(
            (fingerprint) =>
                fingerprint.primaryTitle.rootTitle.isNotEmpty &&
                fingerprint.primaryTitle.rootTitle ==
                    query.primaryTitle.rootTitle,
          )
          .map(
            (fingerprint) => SeriesCandidate<T>(
              fingerprint: fingerprint,
              matchedKeys: <String>{
                'fallback-root:${query.primaryTitle.rootTitle}',
              },
            ),
          )
          .toList(growable: false);
    }

    return matchedKeysById.entries
        .map(
          (entry) => SeriesCandidate<T>(
            fingerprint: _fingerprints[entry.key]!,
            matchedKeys: entry.value,
          ),
        )
        .toList(growable: false);
  }
}
