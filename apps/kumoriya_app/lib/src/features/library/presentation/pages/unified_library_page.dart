import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../anime_catalog/presentation/pages/anime_detail_page.dart';
import '../../../manga_catalog/presentation/pages/manga_detail_page.dart';
import '../../domain/unified_library_entry.dart';
import '../providers/unified_library_providers.dart';

/// Unified library view: shows favorites and subscriptions from both
/// universes side by side, with a filter chip (`All / Anime / Manga`)
/// that defaults to whichever universe routed into the page.
///
/// This is the **manga universe's** library tab. The anime universe
/// keeps its dedicated `LibraryPage` for now (it has additional
/// surfaces — list/grid toggle, history with delete, clear-history
/// action — that the unified view does not replicate). Aligning both
/// universes on this page is a follow-up slice.
class UnifiedLibraryPage extends ConsumerStatefulWidget {
  const UnifiedLibraryPage({super.key, required this.initialFilter});

  /// `null` = "All", otherwise restrict to a single universe.
  final MediaKind? initialFilter;

  @override
  ConsumerState<UnifiedLibraryPage> createState() => _UnifiedLibraryPageState();
}

class _UnifiedLibraryPageState extends ConsumerState<UnifiedLibraryPage> {
  late MediaKind? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
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
              _FilterChips(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
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
                  Tab(text: l10n.myListFavorites),
                  Tab(text: l10n.myListSubscribed),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _UnifiedTab(
                      filter: _filter,
                      kind: _UnifiedTabKind.favorites,
                    ),
                    _UnifiedTab(
                      filter: _filter,
                      kind: _UnifiedTabKind.subscribed,
                    ),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});
  final MediaKind? value;
  final ValueChanged<MediaKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 6,
        children: <Widget>[
          _Chip(
            label: l10n.libraryFilterAll,
            selected: value == null,
            onTap: () => onChanged(null),
          ),
          _Chip(
            label: l10n.universeAnime,
            selected: value == MediaKind.anime,
            onTap: () => onChanged(MediaKind.anime),
          ),
          _Chip(
            label: l10n.universeManga,
            selected: value == MediaKind.manga,
            onTap: () => onChanged(MediaKind.manga),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: KumoriyaColors.primary.withValues(alpha: 0.20),
      backgroundColor: KumoriyaColors.surfaceDim,
      labelStyle: TextStyle(
        color: selected ? KumoriyaColors.primary : KumoriyaColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? KumoriyaColors.primary : KumoriyaColors.borderSubtle,
      ),
    );
  }
}

enum _UnifiedTabKind { favorites, subscribed }

class _UnifiedTab extends ConsumerWidget {
  const _UnifiedTab({required this.filter, required this.kind});

  final MediaKind? filter;
  final _UnifiedTabKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animeAsync = switch (kind) {
      _UnifiedTabKind.favorites => ref.watch(unifiedAnimeFavoritesProvider),
      _UnifiedTabKind.subscribed => ref.watch(unifiedAnimeSubscribedProvider),
    };
    final mangaAsync = switch (kind) {
      _UnifiedTabKind.favorites => ref.watch(unifiedMangaFavoritesProvider),
      _UnifiedTabKind.subscribed => ref.watch(unifiedMangaSubscribedProvider),
    };

    final animeEntries = filter == MediaKind.manga
        ? const <UnifiedLibraryEntry>[]
        : (animeAsync.value ?? const <UnifiedLibraryEntry>[]);
    final mangaEntries = filter == MediaKind.anime
        ? const <UnifiedLibraryEntry>[]
        : (mangaAsync.value ?? const <UnifiedLibraryEntry>[]);

    final loading =
        (filter != MediaKind.manga && animeAsync.isLoading) ||
        (filter != MediaKind.anime && mangaAsync.isLoading);
    final entries = <UnifiedLibraryEntry>[...animeEntries, ...mangaEntries];

    if (loading && entries.isEmpty) {
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
                Positioned(
                  top: 6,
                  left: 6,
                  child: _UniverseBadge(kind: entry.mediaKind),
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
    final route = switch (entry.mediaKind) {
      MediaKind.anime => MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: entry.anilistId),
      ),
      MediaKind.manga => MaterialPageRoute<void>(
        builder: (_) => MangaDetailPage(anilistId: entry.anilistId),
      ),
    };
    Navigator.of(context).push(route);
  }
}

/// Tiny pill in the cover top-left so the user can tell at a glance
/// which universe a card belongs to in the "All" view.
class _UniverseBadge extends StatelessWidget {
  const _UniverseBadge({required this.kind});
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      MediaKind.anime => context.l10n.universeAnime,
      MediaKind.manga => context.l10n.universeManga,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
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
