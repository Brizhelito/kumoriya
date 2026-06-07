import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

String resolveEpisodeDisplayTitle({
  required double episodeNumber,
  required String fallbackTitle,
  String? animeTitle,
  AnimeEpisode? metadata,
  Map<String, SourceEpisode> sourceEpisodes = const <String, SourceEpisode>{},
}) {
  final metadataTitle = metadata?.title.trim() ?? '';
  if (_hasSpecificEpisodeTitle(
    metadataTitle,
    episodeNumber,
    animeTitle: animeTitle,
  )) {
    return metadataTitle;
  }

  for (final sourceEpisode in sourceEpisodes.values) {
    final sourceTitle = sourceEpisode.title.trim();
    if (_hasSpecificEpisodeTitle(
      sourceTitle,
      episodeNumber,
      animeTitle: animeTitle,
    )) {
      return sourceTitle;
    }
  }

  if (metadataTitle.isNotEmpty) {
    return metadataTitle;
  }

  return fallbackTitle;
}

bool _hasSpecificEpisodeTitle(
  String title,
  double episodeNumber, {
  String? animeTitle,
}) {
  if (title.isEmpty) {
    return false;
  }

  return !_isGenericEpisodeTitle(title, episodeNumber, animeTitle: animeTitle);
}

bool _isGenericEpisodeTitle(
  String title,
  double episodeNumber, {
  String? animeTitle,
}) {
  final normalized = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[:\-_.#]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  final withoutBrackets = normalized
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final episodeInt = episodeNumber.toInt();
  final exactPatterns = <RegExp>[
    RegExp(
      '^(episode|ep|episodio|capitulo|capítulo|chapter|chap|cap) $episodeInt\$',
    ),
    RegExp(
      '^(episode|ep|episodio|capitulo|capítulo|chapter|chap|cap)0*$episodeInt\$',
    ),
  ];

  if (exactPatterns.any((pattern) => pattern.hasMatch(withoutBrackets))) {
    return true;
  }

  // Common placeholder style: "{Anime Title} Episode N".
  final suffixPattern = RegExp(
    '(episode|ep|episodio|capitulo|capítulo|chapter|chap|cap)s*0*$episodeInt\$',
  );
  if (suffixPattern.hasMatch(withoutBrackets)) {
    return true;
  }

  final animeNormalized = animeTitle
      ?.trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[:\-_.#]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (animeNormalized != null && animeNormalized.isNotEmpty) {
    final noPunct = withoutBrackets
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final animeVariant in _animeTitleGenericVariants(animeNormalized)) {
      if (!noPunct.startsWith(animeVariant)) {
        continue;
      }
      final suffix = noPunct.substring(animeVariant.length).trim();
      if (suffix == episodeInt.toString() ||
          suffix == episodeInt.toString().padLeft(2, '0') ||
          RegExp(
            r'^(?:episode|ep|episodio|capitulo|capítulo|chapter|chap|cap)\s*0*' +
                episodeInt.toString() +
                r'$',
          ).hasMatch(suffix)) {
        return true;
      }
    }
  }

  return false;
}

Iterable<String> _animeTitleGenericVariants(String normalizedAnimeTitle) sync* {
  final variants = <String>{normalizedAnimeTitle};

  final seasonNumber = _extractSeasonNumber(normalizedAnimeTitle);
  if (seasonNumber != null) {
    final withoutSeason = normalizedAnimeTitle
        .replaceAll(RegExp(r'\s*\b\d+(?:st|nd|rd|th)?\s+season\b\s*$'), '')
        .replaceAll(RegExp(r'\s*\bseason\s+\d+\b\s*$'), '')
        .trim();
    if (withoutSeason.isNotEmpty) {
      variants.add(withoutSeason);
      variants.add('$withoutSeason $seasonNumber');
      variants.add('$withoutSeason season $seasonNumber');
      variants.add('$withoutSeason ${_ordinal(seasonNumber)} season');
    }
  }

  for (final variant in variants) {
    yield variant;
  }
}

int? _extractSeasonNumber(String normalizedAnimeTitle) {
  final ordinal = RegExp(
    r'\b(\d+)(?:st|nd|rd|th)\s+season\b',
  ).firstMatch(normalizedAnimeTitle);
  if (ordinal != null) {
    return int.tryParse(ordinal.group(1) ?? '');
  }

  final season = RegExp(r'\bseason\s+(\d+)\b').firstMatch(normalizedAnimeTitle);
  if (season != null) {
    return int.tryParse(season.group(1) ?? '');
  }

  return null;
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
