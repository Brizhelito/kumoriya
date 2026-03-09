import 'dart:convert';

import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../models/source_availability.dart';
import 'source_selection_policy.dart';

final class CachedSourceAvailabilitySnapshot {
  const CachedSourceAvailabilitySnapshot({
    required this.summary,
    required this.updatedAt,
    required this.coveredSourcePluginIds,
  });

  final SourceAvailabilitySummary summary;
  final DateTime updatedAt;
  final Set<String> coveredSourcePluginIds;
}

final class SourceAvailabilityCacheCodec {
  SourceAvailabilityCacheCodec({
    required List<SourcePlugin> sourcePlugins,
    required SourceSelectionPolicy selectionPolicy,
  }) : _pluginManifestById = {
         for (final plugin in sourcePlugins)
           plugin.manifest.id: plugin.manifest,
       },
       _selectionPolicy = selectionPolicy;

  final Map<String, PluginManifest> _pluginManifestById;
  final SourceSelectionPolicy _selectionPolicy;

  List<SourceAvailabilityCacheRecord> encode({
    required int anilistId,
    required SourceAvailabilitySummary summary,
    required DateTime updatedAt,
  }) {
    return summary.sources
        .map(
          (source) => SourceAvailabilityCacheRecord(
            anilistId: anilistId,
            sourcePluginId: source.manifest.id,
            payloadJson: jsonEncode(_encodeAvailability(source)),
            updatedAt: updatedAt,
          ),
        )
        .toList(growable: false);
  }

  CachedSourceAvailabilitySnapshot? decode(
    List<SourceAvailabilityCacheRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    final sources = <SourceAvailability>[];
    final coveredSourcePluginIds = <String>{};
    var newestUpdatedAt = records.first.updatedAt;

    for (final record in records) {
      final manifest = _pluginManifestById[record.sourcePluginId];
      if (manifest == null) {
        continue;
      }

      newestUpdatedAt = record.updatedAt.isAfter(newestUpdatedAt)
          ? record.updatedAt
          : newestUpdatedAt;
      final decoded = jsonDecode(record.payloadJson);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      sources.add(_decodeAvailability(manifest, decoded));
      coveredSourcePluginIds.add(record.sourcePluginId);
    }

    if (sources.isEmpty) {
      return null;
    }

    return CachedSourceAvailabilitySnapshot(
      summary: SourceAvailabilitySummary(
        sources: sources,
        recommended: _selectionPolicy.selectRecommended(sources),
      ),
      updatedAt: newestUpdatedAt,
      coveredSourcePluginIds: coveredSourcePluginIds,
    );
  }

  Map<String, Object?> _encodeAvailability(SourceAvailability source) {
    return <String, Object?>{
      'status': source.status.name,
      'decision': _encodeDecision(source.decision),
      'matchedAnime': source.matchedAnime == null
          ? null
          : _encodeSourceAnimeMatch(source.matchedAnime!),
      'episodes': source.episodes
          .map(_encodeSourceEpisode)
          .toList(growable: false),
      'availableAudioKinds': source.availableAudioKinds
          .map((kind) => kind.name)
          .toList(growable: false),
      'unavailableReason': source.unavailableReason?.name,
      'errorMessage': source.errorMessage,
    };
  }

  SourceAvailability _decodeAvailability(
    PluginManifest manifest,
    Map<String, dynamic> json,
  ) {
    final decisionJson = json['decision'];
    final matchedAnimeJson = json['matchedAnime'];
    final episodesJson = json['episodes'];
    final audioKindsJson = json['availableAudioKinds'];

    return SourceAvailability(
      manifest: manifest,
      status: _sourceAvailabilityStatusFromName(json['status'] as String?),
      decision: decisionJson is Map<String, dynamic>
          ? _decodeDecision(decisionJson)
          : const SourceMatchDecision(
              verdict: false,
              confidence: MatchConfidence.low,
              reason: 'Cached decision payload was malformed.',
              acceptanceSignals: <String>[],
              rejectionSignals: <String>['cache-decode-error'],
            ),
      matchedAnime: matchedAnimeJson is Map<String, dynamic>
          ? _decodeSourceAnimeMatch(matchedAnimeJson)
          : null,
      episodes: episodesJson is List
          ? episodesJson
                .whereType<Map<String, dynamic>>()
                .map(_decodeSourceEpisode)
                .toList(growable: false)
          : const <SourceEpisode>[],
      availableAudioKinds: audioKindsJson is List
          ? audioKindsJson
                .whereType<String>()
                .map(_sourceAudioKindFromName)
                .whereType<SourceAudioKind>()
                .toSet()
          : const <SourceAudioKind>{},
      unavailableReason: _sourceUnavailableReasonFromName(
        json['unavailableReason'] as String?,
      ),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, Object?> _encodeDecision(SourceMatchDecision decision) {
    return <String, Object?>{
      'verdict': decision.verdict,
      'confidence': decision.confidence.name,
      'reason': decision.reason,
      'acceptanceSignals': decision.acceptanceSignals,
      'rejectionSignals': decision.rejectionSignals,
      'candidate': decision.candidate == null
          ? null
          : _encodeSourceAnimeMatch(decision.candidate!),
    };
  }

  SourceMatchDecision _decodeDecision(Map<String, dynamic> json) {
    final candidateJson = json['candidate'];
    return SourceMatchDecision(
      verdict: json['verdict'] as bool? ?? false,
      confidence: _matchConfidenceFromName(json['confidence'] as String?),
      reason: json['reason'] as String? ?? 'Cached decision reason missing.',
      acceptanceSignals:
          (json['acceptanceSignals'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      rejectionSignals: (json['rejectionSignals'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      candidate: candidateJson is Map<String, dynamic>
          ? _decodeSourceAnimeMatch(candidateJson)
          : null,
    );
  }

  Map<String, Object?> _encodeSourceAnimeMatch(SourceAnimeMatch match) {
    return <String, Object?>{
      'sourceId': match.sourceId,
      'title': match.title,
      'thumbnailUrl': match.thumbnailUrl?.toString(),
      'releaseYear': match.releaseYear,
      'format': match.format.name,
    };
  }

  SourceAnimeMatch _decodeSourceAnimeMatch(Map<String, dynamic> json) {
    return SourceAnimeMatch(
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: _uriOrNull(json['thumbnailUrl'] as String?),
      releaseYear: json['releaseYear'] as int?,
      format: _animeFormatFromName(json['format'] as String?),
    );
  }

  Map<String, Object?> _encodeSourceEpisode(SourceEpisode episode) {
    return <String, Object?>{
      'sourceEpisodeId': episode.sourceEpisodeId,
      'number': episode.number,
      'title': episode.title,
      'episodeUrl': episode.episodeUrl.toString(),
      'thumbnailUrl': episode.thumbnailUrl?.toString(),
    };
  }

  SourceEpisode _decodeSourceEpisode(Map<String, dynamic> json) {
    return SourceEpisode(
      sourceEpisodeId: json['sourceEpisodeId'] as String? ?? '',
      number: (json['number'] as num?)?.toDouble() ?? 0,
      title: json['title'] as String? ?? '',
      episodeUrl: _uriOrNull(json['episodeUrl'] as String?) ?? Uri(),
      thumbnailUrl: _uriOrNull(json['thumbnailUrl'] as String?),
    );
  }

  Uri? _uriOrNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(value);
  }

  SourceAvailabilityStatus _sourceAvailabilityStatusFromName(String? value) {
    return SourceAvailabilityStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SourceAvailabilityStatus.unavailable,
    );
  }

  SourceUnavailableReason? _sourceUnavailableReasonFromName(String? value) {
    if (value == null) {
      return null;
    }
    for (final item in SourceUnavailableReason.values) {
      if (item.name == value) {
        return item;
      }
    }
    return null;
  }

  MatchConfidence _matchConfidenceFromName(String? value) {
    return MatchConfidence.values.firstWhere(
      (item) => item.name == value,
      orElse: () => MatchConfidence.low,
    );
  }

  SourceAudioKind? _sourceAudioKindFromName(String? value) {
    if (value == null) {
      return null;
    }
    for (final item in SourceAudioKind.values) {
      if (item.name == value) {
        return item;
      }
    }
    return null;
  }

  AnimeFormat _animeFormatFromName(String? value) {
    return AnimeFormat.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AnimeFormat.unknown,
    );
  }
}
