import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/storage_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../providers/manga_catalog_providers.dart';
import 'manga_detail_page.dart';

/// Pick the best human-readable title from a `MangaTitle`. Preference
/// order matches the rest of the app: english → romaji → native.
String _preferredTitle(MangaTitle t) {
  final en = t.english;
  if (en != null && en.isNotEmpty) return en;
  if (t.romaji.isNotEmpty) return t.romaji;
  return t.native ?? '';
}

/// Display title with a sane fallback when the AniList batch hasn't
/// resolved yet (we still want history rows to show *something*).
String _displayTitle(Manga? m, int anilistId) {
  if (m == null) return '#$anilistId';
  return _preferredTitle(m.title);
}

/// Manga universe Library tab. Three sub-tabs: History (most recently
/// read), Favorites (heart-toggled in the detail page), Subscribed
/// (notify-toggled in the detail page). Mirrors the anime
/// `LibraryPage` shape so muscle memory carries across universes,
/// without unifying the data model — the unified library is its own
/// slice (10B in the manga plan).
class MangaLibraryPage extends ConsumerWidget {
  const MangaLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.l10n.mangaLibraryTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: KumoriyaColors.primary,
                labelColor: KumoriyaColors.primary,
                unselectedLabelColor: KumoriyaColors.navInactive,
                dividerColor: KumoriyaColors.borderSubtle,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: <Tab>[
                  Tab(text: context.l10n.myListHistory),
                  Tab(text: context.l10n.myListFavorites),
                  Tab(text: context.l10n.myListSubscribed),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _HistoryTab(),
                    _FavoritesTab(),
                    _SubscribedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(mangaRecentHistoryProvider);
    return asyncHistory.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(mangaRecentHistoryProvider),
      ),
      data: (result) => result.fold(
        onFailure: (err) => _ErrorView(
          message: '${err.code}: ${err.message}',
          onRetry: () => ref.invalidate(mangaRecentHistoryProvider),
        ),
        onSuccess: (history) {
          if (history.isEmpty) {
            return _EmptyView(message: context.l10n.mangaLibraryHistoryEmpty);
          }
          // Hydrate the AniList ids so we can show covers + titles.
          final ids = history
              .map((h) => h.mangaAnilistId)
              .toList(growable: false);
          final asyncBatch = ref.watch(mangaBatchByIdsProvider(ids));
          return asyncBatch.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(mangaBatchByIdsProvider(ids)),
            ),
            data: (mangas) {
              final byId = <int, Manga>{for (final m in mangas) m.anilistId: m};
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HistoryRow(
                  history: history[i],
                  manga: byId[history[i].mangaAnilistId],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.history, required this.manga});

  final MangaReadHistory history;
  final Manga? manga;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = history.lastChapterNumber;
    final formatted = n == n.truncateToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(1);
    final title = _displayTitle(manga, history.mangaAnilistId);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MangaDetailPage(anilistId: history.mangaAnilistId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 64,
                child: (manga?.coverImageUrl != null)
                    ? KumoriyaCachedImage(
                        url: manga!.coverImageUrl!,
                        bucket: KumoriyaImageCacheBucket.artwork,
                        fit: BoxFit.cover,
                      )
                    : ColoredBox(color: KumoriyaColors.surfaceDim),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.mangaLibraryHistoryChapterLine(formatted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites + Subscribed tabs share the same id-set → grid layout.
// ---------------------------------------------------------------------------

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _IdSetTab(
      idsAsync: ref.watch(favoriteMangaIdsProvider),
      emptyMessage: context.l10n.mangaLibraryFavoritesEmpty,
      onRetry: () => ref.invalidate(favoriteMangaIdsProvider),
    );
  }
}

class _SubscribedTab extends ConsumerWidget {
  const _SubscribedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _IdSetTab(
      idsAsync: ref.watch(subscribedMangaIdsProvider),
      emptyMessage: context.l10n.mangaLibrarySubscribedEmpty,
      onRetry: () => ref.invalidate(subscribedMangaIdsProvider),
    );
  }
}

class _IdSetTab extends ConsumerWidget {
  const _IdSetTab({
    required this.idsAsync,
    required this.emptyMessage,
    required this.onRetry,
  });

  final AsyncValue<Result<Set<int>, KumoriyaError>> idsAsync;
  final String emptyMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return idsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString(), onRetry: onRetry),
      data: (result) => result.fold(
        onFailure: (err) => _ErrorView(
          message: '${err.code}: ${err.message}',
          onRetry: onRetry,
        ),
        onSuccess: (ids) {
          if (ids.isEmpty) return _EmptyView(message: emptyMessage);
          final list = ids.toList(growable: false);
          final asyncBatch = ref.watch(mangaBatchByIdsProvider(list));
          return asyncBatch.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(mangaBatchByIdsProvider(list)),
            ),
            data: (mangas) => _MangaGrid(mangas: mangas),
          );
        },
      ),
    );
  }
}

class _MangaGrid extends StatelessWidget {
  const _MangaGrid({required this.mangas});

  final List<Manga> mangas;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: mangas.length,
      itemBuilder: (_, i) {
        final m = mangas[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MangaDetailPage(anilistId: m.anilistId),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: m.coverImageUrl != null
                      ? KumoriyaCachedImage(
                          url: m.coverImageUrl!,
                          bucket: KumoriyaImageCacheBucket.artwork,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(color: KumoriyaColors.surfaceDim),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _preferredTitle(m.title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KumoriyaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error views
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KumoriyaColors.textMuted),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: KumoriyaColors.statusDanger,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.mangaHomeRetry),
            ),
          ],
        ),
      ),
    );
  }
}
