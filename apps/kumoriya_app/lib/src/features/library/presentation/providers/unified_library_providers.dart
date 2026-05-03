import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart' as manga;
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../shared/storage_providers.dart';
import '../../../manga_catalog/presentation/providers/manga_catalog_providers.dart';
import '../../domain/unified_library_entry.dart';

final class MangaLibraryHistoryEntry {
  const MangaLibraryHistoryEntry({required this.history, required this.entry});

  final MangaReadHistory history;
  final UnifiedLibraryEntry entry;
}

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

final unifiedMangaHistoryProvider =
    FutureProvider.autoDispose<List<MangaLibraryHistoryEntry>>((ref) async {
      final historyResult = await ref
          .watch(mangaProgressStoreProvider)
          .getRecentHistory(limit: 200);
      final history = historyResult.fold(
        onSuccess: (items) => items,
        onFailure: (_) => const <MangaReadHistory>[],
      );
      if (history.isEmpty) return const <MangaLibraryHistoryEntry>[];
      final ids = history.map((h) => h.mangaAnilistId).toList(growable: false);
      final mangas = await ref.watch(mangaBatchByIdsProvider(ids).future);
      final byId = <int, manga.Manga>{for (final m in mangas) m.anilistId: m};
      return [
        for (final item in history)
          if (byId[item.mangaAnilistId] != null)
            MangaLibraryHistoryEntry(
              history: item,
              entry: _mangaToEntry(byId[item.mangaAnilistId]!),
            ),
      ];
    });

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
