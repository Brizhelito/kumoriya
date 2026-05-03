import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/storage_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../manga_catalog/presentation/pages/manga_detail_page.dart';
import '../../domain/unified_library_entry.dart';
import '../providers/unified_library_providers.dart';

/// Manga library view for favorites and chapter subscriptions.
class UnifiedLibraryPage extends ConsumerStatefulWidget {
  const UnifiedLibraryPage({super.key});

  @override
  ConsumerState<UnifiedLibraryPage> createState() => _UnifiedLibraryPageState();
}

class _UnifiedLibraryPageState extends ConsumerState<UnifiedLibraryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  l10n.libraryTitle,
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
                  Tab(text: l10n.myListHistory),
                  Tab(text: l10n.myListFavorites),
                  Tab(text: l10n.myListSubscribed),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    const _HistoryTab(),
                    _UnifiedTab(kind: _UnifiedTabKind.favorites),
                    _UnifiedTab(kind: _UnifiedTabKind.subscribed),
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

enum _UnifiedTabKind { favorites, subscribed }

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(unifiedMangaHistoryProvider);
    final entries = historyAsync.value ?? const <MangaLibraryHistoryEntry>[];

    if (historyAsync.isLoading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return _EmptyView(message: context.l10n.myListHistoryEmpty);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: entries.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 8) : const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmClearAll(context, ref),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(context.l10n.historyClearAllAction),
              style: TextButton.styleFrom(
                foregroundColor: KumoriyaColors.statusDanger,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }
        final item = entries[index - 1];
        return Dismissible(
          key: ValueKey('manga_history_${item.history.mangaAnilistId}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: KumoriyaColors.statusDanger,
              borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => _deleteEntry(ref, item.history.mangaAnilistId),
          child: _HistoryRow(
            item: item,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MangaDetailPage(anilistId: item.history.mangaAnilistId),
              ),
            ),
            onDelete: () => _deleteEntry(ref, item.history.mangaAnilistId),
          ),
        );
      },
    );
  }

  void _deleteEntry(WidgetRef ref, int mangaAnilistId) {
    ref.read(mangaProgressStoreProvider).deleteHistoryEntry(mangaAnilistId);
    ref.invalidate(unifiedMangaHistoryProvider);
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.historyClearAllTitle),
        content: Text(context.l10n.historyClearAllMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancelAction),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(mangaProgressStoreProvider).clearAllHistory();
              ref.invalidate(unifiedMangaHistoryProvider);
            },
            style: TextButton.styleFrom(
              foregroundColor: KumoriyaColors.statusDanger,
            ),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
  }
}

class _UnifiedTab extends ConsumerWidget {
  const _UnifiedTab({required this.kind});

  final _UnifiedTabKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaAsync = switch (kind) {
      _UnifiedTabKind.favorites => ref.watch(unifiedMangaFavoritesProvider),
      _UnifiedTabKind.subscribed => ref.watch(unifiedMangaSubscribedProvider),
    };

    final entries = mangaAsync.value ?? const <UnifiedLibraryEntry>[];

    if (mangaAsync.isLoading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return _EmptyView(
        message: switch (kind) {
          _UnifiedTabKind.favorites => context.l10n.mangaLibraryFavoritesEmpty,
          _UnifiedTabKind.subscribed =>
            context.l10n.mangaLibrarySubscribedEmpty,
        },
      );
    }
    return _EntryGrid(entries: entries);
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});
  final List<UnifiedLibraryEntry> entries;

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
      itemCount: entries.length,
      itemBuilder: (_, i) => _EntryCard(entry: entries[i]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final MangaLibraryHistoryEntry item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final chapterLabel = item.history.lastChapterNumber % 1 == 0
        ? item.history.lastChapterNumber.toInt().toString()
        : item.history.lastChapterNumber.toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      ),
      tileColor: KumoriyaColors.surface,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 60,
          child: item.entry.coverImageUrl != null
              ? KumoriyaCachedImage(
                  url: item.entry.coverImageUrl!,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  fit: BoxFit.cover,
                )
              : ColoredBox(color: KumoriyaColors.surfaceDim),
        ),
      ),
      title: Text(
        item.entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: KumoriyaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Capítulo $chapterLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: KumoriyaColors.textMuted, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded),
        color: KumoriyaColors.textMuted,
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final UnifiedLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: entry.coverImageUrl != null
                      ? KumoriyaCachedImage(
                          url: entry.coverImageUrl!,
                          bucket: KumoriyaImageCacheBucket.artwork,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(color: KumoriyaColors.surfaceDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.title,
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
  }

  void _open(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => MangaDetailPage(anilistId: entry.anilistId),
    );
    Navigator.of(context).push(route);
  }
}

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
