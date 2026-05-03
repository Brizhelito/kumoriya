import 'package:kumoriya_core/kumoriya_core.dart';

import 'anime.dart';

enum AnimeRelationType {
  prequel,
  sequel,
  sideStory,
  adaptation,
  spinOff,
  other,
}

final class AnimeRelation {
  const AnimeRelation({required this.type, required Anime anime})
    : _anime = anime,
      _target = null;

  const AnimeRelation.crossMedia({
    required this.type,
    required RelatedMedia target,
  }) : _anime = null,
       _target = target;

  final AnimeRelationType type;
  final RelatedMedia? _target;
  final Anime? _anime;

  RelatedMedia get target {
    final explicit = _target;
    if (explicit != null) return explicit;
    final anime = this.anime;
    return RelatedMedia(
      kind: MediaKind.anime,
      anilistId: anime.anilistId,
      titleRomaji: anime.title.romaji,
      titleEnglish: anime.title.english,
      titleNative: anime.title.native,
      coverImageUrl: anime.coverImageUrl,
      bannerImageUrl: anime.bannerImageUrl,
      formatLabel: anime.format.name,
    );
  }

  MediaKind get targetKind => target.kind;

  Anime get anime {
    final value = _anime;
    if (value == null) {
      throw StateError('Anime relation target is not an anime.');
    }
    return value;
  }
}
