import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';

final class CheckSourceAvailabilityUseCase {
  const CheckSourceAvailabilityUseCase({
    required SourcePlugin sourcePlugin,
    required AnilistSourceMatcher matcher,
  }) : _sourcePlugin = sourcePlugin,
       _matcher = matcher;

  final SourcePlugin _sourcePlugin;
  final AnilistSourceMatcher _matcher;

  Future<SourceAvailability> call(AnimeDetail anilistDetail) async {
    final searchResult = await _searchCandidates(anilistDetail);
    if (!searchResult.isSuccess) {
      return SourceAvailability(
        manifest: _sourcePlugin.manifest,
        status: SourceAvailabilityStatus.error,
        decision: const SourceMatchDecision(
          verdict: false,
          confidence: MatchConfidence.low,
          reason: 'Source search failed.',
          acceptanceSignals: <String>[],
          rejectionSignals: <String>['search-error'],
        ),
        errorMessage: searchResult.fold(
          onFailure: (error) => error.message,
          onSuccess: (_) => null,
        ),
      );
    }

    final candidates = searchResult.fold(
      onFailure: (_) => const <SourceAnimeMatch>[],
      onSuccess: (value) => value,
    );
    final decision = _matcher.decideMatch(
      anilistDetail: anilistDetail,
      candidates: candidates,
    );

    if (!decision.verdict || decision.candidate == null) {
      return SourceAvailability(
        manifest: _sourcePlugin.manifest,
        status: SourceAvailabilityStatus.unavailable,
        decision: decision,
        unavailableReason:
            decision.rejectionSignals.contains('ambiguous-top-candidates')
            ? SourceUnavailableReason.ambiguousMatch
            : SourceUnavailableReason.noMatch,
      );
    }

    final episodesResult = await _sourcePlugin.getEpisodes(
      decision.candidate!.sourceId,
    );

    return episodesResult.fold(
      onFailure: (error) => SourceAvailability(
        manifest: _sourcePlugin.manifest,
        status: error.kind == KumoriyaErrorKind.notFound
            ? SourceAvailabilityStatus.unavailable
            : SourceAvailabilityStatus.error,
        decision: decision,
        unavailableReason: error.kind == KumoriyaErrorKind.notFound
            ? SourceUnavailableReason.noEpisodes
            : null,
        errorMessage: error.kind == KumoriyaErrorKind.notFound
            ? null
            : error.message,
      ),
      onSuccess: (episodes) {
        if (episodes.isEmpty) {
          return SourceAvailability(
            manifest: _sourcePlugin.manifest,
            status: SourceAvailabilityStatus.unavailable,
            decision: decision,
            unavailableReason: SourceUnavailableReason.noEpisodes,
          );
        }
        return SourceAvailability(
          manifest: _sourcePlugin.manifest,
          status: SourceAvailabilityStatus.available,
          decision: decision,
          matchedAnime: decision.candidate,
          episodes: episodes,
        );
      },
    );
  }

  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> _searchCandidates(
    AnimeDetail anilistDetail,
  ) async {
    final queries = <String>{
      anilistDetail.anime.title.romaji,
      if (anilistDetail.anime.title.english != null)
        anilistDetail.anime.title.english!,
      if (anilistDetail.anime.title.native != null)
        anilistDetail.anime.title.native!,
      ...anilistDetail.anime.title.synonyms,
    }.where((value) => value.trim().isNotEmpty).toList(growable: false);

    final seenIds = <String>{};
    final collected = <SourceAnimeMatch>[];
    KumoriyaError? lastError;

    for (final query in queries) {
      final result = await _sourcePlugin.search(
        SourceSearchQuery(query: query.trim(), limit: 10),
      );

      result.fold(
        onFailure: (error) => lastError = error,
        onSuccess: (matches) {
          for (final match in matches) {
            if (seenIds.add(match.sourceId)) {
              collected.add(match);
            }
          }
        },
      );

      if (collected.length >= 10) {
        break;
      }
    }

    if (collected.isNotEmpty) {
      return Success(collected);
    }

    if (lastError != null) {
      return Failure(lastError!);
    }

    return const Success(<SourceAnimeMatch>[]);
  }
}
