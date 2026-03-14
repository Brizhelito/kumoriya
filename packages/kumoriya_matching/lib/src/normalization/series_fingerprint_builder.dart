import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/canonical_series.dart';
import '../models/series_record.dart';

final class NormalizedSeriesTitle {
  const NormalizedSeriesTitle({
    required this.raw,
    required this.normalized,
    required this.compact,
    required this.tokens,
    required this.significantTokens,
    required this.sortedTokens,
    required this.rootTitle,
    required this.baseTitle,
  });

  final String raw;
  final String normalized;
  final String compact;
  final List<String> tokens;
  final Set<String> significantTokens;
  final List<String> sortedTokens;
  final String rootTitle;
  final String baseTitle;

  Set<String> get trigrams => _buildTrigrams(normalized);
}

final class SeriesFingerprint<T> {
  const SeriesFingerprint({
    required this.payload,
    required this.identifier,
    required this.titles,
    required this.primaryTitle,
    required this.aliases,
    required this.format,
    required this.releaseYear,
    required this.episodeCount,
    required this.seasonInfo,
    required this.blockingKeys,
  });

  final T payload;
  final String identifier;
  final List<NormalizedSeriesTitle> titles;
  final NormalizedSeriesTitle primaryTitle;
  final Set<String> aliases;
  final AnimeFormat format;
  final int? releaseYear;
  final int? episodeCount;
  final SeriesSeasonInfo seasonInfo;
  final Set<String> blockingKeys;

  bool get isSparse =>
      primaryTitle.significantTokens.length < 2 &&
      aliases.length < 2 &&
      releaseYear == null &&
      format == AnimeFormat.unknown;
}

final class SeriesFingerprintBuilder {
  const SeriesFingerprintBuilder();

  SeriesFingerprint<SourceSeriesRecord> fromSource(SourceSeriesRecord record) {
    final titles = _normalizeTitles(record.titles);
    return SeriesFingerprint<SourceSeriesRecord>(
      payload: record,
      identifier: record.recordId,
      titles: titles,
      primaryTitle: titles.first,
      aliases: titles.map((title) => title.normalized).toSet(),
      format: record.format,
      releaseYear: record.releaseYear,
      episodeCount: record.episodeCount,
      seasonInfo: record.seasonInfo,
      blockingKeys: _buildBlockingKeys(
        titles: titles,
        releaseYear: record.releaseYear,
        seasonInfo: record.seasonInfo,
      ),
    );
  }

  SeriesFingerprint<CanonicalSeries> fromCanonical(CanonicalSeries series) {
    final titles = _normalizeTitles(series.titles);
    return SeriesFingerprint<CanonicalSeries>(
      payload: series,
      identifier: series.canonicalId,
      titles: titles,
      primaryTitle: titles.first,
      aliases: titles.map((title) => title.normalized).toSet(),
      format: series.format,
      releaseYear: series.releaseYear,
      episodeCount: series.episodeCount,
      seasonInfo: series.seasonInfo,
      blockingKeys: _buildBlockingKeys(
        titles: titles,
        releaseYear: series.releaseYear,
        seasonInfo: series.seasonInfo,
      ),
    );
  }

  List<NormalizedSeriesTitle> _normalizeTitles(List<String> inputTitles) {
    final seen = <String>{};
    final normalized = <NormalizedSeriesTitle>[];
    for (final input in inputTitles) {
      final title = _normalizeTitle(input);
      if (title.normalized.isEmpty || !seen.add(title.normalized)) {
        continue;
      }
      normalized.add(title);
    }
    return normalized.isEmpty
        ? <NormalizedSeriesTitle>[_normalizeTitle('')]
        : normalized;
  }

  NormalizedSeriesTitle _normalizeTitle(String raw) {
    final lowered = _stripDiacritics(raw.trim().toLowerCase());
    final cleaned = _normalizeSeasonMarkers(
      lowered
          .replaceAll(RegExp("[\\(\\)\\[\\]\\{\\}!?,.\\\"'`]+"), ' ')
          .replaceAll(RegExp(r'[:/_\\|+-]+'), ' ')
          .replaceAll('&', ' and '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    final tokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_normalizeToken)
        .toList(growable: false);
    final baseTokens = tokens
        .where((token) => !_seasonMarkerTokens.contains(token))
        .toList(growable: false);
    final significantTokens = tokens
        .where((token) => !_lowSignalTokens.contains(token))
        .toSet();
    final sortedTokens = [...tokens]..sort();
    final rootTitle = _extractRootTitle(cleaned, baseTokens.join(' ').trim());
    return NormalizedSeriesTitle(
      raw: raw,
      normalized: tokens.join(' ').trim(),
      compact: tokens.join(),
      tokens: tokens,
      significantTokens: significantTokens,
      sortedTokens: sortedTokens,
      rootTitle: rootTitle,
      baseTitle: baseTokens.join(' ').trim(),
    );
  }

  Set<String> _buildBlockingKeys({
    required List<NormalizedSeriesTitle> titles,
    required int? releaseYear,
    required SeriesSeasonInfo seasonInfo,
  }) {
    final keys = <String>{};
    for (final title in titles) {
      if (title.compact.isNotEmpty) {
        keys.add('exact:${title.compact}');
      }
      if (title.rootTitle.isNotEmpty) {
        keys.add('root:${title.rootTitle}');
      }
      final significant = title.significantTokens.toList(growable: false)
        ..sort();
      if (significant.length >= 2) {
        keys.add('pair:${significant[0]}:${significant[1]}');
      } else if (significant.length == 1) {
        keys.add('token:${significant.first}');
      }
      if (releaseYear != null && title.rootTitle.isNotEmpty) {
        keys.add('year:$releaseYear:${title.rootTitle}');
      }
      if (seasonInfo.seasonNumber != null && title.rootTitle.isNotEmpty) {
        keys.add('season:${title.rootTitle}:s${seasonInfo.seasonNumber}');
      }
      if (seasonInfo.partNumber != null && title.rootTitle.isNotEmpty) {
        keys.add('part:${title.rootTitle}:p${seasonInfo.partNumber}');
      }
    }
    return keys;
  }

  String _extractRootTitle(String cleaned, String baseTitle) {
    if (cleaned.contains(':')) {
      return cleaned.split(':').first.trim();
    }
    if (cleaned.contains(' - ')) {
      return cleaned.split(' - ').first.trim();
    }
    return baseTitle;
  }

  String _normalizeToken(String token) {
    switch (token) {
      case 'ii':
        return '2';
      case 'iii':
        return '3';
      case 'iv':
        return '4';
      case 'v':
        return '5';
      case 'first':
        return '1';
      case 'second':
        return '2';
      case 'third':
        return '3';
      case 'fourth':
        return '4';
      case 'fifth':
        return '5';
      default:
        return token;
    }
  }

  String _normalizeSeasonMarkers(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\b(\d+)(st|nd|rd|th)\s+season\b'),
          (match) => ' season ${match.group(1)} ',
        )
        .replaceAllMapped(
          RegExp(r'\bseason\s+(\d+)\b'),
          (match) => ' season ${match.group(1)} ',
        )
        .replaceAllMapped(
          RegExp(r'\bpart\s+(\d+)\b'),
          (match) => ' part ${match.group(1)} ',
        )
        .replaceAllMapped(
          RegExp(r'\bcour\s+(\d+)\b'),
          (match) => ' cour ${match.group(1)} ',
        );
  }

  String _stripDiacritics(String value) {
    return value
        .replaceAll('\u00E1', 'a')
        .replaceAll('\u00E0', 'a')
        .replaceAll('\u00E4', 'a')
        .replaceAll('\u00E2', 'a')
        .replaceAll('\u00E3', 'a')
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
        .replaceAll('\u00F5', 'o')
        .replaceAll('\u00FA', 'u')
        .replaceAll('\u00F9', 'u')
        .replaceAll('\u00FC', 'u')
        .replaceAll('\u00FB', 'u')
        .replaceAll('\u00F1', 'n');
  }
}

const Set<String> _lowSignalTokens = <String>{
  'the',
  'a',
  'an',
  'tv',
  'anime',
  'series',
  'project',
};

const Set<String> _seasonMarkerTokens = <String>{
  'season',
  'part',
  'cour',
  '1',
  '2',
  '3',
  '4',
  '5',
  'final',
};

Set<String> _buildTrigrams(String input) {
  final normalized = '#$input#';
  if (normalized.length < 3) {
    return <String>{normalized};
  }
  final trigrams = <String>{};
  for (var index = 0; index <= normalized.length - 3; index++) {
    trigrams.add(normalized.substring(index, index + 3));
  }
  return trigrams;
}
