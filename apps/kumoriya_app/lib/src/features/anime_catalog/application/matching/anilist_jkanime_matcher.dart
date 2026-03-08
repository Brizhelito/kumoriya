import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/source_availability.dart';

final class AnilistJkanimeMatcher {
  const AnilistJkanimeMatcher();

  SourceMatchDecision decideMatch({
    required AnimeDetail anilistDetail,
    required List<SourceAnimeMatch> candidates,
  }) {
    if (candidates.isEmpty) {
      return const SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'No JKAnime candidates were returned.',
        acceptanceSignals: <String>[],
        rejectionSignals: <String>['empty-candidate-list'],
      );
    }

    final canonicalTitles = _buildCanonicalTitles(anilistDetail.anime.title);
    final scored =
        candidates
            .map(
              (candidate) => _scoreCandidate(
                anilistDetail: anilistDetail,
                candidate: candidate,
                canonicalTitles: canonicalTitles,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    final hasConflicts = best.decision.rejectionSignals.any(
      (signal) => signal.startsWith('conflict-'),
    );

    final secondScore = scored.length > 1 ? scored[1].score : -999;
    final ambiguousTop = (best.score - secondScore).abs() < 8;
    if (ambiguousTop) {
      return SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'Ambiguous JKAnime candidates with similar confidence.',
        acceptanceSignals: best.decision.acceptanceSignals,
        rejectionSignals: <String>[
          ...best.decision.rejectionSignals,
          'ambiguous-top-candidates',
        ],
      );
    }

    final canAccept =
        best.decision.confidence == MatchConfidence.high &&
        best.decision.acceptanceSignals.contains('exact-title') &&
        !hasConflicts;

    if (canAccept) {
      return best.decision;
    }

    return SourceMatchDecision(
      verdict: false,
      confidence: best.decision.confidence,
      reason: 'Matching confidence is insufficient for safe auto-link.',
      acceptanceSignals: best.decision.acceptanceSignals,
      rejectionSignals: <String>[
        ...best.decision.rejectionSignals,
        'insufficient-confidence',
      ],
    );
  }

  _ScoredDecision _scoreCandidate({
    required AnimeDetail anilistDetail,
    required SourceAnimeMatch candidate,
    required Set<String> canonicalTitles,
  }) {
    var score = 0;
    final acceptanceSignals = <String>[];
    final rejectionSignals = <String>[];

    final normalizedCandidateTitle = _normalize(candidate.title);
    if (normalizedCandidateTitle.isEmpty) {
      return const _ScoredDecision(
        score: -100,
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
    if (exactTitle) {
      score += 120;
      acceptanceSignals.add('exact-title');
    } else {
      final tokenOverlap = _maxTokenOverlap(
        normalizedCandidateTitle,
        canonicalTitles,
      );
      if (tokenOverlap >= 0.90) {
        score += 35;
        acceptanceSignals.add('token-overlap-high');
      } else if (tokenOverlap >= 0.75) {
        score += 10;
        rejectionSignals.add('weak-token-overlap');
      } else {
        rejectionSignals.add('title-mismatch');
      }
    }

    final candidateFormat = candidate.format;
    final anilistFormat = anilistDetail.anime.format;
    if (candidateFormat != AnimeFormat.unknown &&
        anilistFormat != AnimeFormat.unknown) {
      if (candidateFormat == anilistFormat) {
        score += 12;
        acceptanceSignals.add('format-match');
      } else {
        score -= 25;
        rejectionSignals.add('conflict-format');
      }
    }

    final candidateYear = candidate.releaseYear;
    final anilistYear = anilistDetail.anime.releaseYear;
    if (candidateYear != null && anilistYear != null) {
      if (candidateYear == anilistYear) {
        score += 10;
        acceptanceSignals.add('year-match');
      } else {
        score -= 30;
        rejectionSignals.add('conflict-year');
      }
    }

    final confidence = _confidenceFor(score: score, exactTitle: exactTitle);

    return _ScoredDecision(
      score: score,
      decision: SourceMatchDecision(
        verdict: confidence == MatchConfidence.high && exactTitle,
        confidence: confidence,
        reason: confidence == MatchConfidence.high
            ? 'Strong unique title alignment with no material conflicts.'
            : 'Candidate did not satisfy conservative acceptance rules.',
        acceptanceSignals: acceptanceSignals,
        rejectionSignals: rejectionSignals,
        candidate: candidate,
      ),
    );
  }

  MatchConfidence _confidenceFor({
    required int score,
    required bool exactTitle,
  }) {
    if (exactTitle && score >= 90) {
      return MatchConfidence.high;
    }
    if (score >= 70) {
      return MatchConfidence.medium;
    }
    return MatchConfidence.low;
  }

  Set<String> _buildCanonicalTitles(AnimeTitle title) {
    final values = <String>{
      title.romaji,
      if (title.english != null) title.english!,
      if (title.native != null) title.native!,
      ...title.synonyms,
    };

    return values.map(_normalize).where((value) => value.isNotEmpty).toSet();
  }

  double _maxTokenOverlap(String candidate, Set<String> canonicalTitles) {
    final candidateTokens = _tokenize(candidate);
    if (candidateTokens.isEmpty) {
      return 0;
    }

    var maxOverlap = 0.0;
    for (final canonical in canonicalTitles) {
      final canonicalTokens = _tokenize(canonical);
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

  Set<String> _tokenize(String text) {
    final parts = text.split(' ');
    return parts.where((part) => part.isNotEmpty).toSet();
  }

  String _normalize(String input) {
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
  const _ScoredDecision({required this.score, required this.decision});

  final int score;
  final SourceMatchDecision decision;
}
