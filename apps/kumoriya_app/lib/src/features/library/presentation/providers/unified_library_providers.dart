import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart' as anime;
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart' as manga;

import '../../../../shared/storage_providers.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../manga_catalog/presentation/providers/manga_catalog_providers.dart';
import '../../domain/unified_library_entry.dart';

/// Resolves the user's anime favorites into hydrated
/// `UnifiedLibraryEntry` rows. Falls back to the empty list when the
/// underlying id-set fetch fails — a partial library is preferable to
/// a hard error in the unified view (the per-universe pages still
/// surface the error).
final unifiedAnimeFavoritesProvider =
    FutureProvider.autoDispose<List<UnifiedLibraryEntry>>((ref) async {
      final idsResult = await ref.watch(favoriteAnimeIdsProvider.future);
      final ids = idsResult.fold(
        onSuccess: (s) => s.toList(growable: false),
        onFailure: (_) => const <int>[],
      );
      if (ids.isEmpty) return const <UnifiedLibraryEntry>[];
      final repo = ref.watch(animeCatalogRepositoryProvider);
      final result = await repo.fetchBatchAnimeByIds(ids);
      return result.fold(
        onSuccess: (animes) =>
            animes.map(_animeToEntry).toList(growable: false),
        onFailure: (_) => const <UnifiedLibraryEntry>[],
      );
    });

/// Same shape as [unifiedAnimeFavoritesProvider] for the manga side.
final unifiedMangaFavoritesProvider =
    FutureProvider.autoDispose<List<UnifiedLibraryEntry>>((ref) async {
      final idsResult = await ref.watch(favoriteMangaIdsProvider.future);
      final ids = idsResult.fold(
        onSuccess: (s) => s.toList(growable: false),
        onFailure: (_) => const <int>[],
      );
      if (ids.isEmpty) return const <UnifiedLibraryEntry>[];
      final mangas = await ref.watch(mangaBatchByIdsProvider(ids).future);
      return mangas.map(_mangaToEntry).toList(growable: false);
    });

/// Anime + manga subscriptions, merged into a single hydrated list.
final unifiedAnimeSubscribedProvider =
    FutureProvider.autoDispose<List<UnifiedLibraryEntry>>((ref) async {
      final idsResult = await ref.watch(subscribedAnimeIdsProvider.future);
      final ids = idsResult.fold(
        onSuccess: (s) => s.toList(growable: false),
        onFailure: (_) => const <int>[],
      );
      if (ids.isEmpty) return const <UnifiedLibraryEntry>[];
      final repo = ref.watch(animeCatalogRepositoryProvider);
      final result = await repo.fetchBatchAnimeByIds(ids);
      return result.fold(
        onSuccess: (animes) =>
            animes.map(_animeToEntry).toList(growable: false),
        onFailure: (_) => const <UnifiedLibraryEntry>[],
      );
    });

final unifiedMangaSubscribedProvider =
    FutureProvider.autoDispose<List<UnifiedLibraryEntry>>((ref) async {
      final idsResult = await ref.watch(subscribedMangaIdsProvider.future);
      final ids = idsResult.fold(
        onSuccess: (s) => s.toList(growable: false),
        onFailure: (_) => const <int>[],
      );
      if (ids.isEmpty) return const <UnifiedLibraryEntry>[];
      final mangas = await ref.watch(mangaBatchByIdsProvider(ids).future);
      return mangas.map(_mangaToEntry).toList(growable: false);
    });

UnifiedLibraryEntry _animeToEntry(anime.Anime a) {
  final en = a.title.english;
  final title = (en != null && en.isNotEmpty)
      ? en
      : (a.title.romaji.isNotEmpty
            ? a.title.romaji
            : (a.title.native ?? '#${a.anilistId}'));
  return UnifiedLibraryEntry(
    mediaKind: MediaKind.anime,
    anilistId: a.anilistId,
    title: title,
    coverImageUrl: a.coverImageUrl,
  );
}

UnifiedLibraryEntry _mangaToEntry(manga.Manga m) {
  final en = m.title.english;
  final title = (en != null && en.isNotEmpty)
      ? en
      : (m.title.romaji.isNotEmpty
            ? m.title.romaji
            : (m.title.native ?? '#${m.anilistId}'));
  return UnifiedLibraryEntry(
    mediaKind: MediaKind.manga,
    anilistId: m.anilistId,
    title: title,
    coverImageUrl: m.coverImageUrl,
  );
}
