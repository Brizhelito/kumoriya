import 'package:kumoriya_plugins/kumoriya_plugins.dart';

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
    this.unavailableReason,
    this.errorMessage,
  });

  final PluginManifest manifest;
  final SourceAvailabilityStatus status;
  final SourceMatchDecision decision;
  final SourceAnimeMatch? matchedAnime;
  final List<SourceEpisode> episodes;
  final SourceUnavailableReason? unavailableReason;
  final String? errorMessage;
}

final class SourceAvailabilitySummary {
  const SourceAvailabilitySummary({required this.sources, this.recommended});

  final List<SourceAvailability> sources;
  final SourceAvailability? recommended;
}
