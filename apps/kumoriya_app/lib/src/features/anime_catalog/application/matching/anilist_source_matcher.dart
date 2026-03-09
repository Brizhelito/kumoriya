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
                canonicalHasSubtitleBearingTitle:
                    canonicalHasSubtitleBearingTitle,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    final secondScore = scored.length > 1 ? scored[1].score : -999;
    final ambiguousTop =
        best.decision.confidence == MatchConfidence.high &&
        (best.score - secondScore).abs() < 10;
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

    final exactTitle = canonicalTitles.contains(normalizedCandidateTitle);
    final sharedRootTitle = canonicalTitles.any(
      (title) =>
          title.rootTitle.isNotEmpty &&
          title.rootTitle == normalizedCandidateTitle.rootTitle,
    );
    var groupedSeasonTitle = false;
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
      hasStrongTitleAlignment: exactTitle || groupedSeasonTitle,
    );
    final hasStrongTitleAlignment = exactTitle || groupedSeasonTitle;

    return _ScoredDecision(
      score: score,
      hasStrongTitleAlignment: hasStrongTitleAlignment,
      sharedRootTitle: sharedRootTitle,
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

    return values
        .map(_normalizeTitle)
        .where((value) => value.normalized.isNotEmpty)
        .toSet();
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
    if (root.split(' ').length >= 2 && root.length >= 10) {
      return _normalizeLoose(root);
    }
    if (baseTitle.split(' ').length >= 2 && baseTitle.length >= 10) {
      return baseTitle;
    }
    return '';
  }

  String _normalizeLoose(String input) {
    final lower = _stripDiacritics(input.toLowerCase());
    final normalizedSeparators = lower
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
}

final class _ScoredDecision {
  const _ScoredDecision({
    required this.score,
    required this.hasStrongTitleAlignment,
    required this.sharedRootTitle,
    required this.normalizedTitleLength,
    required this.canonicalHasSubtitleBearingTitle,
    required this.decision,
  });

  final int score;
  final bool hasStrongTitleAlignment;
  final bool sharedRootTitle;
  final int normalizedTitleLength;
  final bool canonicalHasSubtitleBearingTitle;
  final SourceMatchDecision decision;
}

final class _NormalizedTitle {
  const _NormalizedTitle({
    required this.normalized,
    required this.orderedTokens,
    required this.baseTitle,
    required this.rootTitle,
    required this.subtitleBearing,
    required this.hasSeasonMarker,
  });

  final String normalized;
  final List<String> orderedTokens;
  final String baseTitle;
  final String rootTitle;
  final bool subtitleBearing;
  final bool hasSeasonMarker;

  Set<String> get tokens => orderedTokens.toSet();

  @override
  bool operator ==(Object other) {
    return other is _NormalizedTitle && other.normalized == normalized;
  }

  @override
  int get hashCode => normalized.hashCode;
}
