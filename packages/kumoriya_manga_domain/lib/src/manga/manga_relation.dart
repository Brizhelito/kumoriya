import 'package:kumoriya_core/kumoriya_core.dart';

import 'manga.dart';

/// Type of relation between two manga entries (or between an anime and a
/// manga, surfaced from the manga side).
enum MangaRelationType {
  prequel,
  sequel,
  sideStory,
  adaptation,
  spinOff,
  other,
}

/// A relation edge starting from a manga, pointing to another manga.
/// Anime↔manga adaptations cross the universe boundary and are surfaced
/// at the application layer using `kumoriya_matching` rather than here.
final class MangaRelation {
  const MangaRelation({required this.type, required Manga manga})
    : _manga = manga,
      _target = null;

  const MangaRelation.crossMedia({
    required this.type,
    required RelatedMedia target,
  }) : _manga = null,
       _target = target;

  final MangaRelationType type;
  final RelatedMedia? _target;
  final Manga? _manga;

  RelatedMedia get target {
    final explicit = _target;
    if (explicit != null) return explicit;
    final manga = this.manga;
    return RelatedMedia(
      kind: MediaKind.manga,
      anilistId: manga.anilistId,
      titleRomaji: manga.title.romaji,
      titleEnglish: manga.title.english,
      titleNative: manga.title.native,
      coverImageUrl: manga.coverImageUrl,
      bannerImageUrl: manga.bannerImageUrl,
      formatLabel: manga.format.name,
    );
  }

  MediaKind get targetKind => target.kind;

  Manga get manga {
    final value = _manga;
    if (value == null) {
      throw StateError('Manga relation target is not a manga.');
    }
    return value;
  }
}
