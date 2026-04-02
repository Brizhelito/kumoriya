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

  // Cached RegExp instances — avoid recompilation on every normalization call.
  static final RegExp _punctuationRe = RegExp(
    "[\\(\\)\\[\\]\\{\\}!?,.\\\"'`]+",
  );
  static final RegExp _separatorRe = RegExp(r'[:/_\\|+-]+');
  static final RegExp _honorificHyphenRe = RegExp(
    r'(?<=[a-z])-(?=sama|san|chan|kun|dono|senpai|sensei)\b',
  );
  static final RegExp _whitespaceRe = RegExp(r'\s+');
  static final RegExp _nonAlnumRe = RegExp(r'[^a-z0-9\s]+');
  static final RegExp _ordinalSeasonRe = RegExp(
    r'\b(\d+)(st|nd|rd|th)\s+season\b',
  );
  static final RegExp _seasonNumberRe = RegExp(r'\bseason\s+(\d+)\b');
  static final RegExp _partNumberRe = RegExp(r'\bpart\s+(\d+)\b');
  static final RegExp _courNumberRe = RegExp(r'\bcour\s+(\d+)\b');

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
    final honorificCollapsed = lowered.replaceAll(_honorificHyphenRe, '');
    final cleaned = _normalizeSeasonMarkers(
      honorificCollapsed
          .replaceAll(_punctuationRe, ' ')
          .replaceAll(_separatorRe, ' ')
          .replaceAll('&', ' and '),
    ).replaceAll(_whitespaceRe, ' ').trim();
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
    final rootTitle = _extractRootTitle(lowered, baseTokens.join(' ').trim());
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

  String _extractRootTitle(String rawLowered, String baseTitle) {
    for (final separator in const [':', ' - ']) {
      final index = rawLowered.indexOf(separator);
      if (index > 0) {
        final root = rawLowered
            .substring(0, index)
            .trim()
            .replaceAll(_nonAlnumRe, '')
            .replaceAll(_whitespaceRe, ' ')
            .trim();
        if (root.split(' ').where((w) => w.isNotEmpty).length >= 2 ||
            root.length >= 6) {
          return root;
        }
      }
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
          _ordinalSeasonRe,
          (match) => ' season ${match.group(1)} ',
        )
        .replaceAllMapped(
          _seasonNumberRe,
          (match) => ' season ${match.group(1)} ',
        )
        .replaceAllMapped(_partNumberRe, (match) => ' part ${match.group(1)} ')
        .replaceAllMapped(_courNumberRe, (match) => ' cour ${match.group(1)} ');
  }

  String _stripDiacritics(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      buffer.write(_diacriticMap[value[i]] ?? value[i]);
    }
    return buffer.toString();
  }

  static const Map<String, String> _diacriticMap = <String, String>{
    '\u00E1': 'a',
    '\u00E0': 'a',
    '\u00E4': 'a',
    '\u00E2': 'a',
    '\u00E3': 'a',
    '\u00E9': 'e',
    '\u00E8': 'e',
    '\u00EB': 'e',
    '\u00EA': 'e',
    '\u00ED': 'i',
    '\u00EC': 'i',
    '\u00EF': 'i',
    '\u00EE': 'i',
    '\u00F3': 'o',
    '\u00F2': 'o',
    '\u00F6': 'o',
    '\u00F4': 'o',
    '\u00F5': 'o',
    '\u00FA': 'u',
    '\u00F9': 'u',
    '\u00FC': 'u',
    '\u00FB': 'u',
    '\u00F1': 'n',
  };
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
