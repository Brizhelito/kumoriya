import 'dart:developer' as developer;

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';

enum _DirectBridgeKind { onaTvDrift, unknownFormat }

final class CheckSourceAvailabilityUseCase {
  static const int _maxParallelLookups = 3;

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
    _debugLog(
      'search anilist=${anilistDetail.anime.anilistId} '
      'source=${_sourcePlugin.manifest.id} '
      'title="${anilistDetail.anime.title.romaji}" '
      'candidates=${candidates.length}',
    );
    var allCandidates = candidates;
    var directlyConfirmedCandidateIds = <String>{};
    SourceMatchDecision? directConfirmedExactTitleDecision;
    SourceMatchDecision? groupedSeasonFallbackDecision;
    SourceMatchDecision? directFormatBridgeDecision;
    var decision = _matcher.decideMatch(
      anilistDetail: anilistDetail,
      candidates: allCandidates,
    );

    if (!decision.verdict || decision.candidate == null) {
      final directCandidates = await _probeDirectSlugCandidates(
        anilistDetail,
        existingCandidates: allCandidates,
        searchCandidateSourceIds: allCandidates
            .map((candidate) => candidate.sourceId)
            .toList(),
      );
      if (directCandidates.isNotEmpty) {
        directlyConfirmedCandidateIds = directCandidates
            .map((candidate) => candidate.sourceId.trim().toLowerCase())
            .toSet();
        directConfirmedExactTitleDecision =
            _buildDirectConfirmedExactTitleDecision(
              anilistDetail: anilistDetail,
              directCandidates: directCandidates,
            );
        groupedSeasonFallbackDecision = _buildGroupedSeasonFallbackDecision(
          anilistDetail: anilistDetail,
          directCandidates: directCandidates,
        );
        directFormatBridgeDecision = _buildDirectFormatBridgeDecision(
          anilistDetail: anilistDetail,
          directCandidates: directCandidates,
        );
        allCandidates = _mergeCandidates(
          existingCandidates: allCandidates,
          resolvedCandidates: directCandidates,
        );
        decision = _matcher.decideMatch(
          anilistDetail: anilistDetail,
          candidates: allCandidates,
        );
      }
    }

    final acceptsDirectlyConfirmedReviewCandidate =
        _acceptsDirectlyConfirmedReviewCandidate(
          decision: decision,
          directlyConfirmedCandidateIds: directlyConfirmedCandidateIds,
        );
    final fallbackDecision =
        (!decision.verdict && directConfirmedExactTitleDecision != null)
        ? directConfirmedExactTitleDecision
        : (!decision.verdict && groupedSeasonFallbackDecision != null)
        ? groupedSeasonFallbackDecision
        : (!decision.verdict && directFormatBridgeDecision != null)
        ? directFormatBridgeDecision
        : null;
    final resolvedDecision = fallbackDecision ?? decision;
    _debugLog(
      'decision anilist=${anilistDetail.anime.anilistId} '
      'source=${_sourcePlugin.manifest.id} '
      'verdict=${resolvedDecision.verdict} '
      'confidence=${resolvedDecision.confidence.name} '
      'candidate=${resolvedDecision.candidate?.sourceId ?? 'none'} '
      'accept=${resolvedDecision.acceptanceSignals.join('|')} '
      'reject=${resolvedDecision.rejectionSignals.join('|')}',
    );

    if ((!resolvedDecision.verdict &&
            !acceptsDirectlyConfirmedReviewCandidate) ||
        resolvedDecision.candidate == null) {
      _debugLog(
        'unavailable-no-match anilist=${anilistDetail.anime.anilistId} '
        'source=${_sourcePlugin.manifest.id}',
      );
      return SourceAvailability(
        manifest: _sourcePlugin.manifest,
        status: SourceAvailabilityStatus.unavailable,
        decision: resolvedDecision,
        unavailableReason:
            resolvedDecision.rejectionSignals.contains('ambiguous_runner_up') ||
                resolvedDecision.rejectionSignals.contains(
                  'ambiguous-top-candidates',
                )
            ? SourceUnavailableReason.ambiguousMatch
            : SourceUnavailableReason.noMatch,
      );
    }

    final episodesResult = await _sourcePlugin.getEpisodes(
      resolvedDecision.candidate!.sourceId,
    );

    return episodesResult.fold(
      onFailure: (error) {
        _debugLog(
          'episodes-failure anilist=${anilistDetail.anime.anilistId} '
          'source=${_sourcePlugin.manifest.id} '
          'candidate=${resolvedDecision.candidate!.sourceId} '
          'code=${error.code} kind=${error.kind.name}',
        );
        return SourceAvailability(
          manifest: _sourcePlugin.manifest,
          status: error.kind == KumoriyaErrorKind.notFound
              ? SourceAvailabilityStatus.unavailable
              : SourceAvailabilityStatus.error,
          decision: resolvedDecision,
          unavailableReason: error.kind == KumoriyaErrorKind.notFound
              ? SourceUnavailableReason.noEpisodes
              : null,
          errorMessage: error.kind == KumoriyaErrorKind.notFound
              ? null
              : error.message,
        );
      },
      onSuccess: (episodes) {
        if (episodes.isEmpty) {
          _debugLog(
            'episodes-empty anilist=${anilistDetail.anime.anilistId} '
            'source=${_sourcePlugin.manifest.id} '
            'candidate=${resolvedDecision.candidate!.sourceId}',
          );
          return SourceAvailability(
            manifest: _sourcePlugin.manifest,
            status: SourceAvailabilityStatus.unavailable,
            decision: resolvedDecision,
            unavailableReason: SourceUnavailableReason.noEpisodes,
          );
        }
        final alignedEpisodes = _alignEpisodesToRequestedSeason(
          anilistDetail: anilistDetail,
          decision: resolvedDecision,
          episodes: episodes,
        );
        _debugLog(
          'episodes-ready anilist=${anilistDetail.anime.anilistId} '
          'source=${_sourcePlugin.manifest.id} '
          'candidate=${resolvedDecision.candidate!.sourceId} '
          'raw=${_episodeRange(episodes)} '
          'aligned=${_episodeRange(alignedEpisodes)} '
          'animeEpisodes=${_episodeRange(anilistDetail.episodes)} '
          'status=${anilistDetail.anime.status.name} '
          'total=${anilistDetail.anime.totalEpisodes ?? 'unknown'} '
          'accept=${resolvedDecision.acceptanceSignals.join('|')}',
        );
        return SourceAvailability(
          manifest: _sourcePlugin.manifest,
          status: SourceAvailabilityStatus.available,
          decision: resolvedDecision,
          matchedAnime: resolvedDecision.candidate,
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

    final sortedMetadata = anilistDetail.episodes.toList(growable: false)
      ..sort((a, b) => a.number.compareTo(b.number));
    final airedMetadata = sortedMetadata
        .where((episode) => episode.isAired)
        .toList(growable: false);
    if (sortedMetadata.isEmpty) {
      return episodes;
    }

    final seasonTotal =
        anilistDetail.anime.totalEpisodes ?? sortedMetadata.length;
    if (seasonTotal > 0 &&
        episodes.length <= seasonTotal &&
        _candidateLooksRequestedSeasonSpecific(
          anilistDetail: anilistDetail,
          candidate: decision.candidate,
        )) {
      return episodes;
    }

    // Prefer the prequel-derived boundary: the source lists S1+S2 cumulatively
    // under a grouped slug, so the S2 block starts right after all previous
    // seasons' total episode counts. This is robust when the source uploads
    // episodes faster than AniList updates `nextAiringEpisode` (otherwise the
    // legacy heuristic below would slice `airedMetadata.length` items from the
    // tail and silently shift the alignment by one — clicking S2_ep1 would
    // open S2_ep2 because source_ep1 would be dropped from the slice).
    final priorSeasonEpisodes = _sumPrequelEpisodes(anilistDetail);

    List<SourceEpisode> sourceSlice;
    List<AnimeEpisode> alignmentMetadata;

    if (priorSeasonEpisodes != null &&
        priorSeasonEpisodes > 0 &&
        priorSeasonEpisodes < episodes.length) {
      sourceSlice = episodes.sublist(priorSeasonEpisodes);
      if (sourceSlice.length > seasonTotal) {
        sourceSlice = sourceSlice.sublist(0, seasonTotal);
      }
      alignmentMetadata = sortedMetadata;
    } else {
      // Legacy fallback: best-effort alignment when the prequel total is
      // unknown. Assumes `source.length == S1_total + aired_in_S2`.
      if (airedMetadata.isEmpty) {
        return episodes;
      }
      sourceSlice = episodes.length <= airedMetadata.length
          ? episodes
          : episodes.sublist(episodes.length - airedMetadata.length);
      alignmentMetadata = airedMetadata;
    }

    if (sourceSlice.isEmpty) {
      return episodes;
    }

    final aligned = <SourceEpisode>[];

    for (var index = 0; index < sourceSlice.length; index++) {
      final sourceEpisode = sourceSlice[index];
      if (index < alignmentMetadata.length) {
        final targetEpisode = alignmentMetadata[index];
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
      } else {
        // Synthesize episode numbering/metadata for extra episodes from the source
        // that AniList hasn't populated yet.
        final nextNumber =
            (alignmentMetadata.isNotEmpty
                ? alignmentMetadata.last.number
                : 0.0) +
            (index - alignmentMetadata.length + 1);
        aligned.add(
          SourceEpisode(
            sourceEpisodeId: sourceEpisode.sourceEpisodeId,
            number: nextNumber,
            title: sourceEpisode.title,
            episodeUrl: sourceEpisode.episodeUrl,
            thumbnailUrl: sourceEpisode.thumbnailUrl,
          ),
        );
      }
    }

    return aligned.isEmpty ? episodes : aligned;
  }

  /// Sums the episode counts of all direct prequel relations. Returns `null`
  /// when no prequel relations are known or when any prequel is missing a
  /// reliable `totalEpisodes` value — in those cases we cannot infer where
  /// the current season starts inside a grouped source listing.
  int? _sumPrequelEpisodes(AnimeDetail anilistDetail) {
    var total = 0;
    var found = false;
    for (final relation in anilistDetail.relations) {
      if (relation.type != AnimeRelationType.prequel ||
          relation.targetKind != MediaKind.anime) {
        continue;
      }
      final episodes = relation.anime.totalEpisodes;
      if (episodes == null || episodes <= 0) {
        // Unknown prequel size -> cannot compute a safe boundary.
        return null;
      }
      total += episodes;
      found = true;
    }
    return found ? total : null;
  }

  bool _candidateLooksRequestedSeasonSpecific({
    required AnimeDetail anilistDetail,
    required SourceAnimeMatch? candidate,
  }) {
    if (candidate == null) {
      return false;
    }

    final seasonNumber = _requestedSeasonNumber(anilistDetail);
    if (seasonNumber == null || seasonNumber < 2) {
      return false;
    }
    if (candidate.seasonNumber == seasonNumber) {
      return true;
    }

    final sourceTokens = <String>{
      _slugify(candidate.sourceId),
      _slugify(candidate.title),
      for (final alias in candidate.aliases) _slugify(alias),
    }..removeWhere((value) => value.isEmpty);

    final seasonTokens = <String>{
      '$seasonNumber',
      'season-$seasonNumber',
      '${_ordinal(seasonNumber)}-season',
    };

    return sourceTokens.any(
      (token) => seasonTokens.any(
        (seasonToken) =>
            token.endsWith('-$seasonToken') || token.contains('-$seasonToken-'),
      ),
    );
  }

  int? _requestedSeasonNumber(AnimeDetail anilistDetail) {
    for (final title in _buildCandidateTitleSet(anilistDetail.anime)) {
      final normalized = title.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final seasonFirst = RegExp(
        r'\bseason\s+(\d+)\b',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (seasonFirst != null) {
        return int.tryParse(seasonFirst.group(1) ?? '');
      }

      final ordinalFirst = RegExp(
        r'\b(\d+)(?:st|nd|rd|th)\s+season\b',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (ordinalFirst != null) {
        return int.tryParse(ordinalFirst.group(1) ?? '');
      }

      final bareTrailing = _tryParseBareTrailingSeasonTitle(normalized);
      if (bareTrailing != null) {
        return bareTrailing.seasonNumber;
      }
    }

    return null;
  }

  Future<List<SourceAnimeMatch>> _probeDirectSlugCandidates(
    AnimeDetail anilistDetail, {
    required List<SourceAnimeMatch> existingCandidates,
    List<String> searchCandidateSourceIds = const <String>[],
  }) async {
    final existingIds = existingCandidates
        .map((candidate) => candidate.sourceId.trim().toLowerCase())
        .toSet();
    final probedSlugs = <String>{};
    final resolved = <SourceAnimeMatch>[];

    final allSlugs = <String>[
      ..._buildDirectSlugCandidates(anilistDetail),
      ...searchCandidateSourceIds,
    ];

    final slugs = <String>[];
    for (final slug in allSlugs) {
      if (probedSlugs.add(slug)) {
        slugs.add(slug);
      }
    }

    for (var offset = 0; offset < slugs.length; offset += _maxParallelLookups) {
      final end = offset + _maxParallelLookups < slugs.length
          ? offset + _maxParallelLookups
          : slugs.length;
      final batch = slugs.sublist(offset, end);
      final results = await Future.wait(
        batch.map((slug) async {
          try {
            return await _sourcePlugin.getAnimeDetail(slug);
          } catch (_) {
            return null;
          }
        }),
      );

      for (final result in results) {
        result?.fold(
          onFailure: (_) {},
          onSuccess: (detail) {
            final normalizedId = detail.sourceId.trim().toLowerCase();
            if (!existingIds.add(normalizedId) &&
                resolved.any(
                  (candidate) =>
                      candidate.sourceId.trim().toLowerCase() == normalizedId,
                )) {
              return;
            }
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
      }
    }

    return resolved;
  }

  List<SourceAnimeMatch> _mergeCandidates({
    required List<SourceAnimeMatch> existingCandidates,
    required List<SourceAnimeMatch> resolvedCandidates,
  }) {
    final merged = <String, SourceAnimeMatch>{
      for (final candidate in existingCandidates)
        candidate.sourceId.trim().toLowerCase(): candidate,
    };

    for (final candidate in resolvedCandidates) {
      merged[candidate.sourceId.trim().toLowerCase()] = candidate;
    }

    return merged.values.toList(growable: false);
  }

  bool _acceptsDirectlyConfirmedReviewCandidate({
    required SourceMatchDecision decision,
    required Set<String> directlyConfirmedCandidateIds,
  }) {
    final candidate = decision.candidate;
    if (candidate == null || directlyConfirmedCandidateIds.isEmpty) {
      return false;
    }

    final normalizedId = candidate.sourceId.trim().toLowerCase();
    if (!directlyConfirmedCandidateIds.contains(normalizedId)) {
      return false;
    }

    return decision.rejectionSignals.every(
      (signal) =>
          signal == 'ambiguous_runner_up' ||
          signal == 'ambiguous-top-candidates',
    );
  }

  SourceMatchDecision? _buildGroupedSeasonFallbackDecision({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> directCandidates,
  }) {
    final canonicalTitle = anilistDetail.anime.title.romaji.trim();
    final rootTitle = _stripSeasonDescriptor(canonicalTitle);
    if (rootTitle.isEmpty || rootTitle == canonicalTitle) {
      return null;
    }

    final normalizedRoot = _slugify(rootTitle);
    final rootVariants = <String>{
      normalizedRoot,
      ..._expandSlugVariants(normalizedRoot),
    };
    for (final candidate in directCandidates) {
      final normalizedCandidateTitle = _slugify(candidate.title);
      if (!rootVariants.contains(normalizedCandidateTitle)) {
        continue;
      }

      return SourceMatchDecision(
        verdict: true,
        confidence: MatchConfidence.medium,
        reason: 'Direct slug confirmation resolved to a grouped season title.',
        acceptanceSignals: const <String>[
          'grouped-season-title',
          'direct-confirmed-grouped-season',
        ],
        rejectionSignals: const <String>[],
        candidate: candidate,
      );
    }

    return null;
  }

  SourceMatchDecision? _buildDirectConfirmedExactTitleDecision({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> directCandidates,
  }) {
    final anime = anilistDetail.anime;
    final canonicalYear = anime.releaseYear;
    final queryTitles = _buildCandidateTitleSet(anime);

    for (final candidate in directCandidates) {
      if (canonicalYear != null &&
          candidate.releaseYear != null &&
          candidate.releaseYear != canonicalYear) {
        continue;
      }

      if (!_matchesDirectExactTitle(queryTitles, candidate)) {
        continue;
      }

      return SourceMatchDecision(
        verdict: true,
        confidence: MatchConfidence.medium,
        reason:
            'Direct detail confirmation resolved an exact canonical title or alias match.',
        acceptanceSignals: const <String>[
          'direct-confirmed-exact-title',
          'direct-confirmed-alias-match',
        ],
        rejectionSignals: const <String>[],
        candidate: candidate,
      );
    }

    return null;
  }

  SourceMatchDecision? _buildDirectFormatBridgeDecision({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> directCandidates,
  }) {
    final anime = anilistDetail.anime;
    final canonicalYear = anime.releaseYear;
    final queryTitles = _buildCandidateTitleSet(anime);

    for (final candidate in directCandidates) {
      final bridgeKind = _bridgeKindForDirectCandidate(
        anime.format,
        candidate.format,
      );
      if (bridgeKind == null) {
        continue;
      }
      if (canonicalYear != null &&
          candidate.releaseYear != null &&
          candidate.releaseYear != canonicalYear) {
        continue;
      }
      if (!_matchesDirectBridgeTitle(queryTitles, candidate.title)) {
        continue;
      }

      return SourceMatchDecision(
        verdict: true,
        confidence: MatchConfidence.medium,
        reason: switch (bridgeKind) {
          _DirectBridgeKind.onaTvDrift =>
            'Direct detail confirmation resolved a strong title match blocked only by ONA/TV source typing drift.',
          _DirectBridgeKind.unknownFormat =>
            'Direct detail confirmation resolved a strong title match where the source omitted reliable format metadata.',
        },
        acceptanceSignals: <String>[
          'direct-confirmed-format-bridge',
          switch (bridgeKind) {
            _DirectBridgeKind.onaTvDrift => 'direct-confirmed-ona-tv-bridge',
            _DirectBridgeKind.unknownFormat =>
              'direct-confirmed-unknown-format-bridge',
          },
        ],
        rejectionSignals: const <String>[],
        candidate: candidate,
      );
    }

    return null;
  }

  _DirectBridgeKind? _bridgeKindForDirectCandidate(
    AnimeFormat queryFormat,
    AnimeFormat candidateFormat,
  ) {
    if ((queryFormat == AnimeFormat.ona && candidateFormat == AnimeFormat.tv) ||
        (queryFormat == AnimeFormat.tv && candidateFormat == AnimeFormat.ona)) {
      return _DirectBridgeKind.onaTvDrift;
    }
    if (candidateFormat == AnimeFormat.unknown) {
      return _DirectBridgeKind.unknownFormat;
    }
    return null;
  }

  bool _matchesDirectBridgeTitle(
    Set<String> queryTitles,
    String candidateTitle,
  ) {
    final normalizedCandidate = _slugify(candidateTitle);
    if (normalizedCandidate.isEmpty) {
      return false;
    }
    final candidateVariants = <String>{
      normalizedCandidate,
      ..._expandSlugVariants(normalizedCandidate),
    };

    for (final queryTitle in queryTitles) {
      final normalizedQuery = _slugify(queryTitle);
      if (normalizedQuery.isEmpty) {
        continue;
      }
      final queryVariants = <String>{
        normalizedQuery,
        ..._expandSlugVariants(normalizedQuery),
      };

      final tokenCount = queryTitle
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .length;
      final strongEnoughPrefix =
          tokenCount >= 3 || normalizedQuery.length >= 16;

      for (final qv in queryVariants) {
        if (candidateVariants.contains(qv)) {
          return true;
        }
        if (strongEnoughPrefix) {
          for (final cv in candidateVariants) {
            if (cv.startsWith('$qv-') || cv.contains(qv)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  bool _matchesDirectExactTitle(
    Set<String> queryTitles,
    SourceAnimeMatch candidate,
  ) {
    final normalizedQueries = <String>{};
    for (final title in queryTitles) {
      final slug = _slugify(title);
      if (slug.isNotEmpty) {
        normalizedQueries.add(slug);
        for (final variant in _expandSlugVariants(slug)) {
          normalizedQueries.add(variant);
        }
      }
    }
    final candidateTitles = <String>[candidate.title, ...candidate.aliases];

    for (final title in candidateTitles) {
      final normalizedTitle = _slugify(title);
      if (normalizedTitle.isEmpty) {
        continue;
      }
      if (normalizedQueries.contains(normalizedTitle)) {
        return true;
      }
    }

    return false;
  }

  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> _searchCandidates(
    AnimeDetail anilistDetail,
  ) async {
    final allQueries = _buildSearchQueries(
      _buildCandidateTitleSet(anilistDetail.anime),
      anilistDetail.anime.format,
    );
    final totalEpisodes = anilistDetail.anime.totalEpisodes ?? 0;
    final isLongAnime = totalEpisodes >= 80;
    final isShortAnime = totalEpisodes > 0 && totalEpisodes <= 12;

    final maxQueries = isLongAnime
        ? allQueries.length
        : isShortAnime
        ? 3
        : 6;
    final queries = allQueries.take(maxQueries).toList(growable: false);
    final earlyStopCandidateCount = isLongAnime
        ? 28
        : isShortAnime
        ? 10
        : 16;

    final seenIds = <String>{};
    final collected = <SourceAnimeMatch>[];
    KumoriyaError? lastError;

    for (
      var offset = 0;
      offset < queries.length;
      offset += _maxParallelLookups
    ) {
      final end = offset + _maxParallelLookups < queries.length
          ? offset + _maxParallelLookups
          : queries.length;
      final batch = queries.sublist(offset, end);
      final results = await Future.wait(
        batch.map(
          (query) => _sourcePlugin.search(
            SourceSearchQuery(query: query.trim(), limit: 10),
          ),
        ),
      );

      for (final result in results) {
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
      }

      if (collected.length >= earlyStopCandidateCount) {
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

  List<String> _buildSearchQueries(Set<String> rawTitles, AnimeFormat format) {
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
      for (final variant in _expandQueryVariants(title, format)) {
        addQuery(variant);
      }
    }

    return ordered;
  }

  List<String> _buildDirectSlugCandidates(AnimeDetail anilistDetail) {
    final candidates = <String>[];
    final seen = <String>{};
    final queries = _buildSearchQueries(
      _buildCandidateTitleSet(anilistDetail.anime),
      anilistDetail.anime.format,
    );

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

  Set<String> _buildCandidateTitleSet(Anime anime) {
    return <String>{
      anime.title.romaji,
      if (anime.title.english != null) anime.title.english!,
      if (anime.title.native != null) anime.title.native!,
      ...anime.title.synonyms,
      ..._supplementalConfirmedTitleAliases(anime),
    };
  }

  Iterable<String> _supplementalConfirmedTitleAliases(Anime anime) sync* {
    switch (anime.anilistId) {
      case 235:
        if (!_hasTitleVariant(anime, 'Detective Conan')) {
          yield 'Detective Conan';
        }
      case 187166:
        if (!_hasTitleVariant(anime, 'Ganzo! Bandori-chan')) {
          yield 'Ganzo! Bandori-chan';
        }
    }
  }

  bool _hasTitleVariant(Anime anime, String candidate) {
    final normalizedCandidate = candidate.trim().toLowerCase();
    final titles = <String?>[
      anime.title.romaji,
      anime.title.english,
      anime.title.native,
      ...anime.title.synonyms,
    ];

    for (final title in titles) {
      if (title?.trim().toLowerCase() == normalizedCandidate) {
        return true;
      }
    }

    return false;
  }

  List<String> _expandQueryVariants(String value, AnimeFormat format) {
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

    void addBareTrailingSeasonVariants(String candidate) {
      if (format != AnimeFormat.tv) {
        return;
      }

      final bareTrailingSeason = _tryParseBareTrailingSeasonTitle(candidate);
      if (bareTrailingSeason == null) {
        return;
      }

      add(
        '${bareTrailingSeason.rootTitle} ${_ordinal(bareTrailingSeason.seasonNumber)} Season',
      );
      add(
        '${bareTrailingSeason.rootTitle} Season ${bareTrailingSeason.seasonNumber}',
      );
    }

    add(value);
    final stripped = _stripSearchNoise(value);
    add(stripped);
    addBareTrailingSeasonVariants(value);
    final withoutSeason = _stripSeasonDescriptor(value);
    add(withoutSeason);
    add(_stripSearchNoise(withoutSeason));
    add(_swapSeasonNotation(value));
    add(_swapSeasonNotation(withoutSeason));

    final withoutTrailingParenthetical = _stripTrailingParenthetical(
      withoutSeason,
    );
    add(withoutTrailingParenthetical);
    addBareTrailingSeasonVariants(withoutTrailingParenthetical);
    add(_swapSeasonNotation(withoutTrailingParenthetical));

    final rootTitle = _extractRootTitle(withoutTrailingParenthetical);
    add(rootTitle);

    final rootPlusSuffix = _extractRootPlusSuffixTitle(withoutSeason);
    add(rootPlusSuffix);
    add(_extractRootPlusSuffixTitle(withoutTrailingParenthetical));

    return ordered;
  }

  ({String rootTitle, int seasonNumber})? _tryParseBareTrailingSeasonTitle(
    String value,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _hasExplicitSeasonDescriptor(trimmed)) {
      return null;
    }

    final match = RegExp(r'^(.*\S)\s+(\d+)$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final rootTitle = match.group(1)!.trim();
    final seasonNumber = int.tryParse(match.group(2) ?? '');
    if (seasonNumber == null || seasonNumber < 2 || seasonNumber > 12) {
      return null;
    }

    if (rootTitle.split(RegExp(r'\s+')).length < 2 || rootTitle.length < 6) {
      return null;
    }

    if (RegExp(r'^\d+$').hasMatch(rootTitle)) {
      return null;
    }

    return (rootTitle: rootTitle, seasonNumber: seasonNumber);
  }

  /// Strips punctuation, commas, quotes, and collapses honorific hyphens
  /// so search queries are closer to how source sites index titles.
  String _stripSearchNoise(String value) {
    return value
        .replaceAll(
          RegExp(
            r'(?<=[a-zA-Z])-(?=sama|san|chan|kun)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp('[,"\'`]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _hasExplicitSeasonDescriptor(String value) {
    return RegExp(
      r'\b(?:season|part|cour)\b',
      caseSensitive: false,
    ).hasMatch(value);
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
    final bareTrailingSeasonSlug = _tryParseBareTrailingSeasonSlug(slug);
    if (bareTrailingSeasonSlug != null) {
      yield '${bareTrailingSeasonSlug.rootSlug}-${_ordinal(bareTrailingSeasonSlug.seasonNumber)}-season';
      yield '${bareTrailingSeasonSlug.rootSlug}-season-${bareTrailingSeasonSlug.seasonNumber}';
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

  ({String rootSlug, int seasonNumber})? _tryParseBareTrailingSeasonSlug(
    String slug,
  ) {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.contains('season-') ||
        normalized.contains('-season') ||
        normalized.contains('part-') ||
        normalized.contains('-part')) {
      return null;
    }

    final match = RegExp(r'^(.*)-(\d+)$').firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final rootSlug = match.group(1)!.trim();
    final seasonNumber = int.tryParse(match.group(2) ?? '');
    if (seasonNumber == null || seasonNumber < 2 || seasonNumber > 12) {
      return null;
    }

    if (rootSlug.split('-').length < 2 ||
        rootSlug.replaceAll('-', '').length < 6) {
      return null;
    }

    return (rootSlug: rootSlug, seasonNumber: seasonNumber);
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

  void _debugLog(String message) {
    assert(() {
      developer.log(message, name: 'kumoriya.source_availability');
      // ignore: avoid_print
      print('[KSA] $message');
      return true;
    }());
  }

  String _episodeRange(Iterable<dynamic> episodes) {
    var count = 0;
    double? min;
    double? max;
    String? lastId;
    for (final episode in episodes) {
      final (number, sourceId) = switch (episode) {
        AnimeEpisode e => (e.number, null),
        SourceEpisode e => (e.number, e.sourceEpisodeId),
        _ => (null, null),
      };
      if (number == null) {
        continue;
      }
      count++;
      min = min == null || number < min ? number : min;
      max = max == null || number > max ? number : max;
      lastId = sourceId ?? lastId;
    }
    if (count == 0) {
      return '0';
    }
    final idSuffix = lastId == null ? '' : ':last=$lastId';
    return '$count(${_numberLabel(min!)}-${_numberLabel(max!)})$idSuffix';
  }

  String _numberLabel(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(3);
  }
}
