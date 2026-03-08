import 'package:kumoriya_plugins/kumoriya_plugins.dart';

enum SourceAvailabilityStatus { available, unavailable }

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
    required this.status,
    required this.decision,
    this.episodes = const <SourceEpisode>[],
  });

  final SourceAvailabilityStatus status;
  final SourceMatchDecision decision;
  final List<SourceEpisode> episodes;
}
