import 'package:kumoriya_domain/kumoriya_domain.dart';

final class AnilistAnimeMapper {
  const AnilistAnimeMapper._();

  static Anime mapAnime(Map<String, dynamic> media) {
    final id = media['id'];
    if (id is! int) {
      throw const FormatException('Missing or invalid media id.');
    }

    final title = _mapTitle(media['title'], media['synonyms']);

    return Anime(
      anilistId: id,
      title: title,
      format: _mapFormat(media['format'] as String?),
      releaseYear: media['seasonYear'] as int?,
      coverImageUrl: _extractCoverImage(media['coverImage']),
      totalEpisodes: media['episodes'] as int?,
      averageScore: media['averageScore'] as int?,
      status: _mapStatus(media['status'] as String?),
    );
  }

  static AnimeDetail mapDetail(Map<String, dynamic> media) {
    final anime = mapAnime(media);
    return AnimeDetail(
      anime: anime,
      synopsis: _cleanSynopsis(media['description'] as String?),
      episodes: mapEpisodes(media),
      genres: _stringList(media['genres']),
      bannerImageUrl: media['bannerImage'] as String?,
      relations: _mapRelations(media['relations']),
    );
  }

  static List<AnimeEpisode> mapEpisodes(Map<String, dynamic> media) {
    final totalEpisodes = media['episodes'] as int?;
    final scheduleNodes = _extractSchedule(media['airingSchedule']);
    final nextAiringEpisode = _extractNextEpisode(media['nextAiringEpisode']);
    final status = _mapStatus(media['status'] as String?);

    if (totalEpisodes != null && totalEpisodes > 0) {
      return List<AnimeEpisode>.generate(totalEpisodes, (index) {
        final episodeNumber = index + 1;
        final scheduleEntry = scheduleNodes[episodeNumber.toDouble()];

        return AnimeEpisode(
          number: episodeNumber.toDouble(),
          title: 'Episode $episodeNumber',
          airDate: scheduleEntry,
          isAired: _isEpisodeAired(
            episodeNumber,
            status,
            nextAiringEpisode: nextAiringEpisode,
          ),
        );
      });
    }

    if (scheduleNodes.isEmpty) {
      return const <AnimeEpisode>[];
    }

    final sorted = scheduleNodes.keys.toList()..sort((a, b) => a.compareTo(b));

    return sorted
        .map(
          (episodeNumber) => AnimeEpisode(
            number: episodeNumber,
            title: 'Episode ${episodeNumber.toInt()}',
            airDate: scheduleNodes[episodeNumber],
            isAired: false,
          ),
        )
        .toList(growable: false);
  }

  static AnimeTitle _mapTitle(dynamic value, dynamic synonymsRaw) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid title payload.');
    }

    final romaji = value['romaji'];
    final english = value['english'];
    final native = value['native'];

    final canonical = (romaji is String && romaji.trim().isNotEmpty)
        ? romaji
        : (english is String && english.trim().isNotEmpty)
        ? english
        : (native is String && native.trim().isNotEmpty)
        ? native
        : null;

    if (canonical == null) {
      throw const FormatException(
        'AniList title is empty in all title fields.',
      );
    }

    return AnimeTitle(
      romaji: canonical,
      english: english is String && english.isNotEmpty ? english : null,
      native: native is String && native.isNotEmpty ? native : null,
      synonyms: _stringList(synonymsRaw),
    );
  }

  static AnimeFormat _mapFormat(String? rawFormat) {
    switch (rawFormat) {
      case 'TV':
        return AnimeFormat.tv;
      case 'MOVIE':
        return AnimeFormat.movie;
      case 'OVA':
        return AnimeFormat.ova;
      case 'ONA':
        return AnimeFormat.ona;
      case 'SPECIAL':
        return AnimeFormat.special;
      default:
        return AnimeFormat.unknown;
    }
  }

  static AnimeStatus _mapStatus(String? rawStatus) {
    switch (rawStatus) {
      case 'FINISHED':
        return AnimeStatus.finished;
      case 'RELEASING':
        return AnimeStatus.releasing;
      case 'NOT_YET_RELEASED':
        return AnimeStatus.notYetReleased;
      case 'CANCELLED':
        return AnimeStatus.cancelled;
      case 'HIATUS':
        return AnimeStatus.hiatus;
      default:
        return AnimeStatus.unknown;
    }
  }

  static String? _extractCoverImage(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final large = value['large'];
    final medium = value['medium'];

    if (large is String && large.isNotEmpty) {
      return large;
    }

    if (medium is String && medium.isNotEmpty) {
      return medium;
    }

    return null;
  }

  static String? _cleanSynopsis(String? synopsis) {
    if (synopsis == null || synopsis.trim().isEmpty) {
      return null;
    }

    return synopsis
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<i>', '')
        .replaceAll('</i>', '')
        .replaceAll('<b>', '')
        .replaceAll('</b>', '');
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value.whereType<String>().toList(growable: false);
  }

  static List<AnimeRelation> _mapRelations(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const <AnimeRelation>[];
    }

    final edges = value['edges'];
    final nodes = value['nodes'];
    if (edges is! List || nodes is! List) {
      return const <AnimeRelation>[];
    }

    final relations = <AnimeRelation>[];
    final length = edges.length < nodes.length ? edges.length : nodes.length;

    for (var i = 0; i < length; i++) {
      final edge = edges[i];
      final node = nodes[i];
      if (edge is! Map<String, dynamic> || node is! Map<String, dynamic>) {
        continue;
      }

      try {
        final anime = mapAnime(node);
        relations.add(
          AnimeRelation(
            type: _mapRelationType(edge['relationType'] as String?),
            anime: anime,
          ),
        );
      } on FormatException {
        continue;
      }
    }

    return relations;
  }

  static AnimeRelationType _mapRelationType(String? rawType) {
    switch (rawType) {
      case 'PREQUEL':
        return AnimeRelationType.prequel;
      case 'SEQUEL':
        return AnimeRelationType.sequel;
      case 'SIDE_STORY':
        return AnimeRelationType.sideStory;
      case 'ADAPTATION':
        return AnimeRelationType.adaptation;
      case 'SPIN_OFF':
        return AnimeRelationType.spinOff;
      default:
        return AnimeRelationType.other;
    }
  }

  static Map<double, DateTime?> _extractSchedule(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const <double, DateTime?>{};
    }

    final nodes = value['nodes'];
    if (nodes is! List) {
      return const <double, DateTime?>{};
    }

    final output = <double, DateTime?>{};
    for (final node in nodes) {
      if (node is! Map<String, dynamic>) {
        continue;
      }

      final episode = node['episode'];
      if (episode is! int || episode <= 0) {
        continue;
      }

      final airingAt = node['airingAt'];
      output[episode.toDouble()] = airingAt is int
          ? DateTime.fromMillisecondsSinceEpoch(airingAt * 1000, isUtc: true)
          : null;
    }

    return output;
  }

  static int? _extractNextEpisode(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final episode = value['episode'];
    return episode is int && episode > 0 ? episode : null;
  }

  static bool _isEpisodeAired(
    int episodeNumber,
    AnimeStatus status, {
    required int? nextAiringEpisode,
  }) {
    if (status == AnimeStatus.finished) {
      return true;
    }

    if (nextAiringEpisode != null) {
      return episodeNumber < nextAiringEpisode;
    }

    return false;
  }
}
