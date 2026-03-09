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
    final queries = _buildSearchQueries(<String>{
      anilistDetail.anime.title.romaji,
      if (anilistDetail.anime.title.english != null)
        anilistDetail.anime.title.english!,
      if (anilistDetail.anime.title.native != null)
        anilistDetail.anime.title.native!,
      ...anilistDetail.anime.title.synonyms,
    });

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

  List<String> _buildSearchQueries(Set<String> rawTitles) {
    final ordered = <String>[];
    final seen = <String>{};

    void addQuery(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final normalizedKey = trimmed.toLowerCase();
      if (seen.add(normalizedKey)) {
        ordered.add(trimmed);
      }
    }

    for (final title in rawTitles) {
      addQuery(title);

      final withoutSeason = _stripSeasonDescriptor(title);
      if (withoutSeason != title) {
        addQuery(withoutSeason);
      }

      final rootTitle = _extractRootTitle(withoutSeason);
      if (rootTitle != withoutSeason) {
        addQuery(rootTitle);
      }
    }

    return ordered;
  }

  String _stripSeasonDescriptor(String value) {
    var result = value.trim();
    const patterns = <String>[
      r'\s*[-:]?\s*\b\d+(?:st|nd|rd|th)?\s+season\b$',
      r'\s*[-:]?\s*\bseason\s+\d+\b$',
      r'\s*[-:]?\s*\bpart\s+\d+\b$',
      r'\s*[-:]?\s*\bcour\s+\d+\b$',
      r'\s*[-:]?\s*\b(?:ii|iii|iv|v)\b$',
    ];

    for (final pattern in patterns) {
      result = result.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    return result.trim();
  }

  String _extractRootTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final colonIndex = trimmed.indexOf(':');
    final dashIndex = trimmed.indexOf(' - ');
    final splitIndex = <int>[colonIndex, dashIndex]
        .where((index) => index > 0)
        .fold<int?>(null, (current, index) {
          if (current == null || index < current) {
            return index;
          }
          return current;
        });

    if (splitIndex == null) {
      return trimmed;
    }

    final root = trimmed.substring(0, splitIndex).trim();
    if (root.length < 10 || root.split(' ').length < 2) {
      return trimmed;
    }
    return root;
  }
}
