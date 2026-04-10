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
        .trim();
    if (noPunct.startsWith(animeNormalized)) {
      final suffix = noPunct.substring(animeNormalized.length).trim();
      if (suffix == episodeInt.toString() ||
          suffix == episodeInt.toString().padLeft(2, '0')) {
        return true;
      }
    }
  }

  return false;
}
