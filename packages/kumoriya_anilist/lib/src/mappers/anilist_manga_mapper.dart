import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Maps raw AniList GraphQL `Media` payloads (where `type == 'MANGA'`)
/// into the manga domain entities.
///
/// Mirrors the shape of `AnilistAnimeMapper`: same field discipline
/// (defensive parsing, no throws on missing optional fields, only on
/// missing canonical fields like id/title), same synopsis cleanup, same
/// relation mapping pattern.
final class AnilistMangaMapper {
  const AnilistMangaMapper._();

  static Manga mapManga(Map<String, dynamic> media) {
    final id = media['id'];
    if (id is! int) {
      throw const FormatException('Missing or invalid media id.');
    }

    final title = _mapTitle(media['title'], media['synonyms']);

    return Manga(
      anilistId: id,
      title: title,
      format: _mapFormat(media['format'] as String?),
      releaseYear: _extractStartYear(media['startDate']),
      coverImageUrl: _extractCoverImage(media['coverImage']),
      bannerImageUrl: media['bannerImage'] as String?,
      totalChapters: media['chapters'] as int?,
      totalVolumes: media['volumes'] as int?,
      averageScore: media['averageScore'] as int?,
      popularity: media['popularity'] as int?,
      synopsis: _cleanSynopsis(media['description'] as String?),
      genres: _stringList(media['genres']),
      status: _mapStatus(media['status'] as String?),
      countryOfOrigin: _mapCountry(media['countryOfOrigin']),
    );
  }

  static MangaDetail mapDetail(Map<String, dynamic> media) {
    final manga = mapManga(media);
    return MangaDetail(
      manga: manga,
      relations: _mapRelations(media['relations']),
    );
  }

  static MangaTitle _mapTitle(dynamic value, dynamic synonymsRaw) {
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

    return MangaTitle(
      romaji: canonical,
      english: english is String && english.isNotEmpty ? english : null,
      native: native is String && native.isNotEmpty ? native : null,
      synonyms: _stringList(synonymsRaw),
    );
  }

  static MangaFormat _mapFormat(String? rawFormat) {
    switch (rawFormat) {
      case 'MANGA':
        return MangaFormat.manga;
      case 'MANHWA':
        return MangaFormat.manhwa;
      case 'MANHUA':
        return MangaFormat.manhua;
      case 'ONE_SHOT':
        return MangaFormat.oneShot;
      case 'DOUJINSHI':
        return MangaFormat.doujinshi;
      // 'NOVEL' is intentionally absent — light novels are out of scope
      // for the manga phase and surface as `unknown` so they cannot be
      // confused with manga in the UI.
      default:
        return MangaFormat.unknown;
    }
  }

  static MangaStatus _mapStatus(String? rawStatus) {
    switch (rawStatus) {
      case 'FINISHED':
        return MangaStatus.finished;
      case 'RELEASING':
        return MangaStatus.releasing;
      case 'NOT_YET_RELEASED':
        return MangaStatus.notYetReleased;
      case 'CANCELLED':
        return MangaStatus.cancelled;
      case 'HIATUS':
        return MangaStatus.hiatus;
      default:
        return MangaStatus.unknown;
    }
  }

  static MangaCountryOfOrigin? _mapCountry(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return MangaCountryOfOrigin(raw);
  }

  static int? _extractStartYear(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    final year = value['year'];
    return year is int && year > 0 ? year : null;
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

  /// Filters relation nodes to MANGA-only. Cross-universe (anime
  /// adaptations) are surfaced separately via `kumoriya_matching` and
  /// AniList relations at the application layer; the manga domain
  /// `MangaRelation` represents manga-to-manga edges only.
  static List<MangaRelation> _mapRelations(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const <MangaRelation>[];
    }

    final edges = value['edges'];
    final nodes = value['nodes'];
    if (edges is! List || nodes is! List) {
      return const <MangaRelation>[];
    }

    final relations = <MangaRelation>[];
    final length = edges.length < nodes.length ? edges.length : nodes.length;

    for (var i = 0; i < length; i++) {
      final edge = edges[i];
      final node = nodes[i];
      if (edge is! Map<String, dynamic> || node is! Map<String, dynamic>) {
        continue;
      }

      try {
        final mediaType = node['type'];
        if (mediaType == 'ANIME') {
          relations.add(
            MangaRelation.crossMedia(
              type: _mapRelationType(edge['relationType'] as String?),
              target: _mapRelatedMedia(node, MediaKind.anime),
            ),
          );
          continue;
        }
        if (mediaType is String && mediaType != 'MANGA') continue;
        final manga = mapManga(node);
        relations.add(
          MangaRelation(
            type: _mapRelationType(edge['relationType'] as String?),
            manga: manga,
          ),
        );
      } on FormatException {
        continue;
      }
    }

    return relations;
  }

  static RelatedMedia _mapRelatedMedia(
    Map<String, dynamic> media,
    MediaKind kind,
  ) {
    final id = media['id'];
    if (id is! int) {
      throw const FormatException('Missing or invalid media id.');
    }
    final title = _mapTitle(media['title'], media['synonyms']);
    return RelatedMedia(
      kind: kind,
      anilistId: id,
      titleRomaji: title.romaji,
      titleEnglish: title.english,
      titleNative: title.native,
      coverImageUrl: _extractCoverImage(media['coverImage']),
      bannerImageUrl: media['bannerImage'] as String?,
      formatLabel: media['format'] as String?,
    );
  }

  static MangaRelationType _mapRelationType(String? rawType) {
    switch (rawType) {
      case 'PREQUEL':
        return MangaRelationType.prequel;
      case 'SEQUEL':
        return MangaRelationType.sequel;
      case 'SIDE_STORY':
        return MangaRelationType.sideStory;
      case 'ADAPTATION':
        return MangaRelationType.adaptation;
      case 'SPIN_OFF':
        return MangaRelationType.spinOff;
      default:
        return MangaRelationType.other;
    }
  }
}
