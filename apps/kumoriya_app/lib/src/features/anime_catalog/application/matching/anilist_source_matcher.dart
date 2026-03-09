import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/source_availability.dart';

final class AnilistSourceMatcher {
  const AnilistSourceMatcher();

  SourceMatchDecision decideMatch({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> candidates,
  }) {
    if (candidates.isEmpty) {
      return const SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'No source candidates were returned.',
        acceptanceSignals: <String>[],
        rejectionSignals: <String>['empty-candidate-list'],
      );
    }

    final canonicalTitles = _buildCanonicalTitles(anilistDetail.anime.title);
    final canonicalAliasRoots = _buildCanonicalAliasRoots(
      anilistDetail.anime.title,
    );
    final canonicalHasSubtitleBearingTitle = canonicalTitles.any(
      (title) => title.subtitleBearing,
    );
    final scored =
        candidates
            .map(
              (candidate) => _scoreCandidate(
                anilistDetail: anilistDetail,
                candidate: candidate,
                canonicalTitles: canonicalTitles,
                canonicalAliasRoots: canonicalAliasRoots,
                canonicalHasSubtitleBearingTitle:
                    canonicalHasSubtitleBearingTitle,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    final secondScore = scored.length > 1 ? scored[1].score : -999;
    final bestTitleSignalRank = _titleSignalRank(best.decision);
    final secondTitleSignalRank = scored.length > 1
        ? _titleSignalRank(scored[1].decision)
        : -1;
    final ambiguousTop =
        best.decision.confidence == MatchConfidence.high &&
        (best.score - secondScore).abs() < 10 &&
        bestTitleSignalRank == secondTitleSignalRank;
    final hasConflicts = best.decision.rejectionSignals.any(
      (signal) => signal.startsWith('conflict-'),
    );

    if (ambiguousTop) {
      return SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'Multiple candidates satisfy the same conservative title rule.',
        acceptanceSignals: best.decision.acceptanceSignals,
        rejectionSignals: <String>[
          ...best.decision.rejectionSignals,
          'ambiguous-top-candidates',
        ],
      );
    }

    final canAccept =
        best.decision.confidence == MatchConfidence.high &&
        best.hasStrongTitleAlignment &&
        !hasConflicts;

    if (canAccept) {
      return best.decision;
    }

    final franchiseRootFallback = _selectFranchiseRootFallback(scored);
    if (franchiseRootFallback != null) {
      return franchiseRootFallback;
    }

    return SourceMatchDecision(
      verdict: false,
      confidence: best.decision.confidence,
      reason: best.hasStrongTitleAlignment
          ? 'Candidate conflicts with conservative metadata checks.'
          : 'No conservative AniList/source title alignment was found.',
      acceptanceSignals: best.decision.acceptanceSignals,
      rejectionSignals: <String>[
        ...best.decision.rejectionSignals,
        if (!best.hasStrongTitleAlignment) 'no-exact-title-match',
        'insufficient-confidence',
      ],
    );
  }

  _ScoredDecision _scoreCandidate({
    required AnimeDetail anilistDetail,
    required SourceAnimeMatch candidate,
    required Set<_NormalizedTitle> canonicalTitles,
    required Set<String> canonicalAliasRoots,
    required bool canonicalHasSubtitleBearingTitle,
  }) {
    var score = 0;
    final acceptanceSignals = <String>[];
    final rejectionSignals = <String>[];

    final normalizedCandidateTitle = _normalizeTitle(candidate.title);
    if (normalizedCandidateTitle.normalized.isEmpty) {
      return const _ScoredDecision(
        score: -100,
        hasStrongTitleAlignment: false,
        sharedRootTitle: false,
        rootTitleWordCount: 0,
        normalizedTitleLength: 0,
        canonicalHasSubtitleBearingTitle: false,
        decision: SourceMatchDecision(
          verdict: false,
          confidence: MatchConfidence.low,
          reason: 'Candidate title could not be normalized.',
          acceptanceSignals: <String>[],
          rejectionSignals: <String>['empty-normalized-title'],
        ),
      );
    }

    final exactTitle = canonicalTitles.any(
      (title) =>
          title.normalized == normalizedCandidateTitle.normalized ||
          title.compactNormalized == normalizedCandidateTitle.compactNormalized,
    );
    final sharedRootTitle = canonicalTitles.any(
      (title) =>
          title.rootTitle.isNotEmpty &&
          title.rootTitle == normalizedCandidateTitle.rootTitle,
    );
    var groupedSeasonTitle = false;
    var candidateSubtitleExpansion = false;
    var sharedSubtitleRootTitle = false;
    var genericSuffixAliasTitle = false;
    if (exactTitle) {
      score += 100;
      acceptanceSignals.add('exact-title');
    } else {
      groupedSeasonTitle = canonicalTitles.any(
        (title) =>
            title.baseTitle == normalizedCandidateTitle.baseTitle &&
            title.baseTitle.isNotEmpty &&
            title.hasSeasonMarker &&
            !normalizedCandidateTitle.hasSeasonMarker,
      );
      if (groupedSeasonTitle) {
        score += 92;
        acceptanceSignals.add('grouped-season-title');
      } else {
        candidateSubtitleExpansion = canonicalTitles.any(
          (title) =>
              !title.subtitleBearing &&
              title.normalized == normalizedCandidateTitle.rootTitle &&
              normalizedCandidateTitle.subtitleBearing,
        );
        if (candidateSubtitleExpansion) {
          score += 91;
          acceptanceSignals.add('candidate-subtitle-expansion');
        } else {
          sharedSubtitleRootTitle = canonicalTitles.any((title) {
            if (!title.subtitleBearing ||
                !normalizedCandidateTitle.subtitleBearing ||
                title.rootTitle.isEmpty ||
                title.rootTitle != normalizedCandidateTitle.rootTitle) {
              return false;
            }

            final metrics = _subtitleTailMetrics(
              title,
              normalizedCandidateTitle,
            );
            return metrics.overlap >= 0.45 && metrics.lengthRatio >= 0.75;
          });
          if (sharedSubtitleRootTitle) {
            score += 89;
            acceptanceSignals.add('shared-subtitle-root');
          } else {
            genericSuffixAliasTitle = _matchesCanonicalAliasWithGenericSuffix(
              canonicalAliasRoots: canonicalAliasRoots,
              candidate: normalizedCandidateTitle,
            );
            if (genericSuffixAliasTitle) {
              score += 88;
              acceptanceSignals.add('canonical-prefix-generic-suffix');
            } else {
              final tokenOverlap = _maxTokenOverlap(
                normalizedCandidateTitle,
                canonicalTitles,
              );
              if (tokenOverlap >= 0.75) {
                rejectionSignals.add('weak-token-overlap');
              } else {
                rejectionSignals.add('title-mismatch');
              }
            }
          }
        }
      }
    }

    final candidateFormat = candidate.format;
    final anilistFormat = anilistDetail.anime.format;
    if (candidateFormat != AnimeFormat.unknown &&
        anilistFormat != AnimeFormat.unknown) {
      if (candidateFormat == anilistFormat) {
        score += 15;
        acceptanceSignals.add('format-match');
      } else {
        score -= 30;
        rejectionSignals.add('conflict-format');
      }
    }

    final candidateYear = candidate.releaseYear;
    final anilistYear = anilistDetail.anime.releaseYear;
    if (candidateYear != null && anilistYear != null) {
      if (candidateYear == anilistYear) {
        score += 10;
        acceptanceSignals.add('year-match');
      } else if (groupedSeasonTitle && candidateYear < anilistYear) {
        acceptanceSignals.add('grouped-season-year-gap');
      } else {
        score -= 35;
        rejectionSignals.add('conflict-year');
      }
    }

    final confidence = _confidenceFor(
      score: score,
      hasStrongTitleAlignment:
          exactTitle ||
          groupedSeasonTitle ||
          candidateSubtitleExpansion ||
          sharedSubtitleRootTitle ||
          genericSuffixAliasTitle,
    );
    final hasStrongTitleAlignment =
        exactTitle ||
        groupedSeasonTitle ||
        candidateSubtitleExpansion ||
        sharedSubtitleRootTitle ||
        genericSuffixAliasTitle;

    return _ScoredDecision(
      score: score,
      hasStrongTitleAlignment: hasStrongTitleAlignment,
      sharedRootTitle: sharedRootTitle,
      rootTitleWordCount: normalizedCandidateTitle.rootTitleWordCount,
      normalizedTitleLength: normalizedCandidateTitle.normalized.length,
      canonicalHasSubtitleBearingTitle: canonicalHasSubtitleBearingTitle,
      decision: SourceMatchDecision(
        verdict: confidence == MatchConfidence.high && hasStrongTitleAlignment,
        confidence: confidence,
        reason: confidence == MatchConfidence.high
            ? 'Strong AniList/source title alignment with no material conflicts.'
            : 'Candidate did not satisfy conservative acceptance rules.',
        acceptanceSignals: acceptanceSignals,
        rejectionSignals: rejectionSignals,
        candidate: candidate,
      ),
    );
  }

  SourceMatchDecision? _selectFranchiseRootFallback(
    List<_ScoredDecision> scored,
  ) {
    final rootCompatible = scored
        .where((candidate) {
          final rejections = candidate.decision.rejectionSignals;
          final hasHardConflict = rejections.any(
            (signal) =>
                signal == 'conflict-format' || signal == 'conflict-year',
          );
          return candidate.sharedRootTitle && !hasHardConflict;
        })
        .toList(growable: false);

    if (rootCompatible.isEmpty) {
      return null;
    }
    if (rootCompatible.length < 2) {
      return null;
    }
    if (rootCompatible.any((candidate) => candidate.rootTitleWordCount < 2)) {
      return null;
    }

    final allSubtitleBearing = rootCompatible.every(
      (candidate) => candidate.canonicalHasSubtitleBearingTitle,
    );
    if (!allSubtitleBearing) {
      return null;
    }

    final shortestLength = rootCompatible
        .map((candidate) => candidate.normalizedTitleLength)
        .reduce((a, b) => a < b ? a : b);
    final shortestCandidates = rootCompatible
        .where((candidate) => candidate.normalizedTitleLength == shortestLength)
        .toList(growable: false);
    if (shortestCandidates.length != 1) {
      return null;
    }

    final candidate = shortestCandidates.single;
    return SourceMatchDecision(
      verdict: true,
      confidence: MatchConfidence.high,
      reason:
          'Source candidates collapse to a single franchise root and one umbrella entry.',
      acceptanceSignals: <String>[
        ...candidate.decision.acceptanceSignals,
        'franchise-root-grouping',
      ],
      rejectionSignals: candidate.decision.rejectionSignals,
      candidate: candidate.decision.candidate,
    );
  }

  MatchConfidence _confidenceFor({
    required int score,
    required bool hasStrongTitleAlignment,
  }) {
    if (hasStrongTitleAlignment && score >= 85) {
      return MatchConfidence.high;
    }
    if (hasStrongTitleAlignment && score >= 60) {
      return MatchConfidence.medium;
    }
    return MatchConfidence.low;
  }

  Set<_NormalizedTitle> _buildCanonicalTitles(AnimeTitle title) {
    final values = <String>{
      title.romaji,
      if (title.english != null) title.english!,
      if (title.native != null) title.native!,
      ...title.synonyms,
    };
    final expanded = <String>{};
    for (final value in values) {
      expanded.add(value);
      final withoutSeason = _swapSeasonNotation(value);
      expanded.add(withoutSeason);
    }

    return expanded
        .map(_normalizeTitle)
        .where((value) => value.normalized.isNotEmpty)
        .toSet();
  }

  Set<String> _buildCanonicalAliasRoots(AnimeTitle title) {
    final rawValues = <String>{
      title.romaji,
      if (title.english != null) title.english!,
      if (title.native != null) title.native!,
      ...title.synonyms,
    };
    final roots = <String>{};

    for (final raw in rawValues) {
      final stripped = _stripTrailingParenthetical(raw);
      final normalized = _normalizeLoose(stripped);
      final tokens = normalized
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      if (tokens.length == 1 && tokens.first.length >= 7) {
        roots.add(normalized);
      }
    }

    return roots;
  }

  double _maxTokenOverlap(
    _NormalizedTitle candidate,
    Set<_NormalizedTitle> canonicalTitles,
  ) {
    final candidateTokens = candidate.tokens;
    if (candidateTokens.isEmpty) {
      return 0;
    }

    var maxOverlap = 0.0;
    for (final canonical in canonicalTitles) {
      final canonicalTokens = canonical.tokens;
      if (canonicalTokens.isEmpty) {
        continue;
      }

      final intersection = candidateTokens.intersection(canonicalTokens).length;
      final union = candidateTokens.union(canonicalTokens).length;
      final overlap = union == 0 ? 0.0 : intersection / union;
      if (overlap > maxOverlap) {
        maxOverlap = overlap;
      }
    }

    return maxOverlap;
  }

  _NormalizedTitle _normalizeTitle(String input) {
    final normalized = _normalizeLoose(input);
    final orderedTokens = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final baseTitle = _stripSeasonTokens(orderedTokens).join(' ').trim();

    return _NormalizedTitle(
      normalized: normalized,
      compactNormalized: normalized.replaceAll(' ', ''),
      orderedTokens: orderedTokens,
      baseTitle: baseTitle,
      rootTitle: _extractRootTitle(input, baseTitle),
      subtitleBearing: _isSubtitleBearing(input),
      hasSeasonMarker:
          orderedTokens.length != _stripSeasonTokens(orderedTokens).length,
    );
  }

  bool _isSubtitleBearing(String rawInput) {
    final trimmed = rawInput.trim();
    return trimmed.contains(':') || trimmed.contains(' - ');
  }

  String _extractRootTitle(String rawInput, String baseTitle) {
    final trimmed = rawInput.trim();
    final splitOnDash = trimmed.split(' - ');
    final dashCandidate = splitOnDash.length > 1 ? splitOnDash.first : trimmed;
    final root = dashCandidate.split(':').first.trim();
    final hasExplicitSubtitle =
        trimmed.contains(':') || trimmed.contains(' - ');
    if (hasExplicitSubtitle && root.length >= 4) {
      return _normalizeLoose(root);
    }
    if (baseTitle.split(' ').length >= 2 && baseTitle.length >= 10) {
      return baseTitle;
    }
    return '';
  }

  String _extractRootPlusSuffixTitle(String rawInput) {
    final trimmed = rawInput.trim();
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

  String _normalizeLoose(String input) {
    final lower = _stripDiacritics(input.toLowerCase());
    final romanizationNormalized = lower
        .replaceAll(RegExp(r'\bno de\b', caseSensitive: false), 'node')
        .replaceAll(RegExp(r'\bomou na\b', caseSensitive: false), 'omouna');
    final normalizedSeparators = romanizationNormalized
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll('/', ' ')
        .replaceAll(':', ' ')
        .replaceAll('.', ' ');

    final builder = StringBuffer();
    var previousWasSpace = false;

    for (final codeUnit in normalizedSeparators.codeUnits) {
      final isLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isSpace = codeUnit == 32;

      if (isLetter || isDigit) {
        builder.writeCharCode(codeUnit);
        previousWasSpace = false;
        continue;
      }

      if (isSpace && !previousWasSpace) {
        builder.write(' ');
        previousWasSpace = true;
      }
    }

    return builder.toString().trim();
  }

  List<String> _stripSeasonTokens(List<String> orderedTokens) {
    if (orderedTokens.isEmpty) {
      return orderedTokens;
    }

    final tokens = List<String>.from(orderedTokens);
    while (tokens.isNotEmpty) {
      final removed = _tryRemoveSeasonSuffix(tokens);
      if (!removed) {
        break;
      }
    }
    return tokens;
  }

  bool _tryRemoveSeasonSuffix(List<String> tokens) {
    if (tokens.isEmpty) {
      return false;
    }

    final last = tokens.last;
    if (_isRomanSeasonToken(last)) {
      tokens.removeLast();
      return true;
    }

    if (tokens.length >= 2) {
      final secondLast = tokens[tokens.length - 2];
      final previousIsNumeric = RegExp(r'^\d+$').hasMatch(secondLast);
      if (_isOrdinalSeasonToken(last) &&
          !previousIsNumeric &&
          tokens.length >= 3) {
        tokens.removeLast();
        return true;
      }
      if (last == 'season' &&
          (_isOrdinalSeasonToken(secondLast) ||
              _isRomanSeasonToken(secondLast))) {
        tokens.removeRange(tokens.length - 2, tokens.length);
        return true;
      }
      if ((_isOrdinalSeasonToken(last) || _isRomanSeasonToken(last)) &&
          secondLast == 'season') {
        tokens.removeRange(tokens.length - 2, tokens.length);
        return true;
      }
      if (secondLast == 'part' && _isOrdinalSeasonToken(last)) {
        tokens.removeRange(tokens.length - 2, tokens.length);
        return true;
      }
      if (secondLast == 'cour' && _isOrdinalSeasonToken(last)) {
        tokens.removeRange(tokens.length - 2, tokens.length);
        return true;
      }
    }

    return false;
  }

  bool _isOrdinalSeasonToken(String value) {
    return RegExp(
      r'^(?:\d+|\d+(?:st|nd|rd|th)|first|second|third|fourth|fifth)$',
    ).hasMatch(value);
  }

  bool _isRomanSeasonToken(String value) {
    return const <String>{'ii', 'iii', 'iv', 'v'}.contains(value);
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

  _SubtitleTailMetrics _subtitleTailMetrics(
    _NormalizedTitle canonical,
    _NormalizedTitle candidate,
  ) {
    final canonicalRootTokens = canonical.rootTitle
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    final candidateRootTokens = candidate.rootTitle
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    final canonicalTail = canonical.tokens.difference(canonicalRootTokens);
    final candidateTail = candidate.tokens.difference(candidateRootTokens);
    if (canonicalTail.isEmpty || candidateTail.isEmpty) {
      return const _SubtitleTailMetrics(overlap: 0, lengthRatio: 0);
    }

    final intersection = canonicalTail.intersection(candidateTail).length;
    final union = canonicalTail.union(candidateTail).length;
    final overlap = union == 0 ? 0.0 : intersection / union;
    final shorter = canonicalTail.length < candidateTail.length
        ? canonicalTail.length
        : candidateTail.length;
    final longer = canonicalTail.length > candidateTail.length
        ? canonicalTail.length
        : candidateTail.length;
    final lengthRatio = longer == 0 ? 0.0 : shorter / longer;
    return _SubtitleTailMetrics(overlap: overlap, lengthRatio: lengthRatio);
  }

  bool _matchesCanonicalAliasWithGenericSuffix({
    required Set<String> canonicalAliasRoots,
    required _NormalizedTitle candidate,
  }) {
    const genericSuffixTokens = <String>{'anime', 'shinsaku', 'tv', 'series'};

    for (final alias in canonicalAliasRoots) {
      final aliasTokens = alias
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      if (aliasTokens.isEmpty ||
          candidate.orderedTokens.length <= aliasTokens.length) {
        continue;
      }

      var prefixMatches = true;
      for (var index = 0; index < aliasTokens.length; index++) {
        if (candidate.orderedTokens[index] != aliasTokens[index]) {
          prefixMatches = false;
          break;
        }
      }

      if (!prefixMatches) {
        continue;
      }

      final suffixTokens = candidate.orderedTokens.sublist(aliasTokens.length);
      if (suffixTokens.every(genericSuffixTokens.contains)) {
        return true;
      }
    }

    return false;
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

  int _titleSignalRank(SourceMatchDecision decision) {
    final acceptanceSignals = decision.acceptanceSignals;
    if (acceptanceSignals.contains('exact-title')) {
      return 5;
    }
    if (acceptanceSignals.contains('candidate-subtitle-expansion')) {
      return 4;
    }
    if (acceptanceSignals.contains('shared-subtitle-root')) {
      return 3;
    }
    if (acceptanceSignals.contains('canonical-prefix-generic-suffix')) {
      return 2;
    }
    if (acceptanceSignals.contains('grouped-season-title')) {
      return 1;
    }
    return 0;
  }
}

final class _ScoredDecision {
  const _ScoredDecision({
    required this.score,
    required this.hasStrongTitleAlignment,
    required this.sharedRootTitle,
    required this.rootTitleWordCount,
    required this.normalizedTitleLength,
    required this.canonicalHasSubtitleBearingTitle,
    required this.decision,
  });

  final int score;
  final bool hasStrongTitleAlignment;
  final bool sharedRootTitle;
  final int rootTitleWordCount;
  final int normalizedTitleLength;
  final bool canonicalHasSubtitleBearingTitle;
  final SourceMatchDecision decision;
}

final class _SubtitleTailMetrics {
  const _SubtitleTailMetrics({
    required this.overlap,
    required this.lengthRatio,
  });

  final double overlap;
  final double lengthRatio;
}

final class _NormalizedTitle {
  const _NormalizedTitle({
    required this.normalized,
    required this.compactNormalized,
    required this.orderedTokens,
    required this.baseTitle,
    required this.rootTitle,
    required this.subtitleBearing,
    required this.hasSeasonMarker,
  });

  final String normalized;
  final String compactNormalized;
  final List<String> orderedTokens;
  final String baseTitle;
  final String rootTitle;
  final bool subtitleBearing;
  final bool hasSeasonMarker;

  Set<String> get tokens => orderedTokens.toSet();

  int get rootTitleWordCount =>
      rootTitle.split(' ').where((token) => token.isNotEmpty).length;

  @override
  bool operator ==(Object other) {
    return other is _NormalizedTitle && other.normalized == normalized;
  }

  @override
  int get hashCode => normalized.hashCode;
}
