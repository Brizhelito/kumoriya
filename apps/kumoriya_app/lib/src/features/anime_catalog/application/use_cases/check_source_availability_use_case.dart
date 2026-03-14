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
    var allCandidates = candidates;
    var decision = _matcher.decideMatch(
      anilistDetail: anilistDetail,
      candidates: allCandidates,
    );

    if (!decision.verdict || decision.candidate == null) {
      final directCandidates = await _probeDirectSlugCandidates(
        anilistDetail,
        existingCandidates: allCandidates,
      );
      if (directCandidates.isNotEmpty) {
        allCandidates = <SourceAnimeMatch>[
          ...allCandidates,
          ...directCandidates,
        ];
        decision = _matcher.decideMatch(
          anilistDetail: anilistDetail,
          candidates: allCandidates,
        );
      }
    }

    if (!decision.verdict || decision.candidate == null) {
      return SourceAvailability(
        manifest: _sourcePlugin.manifest,
        status: SourceAvailabilityStatus.unavailable,
        decision: decision,
        unavailableReason:
            decision.rejectionSignals.contains('ambiguous_runner_up') ||
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
        final alignedEpisodes = _alignEpisodesToRequestedSeason(
          anilistDetail: anilistDetail,
          decision: decision,
          episodes: episodes,
        );
        return SourceAvailability(
          manifest: _sourcePlugin.manifest,
          status: SourceAvailabilityStatus.available,
          decision: decision,
          matchedAnime: decision.candidate,
          episodes: alignedEpisodes,
        );
      },
    );
  }

  List<SourceEpisode> _alignEpisodesToRequestedSeason({
    required AnimeDetail anilistDetail,
    required SourceMatchDecision decision,
    required List<SourceEpisode> episodes,
  }) {
    if (!decision.acceptanceSignals.contains('grouped-season-title')) {
      return episodes;
    }

    final airedMetadata =
        anilistDetail.episodes
            .where((episode) => episode.isAired)
            .toList(growable: false)
          ..sort((a, b) => a.number.compareTo(b.number));
    if (airedMetadata.isEmpty) {
      return episodes;
    }

    final sourceSlice = episodes.length <= airedMetadata.length
        ? episodes
        : episodes.sublist(episodes.length - airedMetadata.length);
    if (sourceSlice.isEmpty) {
      return episodes;
    }

    final maxLength = sourceSlice.length < airedMetadata.length
        ? sourceSlice.length
        : airedMetadata.length;
    final aligned = <SourceEpisode>[];

    for (var index = 0; index < maxLength; index++) {
      final sourceEpisode = sourceSlice[index];
      final targetEpisode = airedMetadata[index];
      aligned.add(
        SourceEpisode(
          sourceEpisodeId: sourceEpisode.sourceEpisodeId,
          number: targetEpisode.number,
          title: targetEpisode.title.trim().isEmpty
              ? sourceEpisode.title
              : targetEpisode.title,
          episodeUrl: sourceEpisode.episodeUrl,
          thumbnailUrl: sourceEpisode.thumbnailUrl,
        ),
      );
    }

    return aligned.isEmpty ? episodes : aligned;
  }

  Future<List<SourceAnimeMatch>> _probeDirectSlugCandidates(
    AnimeDetail anilistDetail, {
    required List<SourceAnimeMatch> existingCandidates,
  }) async {
    final existingIds = existingCandidates
        .map((candidate) => candidate.sourceId.trim().toLowerCase())
        .toSet();
    final resolved = <SourceAnimeMatch>[];

    for (final slug in _buildDirectSlugCandidates(anilistDetail)) {
      if (!existingIds.add(slug)) {
        continue;
      }

      try {
        final result = await _sourcePlugin.getAnimeDetail(slug);
        result.fold(
          onFailure: (_) {},
          onSuccess: (detail) {
            resolved.add(
              SourceAnimeMatch(
                sourceId: detail.sourceId,
                title: detail.title,
                thumbnailUrl: detail.thumbnailUrl,
                releaseYear: detail.releaseYear,
                format: detail.format,
                aliases: detail.aliases,
                totalEpisodes: detail.totalEpisodes,
                seasonNumber: detail.seasonNumber,
                partNumber: detail.partNumber,
              ),
            );
          },
        );
      } catch (_) {
        continue;
      }
    }

    return resolved;
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

    final prioritizedTitles = rawTitles.toList(growable: false)
      ..sort((left, right) {
        return _titleQueryPriority(left).compareTo(_titleQueryPriority(right));
      });

    for (final title in prioritizedTitles) {
      for (final variant in _expandQueryVariants(title)) {
        addQuery(variant);
      }
    }

    return ordered;
  }

  List<String> _buildDirectSlugCandidates(AnimeDetail anilistDetail) {
    final candidates = <String>[];
    final seen = <String>{};
    final queries = _buildSearchQueries(<String>{
      anilistDetail.anime.title.romaji,
      if (anilistDetail.anime.title.english != null)
        anilistDetail.anime.title.english!,
      if (anilistDetail.anime.title.native != null)
        anilistDetail.anime.title.native!,
      ...anilistDetail.anime.title.synonyms,
    });

    void addSlug(String value) {
      final slug = _slugify(value);
      if (slug.isEmpty || !seen.add(slug)) {
        return;
      }
      candidates.add(slug);
      for (final variant in _expandSlugVariants(slug)) {
        if (seen.add(variant)) {
          candidates.add(variant);
        }
      }
    }

    for (final query in queries) {
      addSlug(query);
      if (anilistDetail.anime.format == AnimeFormat.tv) {
        addSlug('$query TV');
      }
    }

    return candidates;
  }

  List<String> _expandQueryVariants(String value) {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String candidate) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) {
        return;
      }
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        ordered.add(trimmed);
      }
    }

    add(value);
    final withoutSeason = _stripSeasonDescriptor(value);
    add(withoutSeason);
    add(_swapSeasonNotation(value));
    add(_swapSeasonNotation(withoutSeason));

    final withoutTrailingParenthetical = _stripTrailingParenthetical(
      withoutSeason,
    );
    add(withoutTrailingParenthetical);
    add(_swapSeasonNotation(withoutTrailingParenthetical));

    final rootTitle = _extractRootTitle(withoutTrailingParenthetical);
    add(rootTitle);

    final rootPlusSuffix = _extractRootPlusSuffixTitle(withoutSeason);
    add(rootPlusSuffix);
    add(_extractRootPlusSuffixTitle(withoutTrailingParenthetical));

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
    if (root.split(' ').length < 2 || root.length < 6) {
      return trimmed;
    }
    return root;
  }

  String _extractRootPlusSuffixTitle(String value) {
    final trimmed = value.trim();
    final colonIndex = trimmed.indexOf(':');
    final dashIndex = trimmed.lastIndexOf(' - ');
    if (colonIndex <= 0 || dashIndex <= colonIndex) {
      return trimmed;
    }

    final root = trimmed.substring(0, colonIndex).trim();
    final suffix = trimmed.substring(dashIndex + 3).trim();
    if (root.isEmpty || suffix.isEmpty) {
      return trimmed;
    }

    return '$root: $suffix';
  }

  String _stripTrailingParenthetical(String value) {
    return value.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  String _swapSeasonNotation(String value) {
    final seasonFirst = RegExp(
      r'\bseason\s+(\d+)\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (seasonFirst != null) {
      final number = int.tryParse(seasonFirst.group(1) ?? '');
      if (number != null) {
        return value.replaceFirst(
          seasonFirst.group(0)!,
          '${_ordinal(number)} Season',
        );
      }
    }

    final ordinalFirst = RegExp(
      r'\b(\d+)(st|nd|rd|th)\s+season\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (ordinalFirst != null) {
      final number = int.tryParse(ordinalFirst.group(1) ?? '');
      if (number != null) {
        return value.replaceFirst(ordinalFirst.group(0)!, 'Season $number');
      }
    }

    return value;
  }

  int _titleQueryPriority(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 3;
    }
    if (_containsMojibake(trimmed)) {
      return 2;
    }
    if (_containsCjk(trimmed)) {
      return 1;
    }
    return 0;
  }

  bool _containsCjk(String value) {
    return RegExp(
      r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
      unicode: true,
    ).hasMatch(value);
  }

  bool _containsMojibake(String value) {
    return value.contains('Ã') ||
        value.contains('â') ||
        value.contains('å') ||
        value.contains('ð');
  }

  Iterable<String> _expandSlugVariants(String slug) sync* {
    if (slug.contains('-sama')) {
      yield slug.replaceAll('-sama', 'sama');
    }
    if (slug.contains('-san')) {
      yield slug.replaceAll('-san', 'san');
    }
    if (slug.contains('-chan')) {
      yield slug.replaceAll('-chan', 'chan');
    }
    if (slug.contains('-kun')) {
      yield slug.replaceAll('-kun', 'kun');
    }
    if (slug.contains('season-2')) {
      yield slug.replaceAll('season-2', '2nd-season');
    }
    if (slug.contains('season-3')) {
      yield slug.replaceAll('season-3', '3rd-season');
    }
    if (slug.contains('season-4')) {
      yield slug.replaceAll('season-4', '4th-season');
    }
  }

  String _slugify(String value) {
    final lower = _stripDiacritics(value.toLowerCase());
    final buffer = StringBuffer();
    var previousWasDash = false;

    for (final codeUnit in lower.codeUnits) {
      final isLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isLetter || isDigit) {
        buffer.writeCharCode(codeUnit);
        previousWasDash = false;
        continue;
      }

      final isCollapsedSeparator =
          codeUnit == 47 ||
          codeUnit == 92 ||
          codeUnit == 39 ||
          codeUnit == 8217;
      if (isCollapsedSeparator) {
        continue;
      }

      if (!previousWasDash) {
        buffer.write('-');
        previousWasDash = true;
      }
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _stripDiacritics(String value) {
    return value
        .replaceAll('\u00E1', 'a')
        .replaceAll('\u00E0', 'a')
        .replaceAll('\u00E4', 'a')
        .replaceAll('\u00E2', 'a')
        .replaceAll('\u00E9', 'e')
        .replaceAll('\u00E8', 'e')
        .replaceAll('\u00EB', 'e')
        .replaceAll('\u00EA', 'e')
        .replaceAll('\u00ED', 'i')
        .replaceAll('\u00EC', 'i')
        .replaceAll('\u00EF', 'i')
        .replaceAll('\u00EE', 'i')
        .replaceAll('\u00F3', 'o')
        .replaceAll('\u00F2', 'o')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u00F4', 'o')
        .replaceAll('\u00FA', 'u')
        .replaceAll('\u00F9', 'u')
        .replaceAll('\u00FC', 'u')
        .replaceAll('\u00FB', 'u')
        .replaceAll('\u00F1', 'n');
  }

  String _ordinal(int value) {
    final remainder100 = value % 100;
    if (remainder100 >= 11 && remainder100 <= 13) {
      return '${value}th';
    }

    switch (value % 10) {
      case 1:
        return '${value}st';
      case 2:
        return '${value}nd';
      case 3:
        return '${value}rd';
      default:
        return '${value}th';
    }
  }
}
