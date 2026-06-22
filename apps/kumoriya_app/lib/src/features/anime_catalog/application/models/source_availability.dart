import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

export 'package:kumoriya_domain/kumoriya_domain.dart'
    show SourceAudioKind, sourceAudioKindFromCode;

enum SourceAvailabilityStatus { available, unavailable, error }

enum SourceUnavailableReason { noMatch, ambiguousMatch, noEpisodes }

enum MatchConfidence { high, medium, low }

final class SourceMatchDecision {
  const SourceMatchDecision({
    required this.verdict,
    required this.confidence,
    required this.reason,
    required this.acceptanceSignals,
    required this.rejectionSignals,
    this.candidate,
  });

  final bool verdict;
  final MatchConfidence confidence;
  final String reason;
  final List<String> acceptanceSignals;
  final List<String> rejectionSignals;
  final SourceAnimeMatch? candidate;
}

final class SourceAvailability {
  const SourceAvailability({
    required this.manifest,
    required this.status,
    required this.decision,
    this.matchedAnime,
    this.episodes = const <SourceEpisode>[],
    this.availableAudioKinds = const <SourceAudioKind>{},
    this.unavailableReason,
    this.errorMessage,
  });

  final PluginManifest manifest;
  final SourceAvailabilityStatus status;
  final SourceMatchDecision decision;
  final SourceAnimeMatch? matchedAnime;
  final List<SourceEpisode> episodes;
  final Set<SourceAudioKind> availableAudioKinds;
  final SourceUnavailableReason? unavailableReason;
  final String? errorMessage;

  bool get isAvailable => status == SourceAvailabilityStatus.available;

  SourceAvailability copyWith({
    PluginManifest? manifest,
    SourceAvailabilityStatus? status,
    SourceMatchDecision? decision,
    SourceAnimeMatch? matchedAnime,
    List<SourceEpisode>? episodes,
    Set<SourceAudioKind>? availableAudioKinds,
    SourceUnavailableReason? unavailableReason,
    String? errorMessage,
  }) {
    return SourceAvailability(
      manifest: manifest ?? this.manifest,
      status: status ?? this.status,
      decision: decision ?? this.decision,
      matchedAnime: matchedAnime ?? this.matchedAnime,
      episodes: episodes ?? this.episodes,
      availableAudioKinds: availableAudioKinds ?? this.availableAudioKinds,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final class SourceAvailabilitySummary {
  const SourceAvailabilitySummary({required this.sources, this.recommended});

  final List<SourceAvailability> sources;
  final SourceAvailability? recommended;

  List<SourceAvailability> get playableSources =>
      sources.where((source) => source.isAvailable).toList(growable: false);
}
