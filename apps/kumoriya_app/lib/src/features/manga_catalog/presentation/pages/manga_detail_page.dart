import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/storage_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/meta_chip.dart';
import '../../../../shared/widgets/translated_dynamic_text.dart';
import '../../../manga_downloads/presentation/widgets/chapter_download_button.dart';
import '../../../anime_catalog/presentation/pages/anime_detail_page.dart';
import '../../application/services/composite_manga_catalog_repository.dart';
import '../providers/manga_catalog_providers.dart';
import 'manga_reader_route.dart';

/// Detail screen for a single manga. Loads metadata via
/// [mangaDetailProvider] and the (lazy) chapter list via
/// [mangaChaptersProvider]. Tapping a chapter shows a "reader coming
/// soon" SnackBar — the reader lands in Slice 9.
class MangaDetailPage extends ConsumerWidget {
  const MangaDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mangaDetailProvider(anilistId));
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e.toString()),
        data: (detail) => _DetailContent(detail: detail),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final MangaDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manga = detail.manga;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: KumoriyaColors.background,
          expandedHeight: 280,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                KumoriyaCachedImage(
                  url: manga.bannerImageUrl ?? manga.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        KumoriyaColors.background,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  manga.title.romaji,
                  style: theme.textTheme.headlineMedium!.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (manga.title.native != null &&
                    manga.title.native!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      manga.title.native!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: KumoriyaColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _HeaderChips(manga: manga),
                const SizedBox(height: 16),
                _LibraryActionsRow(anilistId: manga.anilistId),
                const SizedBox(height: 16),
                _CollapsibleMangaSynopsis(
                  synopsis:
                      (detail.synopsis == null || detail.synopsis!.isEmpty)
                      ? l10n.mangaDetailNoSynopsis
                      : _stripHtml(detail.synopsis!),
                ),
                if (detail.genres.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    l10n.mangaDetailGenres,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final g in detail.genres) Chip(label: Text(g)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.mangaDetailChapters,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: KumoriyaColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _SourcePicker(anilistId: manga.anilistId),
                    const SizedBox(width: 6),
                    _ScanlatorPicker(anilistId: manga.anilistId),
                  ],
                ),
              ],
            ),
          ),
        ),
        _ChaptersSliver(anilistId: manga.anilistId),
        if (detail.relations.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: _MangaRelationsSection(relations: detail.relations),
            ),
          ),
      ],
    );
  }

  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

class _HeaderChips extends StatelessWidget {
  const _HeaderChips({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = <Widget>[
      _Chip(label: _formatLabel(manga.format)),
      _Chip(label: _statusLabel(manga.status)),
      if (manga.totalChapters != null)
        _Chip(label: l10n.mangaCardChapterCountLabel(manga.totalChapters!)),
      if (manga.averageScore != null)
        _Chip(label: '★ ${(manga.averageScore! / 10).toStringAsFixed(1)}'),
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  String _formatLabel(MangaFormat format) {
    return switch (format) {
      MangaFormat.manga => 'Manga',
      MangaFormat.manhwa => 'Manhwa',
      MangaFormat.manhua => 'Manhua',
      MangaFormat.oneShot => 'One-shot',
      MangaFormat.doujinshi => 'Doujinshi',
      MangaFormat.unknown => '—',
    };
  }

  String _statusLabel(MangaStatus status) {
    return switch (status) {
      MangaStatus.releasing => 'Releasing',
      MangaStatus.finished => 'Finished',
      MangaStatus.notYetReleased => 'Upcoming',
      MangaStatus.cancelled => 'Cancelled',
      MangaStatus.hiatus => 'Hiatus',
      MangaStatus.unknown => '—',
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        border: Border.all(color: KumoriyaColors.borderSubtle),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: KumoriyaColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Toggle row for Favorite + Subscribe. Mirrors the anime detail
/// pattern but reads/writes the manga library store. Both toggles are
/// optimistic: the storage call is fire-and-forget, then the relevant
/// providers are invalidated so the new state propagates everywhere
/// (Library tab, this row, any other manga card).
class _LibraryActionsRow extends ConsumerWidget {
  const _LibraryActionsRow({required this.anilistId});
  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavAsync = ref.watch(isFavoriteMangaProvider(anilistId));
    final isSubAsync = ref.watch(isSubscribedMangaProvider(anilistId));
    final isFav = isFavAsync.value ?? false;
    final isSub = isSubAsync.value ?? false;
    final l10n = context.l10n;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        _ActionPill(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: isFav
              ? l10n.mangaDetailRemoveFavorite
              : l10n.mangaDetailAddFavorite,
          active: isFav,
          onTap: () async {
            await ref
                .read(mangaLibraryStoreProvider)
                .setFavorite(anilistId, isFavorite: !isFav);
            ref.invalidate(favoriteMangaIdsProvider);
          },
        ),
        _ActionPill(
          icon: isSub
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          label: isSub
              ? l10n.mangaDetailUnsubscribe
              : l10n.mangaDetailSubscribe,
          active: isSub,
          onTap: () async {
            await ref
                .read(mangaLibraryStoreProvider)
                .setSubscription(anilistId, notify: !isSub);
            ref.invalidate(subscribedMangaIdsProvider);
          },
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? KumoriyaColors.primary : KumoriyaColors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        // ignore: discarded_futures
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleMangaSynopsis extends StatefulWidget {
  const _CollapsibleMangaSynopsis({required this.synopsis});

  final String synopsis;

  @override
  State<_CollapsibleMangaSynopsis> createState() =>
      _CollapsibleMangaSynopsisState();
}

class _CollapsibleMangaSynopsisState extends State<_CollapsibleMangaSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: <Widget>[
              Text(
                context.l10n.mangaDetailSynopsis,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: KumoriyaColors.textTertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: TranslatedDynamicText(
            widget.synopsis,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              height: 1.5,
              color: KumoriyaColors.textSecondary,
            ),
          ),
          secondChild: TranslatedDynamicText(
            widget.synopsis,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              height: 1.5,
              color: KumoriyaColors.textSecondary,
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

class _MangaRelationsSection extends StatefulWidget {
  const _MangaRelationsSection({required this.relations});

  final List<MangaRelation> relations;

  @override
  State<_MangaRelationsSection> createState() => _MangaRelationsSectionState();
}

class _MangaRelationsSectionState extends State<_MangaRelationsSection> {
  static const int _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visible = _expanded
        ? widget.relations
        : widget.relations.take(_collapsedCount);
    final canToggle = widget.relations.length > _collapsedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.relationsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: KumoriyaColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...visible.map(
          (relation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MangaRelationCard(relation: relation),
          ),
        ),
        if (canToggle)
          _RelationsToggleButton(
            expanded: _expanded,
            hiddenCount: widget.relations.length - _collapsedCount,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}

class _RelationsToggleButton extends StatelessWidget {
  const _RelationsToggleButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onPressed,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 18,
        ),
        label: Text(
          expanded
              ? _relationsShowLessLabel(context)
              : _relationsShowMoreLabel(context, hiddenCount),
        ),
        style: TextButton.styleFrom(
          foregroundColor: KumoriyaColors.primary,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _MangaRelationCard extends StatelessWidget {
  const _MangaRelationCard({required this.relation});

  final MangaRelation relation;

  @override
  Widget build(BuildContext context) {
    final target = relation.target;
    return InkWell(
      borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => switch (target.kind) {
            MediaKind.anime => AnimeDetailPage(anilistId: target.anilistId),
            MediaKind.manga => MangaDetailPage(anilistId: target.anilistId),
          },
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KumoriyaColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            KumoriyaCachedImage(
              url: target.coverImageUrl,
              bucket: KumoriyaImageCacheBucket.artwork,
              width: 44,
              height: 58,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(KumoriyaRadius.md),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    target.titleRomaji,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      MetaChip(
                        label: _displayMangaRelationTypeLabel(
                          context,
                          relation.type,
                        ),
                        isActive: true,
                      ),
                      MetaChip(
                        label: _mangaRelationTargetFormatLabel(relation),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: KumoriyaColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterPageSelector extends StatelessWidget {
  const _ChapterPageSelector({
    required this.pageCount,
    required this.currentPage,
    required this.pageSize,
    required this.chapters,
    required this.onPageSelected,
  });

  final int pageCount;
  final int currentPage;
  final int pageSize;
  final List<MangaChapter> chapters;
  final void Function(int page) onPageSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pageCount,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final startIndex = index * pageSize;
          final pageChapters = chapters
              .skip(startIndex)
              .take(pageSize)
              .toList(growable: false);
          final label = _chapterPageRangeLabel(pageChapters);
          final isSelected = index == currentPage;
          return ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 11)),
            selected: isSelected,
            onSelected: (_) => onPageSelected(index),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

String _chapterPageRangeLabel(List<MangaChapter> chapters) {
  if (chapters.isEmpty) return '—';
  double min = chapters.first.number;
  double max = chapters.first.number;
  for (final chapter in chapters.skip(1)) {
    if (chapter.number < min) min = chapter.number;
    if (chapter.number > max) max = chapter.number;
  }
  final start = _formatChapterRangeNumber(min);
  final end = _formatChapterRangeNumber(max);
  return start == end ? start : '$start–$end';
}

String _formatChapterRangeNumber(double value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _ChaptersSliver extends ConsumerStatefulWidget {
  const _ChaptersSliver({required this.anilistId});
  final int anilistId;

  @override
  ConsumerState<_ChaptersSliver> createState() => _ChaptersSliverState();
}

class _ChaptersSliverState extends ConsumerState<_ChaptersSliver> {
  static const int _pageSize = 50;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final asyncChapters = ref.watch(mangaChaptersProvider(widget.anilistId));
    return asyncChapters.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Text(
            e.toString(),
            style: const TextStyle(color: KumoriyaColors.statusDanger),
          ),
        ),
      ),
      data: (chapters) {
        if (chapters.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Text(
                context.l10n.mangaDetailNoChaptersInLanguage,
                style: const TextStyle(color: KumoriyaColors.textMuted),
              ),
            ),
          );
        }

        // Partition into in-app playable (top of the list) and
        // external publisher mirrors (bottom). External chapters
        // can't be opened by the reader — the row taps url_launcher
        // instead. Order within each bucket is preserved from the
        // composite repository.
        final playable = chapters
            .where((c) => c.externalUrl == null)
            .toList(growable: false);
        final external = chapters
            .where((c) => c.externalUrl != null)
            .toList(growable: false);

        final pageCount = (playable.length / _pageSize).ceil().clamp(1, 9999);
        final page = _page.clamp(0, pageCount - 1);
        if (page != _page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _page = page);
          });
        }
        final pageStart = page * _pageSize;
        final visiblePlayable = playable
            .skip(pageStart)
            .take(_pageSize)
            .toList(growable: false);
        final l10n = context.l10n;
        return SliverToBoxAdapter(
          child: Column(
            children: <Widget>[
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _ChapterPageSelector(
                    pageCount: pageCount,
                    currentPage: page,
                    pageSize: _pageSize,
                    chapters: playable,
                    onPageSelected: (selectedPage) {
                      setState(() => _page = selectedPage);
                    },
                  ),
                ),
              for (final chapter in visiblePlayable)
                _ChapterRow(chapter: chapter, mangaAnilistId: widget.anilistId),
              if (external.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.mangaDetailExternalChaptersTitle,
                        style: const TextStyle(
                          color: KumoriyaColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.mangaDetailExternalChaptersHint,
                        style: const TextStyle(
                          color: KumoriyaColors.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final chapter in external)
                  _ExternalChapterRow(chapter: chapter),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Compact chip beside the "Capítulos" header that opens a modal
/// sheet listing the scanlators that uploaded this manga, with one
/// "Auto" option that resets to the default dedup rule.
///
/// Hidden when the chapter cache has not been warmed yet (e.g. first
/// frame after navigation) or when the source returned chapters with
/// no scanlator metadata at all.
class _ScanlatorPicker extends ConsumerWidget {
  const _ScanlatorPicker({required this.anilistId});
  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(availableScanlatorsProvider(anilistId));
    final preferredAsync = ref.watch(preferredScanlatorProvider(anilistId));
    if (options.isEmpty) return const SizedBox.shrink();
    final preferred = preferredAsync.value;
    final l10n = context.l10n;
    final label = preferred ?? l10n.mangaDetailScanlatorAuto;
    return InkWell(
      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      onTap: () => _openSheet(context, ref, options, preferred),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          border: Border.all(color: KumoriyaColors.borderSubtle),
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.tune_rounded,
              size: 14,
              color: KumoriyaColors.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                '${l10n.mangaDetailScanlatorLabel}: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KumoriyaColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: KumoriyaColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    List<ScanlatorOption> options,
    String? current,
  ) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<_PickResult?>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.mangaDetailScanlatorPickerTitle,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  current == null
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: current == null
                      ? KumoriyaColors.primary
                      : KumoriyaColors.textMuted,
                ),
                title: Text(
                  l10n.mangaDetailScanlatorAuto,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mangaDetailScanlatorAutoHint,
                  style: const TextStyle(
                    color: KumoriyaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(const _PickResult(scanlator: null)),
              ),
              const Divider(height: 1, color: KumoriyaColors.borderSubtle),
              for (final opt in options)
                ListTile(
                  leading: Icon(
                    current == opt.name
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: current == opt.name
                        ? KumoriyaColors.primary
                        : KumoriyaColors.textMuted,
                  ),
                  title: Text(
                    opt.name,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: opt.lastReleaseAt != null
                      ? Text(
                          _formatLastRelease(l10n, opt.lastReleaseAt!),
                          style: const TextStyle(
                            color: KumoriyaColors.textMuted,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: Text(
                    l10n.mangaDetailScanlatorChapterCount(opt.chapterCount),
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(ctx).pop(_PickResult(scanlator: opt.name)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked.scanlator == current) return;
    await ref
        .read(mangaLibraryStoreProvider)
        .setPreferredScanlator(anilistId, picked.scanlator);
    ref.invalidate(preferredScanlatorProvider(anilistId));
    ref.invalidate(mangaChaptersProvider(anilistId));
  }
}

/// Internal value object used to differentiate "user picked Auto"
/// (`scanlator == null`) from "user dismissed the sheet" (`null` from
/// `showModalBottomSheet`).
class _PickResult {
  const _PickResult({required this.scanlator});
  final String? scanlator;
}

/// Formats a "last release was X ago" hint for the scanlator picker
/// rows (S1.F). Buckets:
///
///  * Same calendar day  → "Last release today"
///  * 1-30 days          → "Last release N days ago"
///  * 31+ days           → "Last release N months ago" (rounded down)
///
/// We deliberately stop at months — anything older than ~12 months is
/// still meaningful as "this group hasn't shipped in a year+", and we
/// don't want to invent a "years ago" plural form for what is already
/// a soft signal.
String _formatLastRelease(AppLocalizations l10n, DateTime when) {
  final now = DateTime.now();
  // Compare on day boundaries so "earlier today" still reads as
  // today even when the timestamp is N hours ago.
  final today = DateTime(now.year, now.month, now.day);
  final whenDay = DateTime(when.year, when.month, when.day);
  final days = today.difference(whenDay).inDays;
  if (days <= 0) return l10n.mangaDetailScanlatorLastReleaseToday;
  if (days < 31) return l10n.mangaDetailScanlatorLastReleaseDays(days);
  final months = days ~/ 30;
  return l10n.mangaDetailScanlatorLastReleaseMonths(months);
}

/// Compact chip beside the chapters header that opens a modal sheet
/// listing the source plugins that contributed playable chapters for
/// this manga, with one "All" option that resets to the default
/// fan-out + cross-source dedup behaviour.
///
/// Hidden when the chapter cache has not been warmed yet OR when only
/// one plugin contributed (no choice to offer).
class _SourcePicker extends ConsumerWidget {
  const _SourcePicker({required this.anilistId});
  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(availableSourcesProvider(anilistId));
    final preferredAsync = ref.watch(preferredSourceIdProvider(anilistId));
    // Only one option AND no explicit user pin → nothing to pick. The
    // chip stays hidden so it doesn't take real estate from the
    // scanlator picker.
    if (options.length <= 1 && preferredAsync.value == null) {
      return const SizedBox.shrink();
    }
    final preferredId = preferredAsync.value;
    final preferredOption = preferredId == null
        ? null
        : options.firstWhere(
            (o) => o.sourceId == preferredId,
            orElse: () => (
              sourceId: preferredId,
              displayName: preferredId,
              chapterCount: 0,
            ),
          );
    final l10n = context.l10n;
    final label = preferredOption?.displayName ?? l10n.mangaDetailSourceAuto;
    return InkWell(
      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      onTap: () => _openSheet(context, ref, options, preferredId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          border: Border.all(color: KumoriyaColors.borderSubtle),
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_outlined,
              size: 14,
              color: KumoriyaColors.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                '${l10n.mangaDetailSourceLabel}: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KumoriyaColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: KumoriyaColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    List<SourceOption> options,
    String? current,
  ) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<_SourcePickResult?>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.mangaDetailSourcePickerTitle,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  current == null
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: current == null
                      ? KumoriyaColors.primary
                      : KumoriyaColors.textMuted,
                ),
                title: Text(
                  l10n.mangaDetailSourceAuto,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mangaDetailSourceAutoHint,
                  style: const TextStyle(
                    color: KumoriyaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.of(
                  ctx,
                ).pop(const _SourcePickResult(sourceId: null)),
              ),
              const Divider(height: 1, color: KumoriyaColors.borderSubtle),
              for (final opt in options)
                ListTile(
                  leading: Icon(
                    current == opt.sourceId
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: current == opt.sourceId
                        ? KumoriyaColors.primary
                        : KumoriyaColors.textMuted,
                  ),
                  title: Text(
                    opt.displayName,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    l10n.mangaDetailScanlatorChapterCount(opt.chapterCount),
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.of(
                    ctx,
                  ).pop(_SourcePickResult(sourceId: opt.sourceId)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked.sourceId == current) return;
    await ref
        .read(mangaLibraryStoreProvider)
        .setPreferredSourceId(anilistId, picked.sourceId);
    ref.invalidate(preferredSourceIdProvider(anilistId));
    ref.invalidate(mangaChaptersProvider(anilistId));
  }
}

class _SourcePickResult {
  const _SourcePickResult({required this.sourceId});
  final String? sourceId;
}

String _displayMangaRelationTypeLabel(
  BuildContext context,
  MangaRelationType type,
) {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  return switch (type) {
    MangaRelationType.prequel => spanish ? 'Precuela' : 'Prequel',
    MangaRelationType.sequel => spanish ? 'Secuela' : 'Sequel',
    MangaRelationType.sideStory => spanish ? 'Historia lateral' : 'Side story',
    MangaRelationType.adaptation => spanish ? 'Adaptación' : 'Adaptation',
    MangaRelationType.spinOff => 'Spin-off',
    MangaRelationType.other => spanish ? 'Relación' : 'Related',
  };
}

String _formatMangaFormatLabel(MangaFormat format) {
  return switch (format) {
    MangaFormat.manga => 'Manga',
    MangaFormat.manhwa => 'Manhwa',
    MangaFormat.manhua => 'Manhua',
    MangaFormat.oneShot => 'One-shot',
    MangaFormat.doujinshi => 'Doujinshi',
    MangaFormat.unknown => '—',
  };
}

String _mangaRelationTargetFormatLabel(MangaRelation relation) {
  return switch (relation.targetKind) {
    MediaKind.anime => relation.target.formatLabel ?? 'Anime',
    MediaKind.manga => _formatMangaFormatLabel(relation.manga.format),
  };
}

String _relationsShowMoreLabel(BuildContext context, int hiddenCount) {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  return spanish
      ? 'Ver $hiddenCount relaciones más'
      : 'Show $hiddenCount more relations';
}

String _relationsShowLessLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Ver menos relaciones'
      : 'Show fewer relations';
}

/// Renders a chapter that lives on an official external publisher
/// (MangaPlus, Viz, ComiXology, …). Tapping launches the system
/// browser via `url_launcher`. The reader is never engaged.
class _ExternalChapterRow extends StatelessWidget {
  const _ExternalChapterRow({required this.chapter});
  final MangaChapter chapter;

  Future<void> _open(BuildContext context) async {
    final url = chapter.externalUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mangaDetailOpenExternalFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chapterNum = chapter.number == chapter.number.truncateToDouble()
        ? chapter.number.toInt().toString()
        : chapter.number.toStringAsFixed(1);
    final volumeLabel = chapter.volume != null
        ? '${l10n.mangaDetailVolumeLabel(chapter.volume!)} · '
        : '';
    final providerLabel = chapter.scanlator?.isNotEmpty == true
        ? chapter.scanlator!
        : (chapter.externalUrl?.host ?? 'external');
    final subtitle =
        '$volumeLabel${l10n.mangaDetailChapterLabel(chapterNum)} · $providerLabel';
    return InkWell(
      onTap: () {
        // ignore: discarded_futures
        _open(context);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.open_in_new_rounded,
              color: KumoriyaColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chapter.title.isNotEmpty
                        ? chapter.title
                        : l10n.mangaDetailChapterLabel(chapterNum),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                l10n.mangaDetailOpenExternal,
                style: const TextStyle(
                  color: KumoriyaColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({required this.chapter, required this.mangaAnilistId});
  final MangaChapter chapter;
  final int mangaAnilistId;

  Future<void> _openReader(BuildContext context, WidgetRef ref) async {
    // Resolve the manga format from the in-flight detail provider so
    // the reader picks the right default mode (vertical for manhwa).
    // Falls back to `unknown` (paginated) if the detail isn't ready
    // yet, which is harmless — the user can scroll to override.
    final detailAsync = ref.read(mangaDetailProvider(mangaAnilistId));
    final format = detailAsync.value?.manga.format ?? MangaFormat.unknown;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MangaReaderRoute(
          mangaAnilistId: mangaAnilistId,
          chapter: chapter,
          format: format,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final volumeLabel = chapter.volume != null
        ? '${l10n.mangaDetailVolumeLabel(chapter.volume!)} · '
        : '';
    final chapterNum = chapter.number == chapter.number.truncateToDouble()
        ? chapter.number.toInt().toString()
        : chapter.number.toStringAsFixed(1);
    final scanlator = chapter.scanlator;
    final subtitle = scanlator != null && scanlator.isNotEmpty
        ? '$volumeLabel${l10n.mangaDetailChapterLabel(chapterNum)} · $scanlator'
        : '$volumeLabel${l10n.mangaDetailChapterLabel(chapterNum)}';
    return InkWell(
      onTap: () => _openReader(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chapter.title.isNotEmpty
                        ? chapter.title
                        : l10n.mangaDetailChapterLabel(chapterNum),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            Builder(
              builder: (_) {
                final detail = ref.read(mangaDetailProvider(mangaAnilistId));
                final t = detail.value?.manga.title;
                return ChapterDownloadButton(
                  mangaAnilistId: mangaAnilistId,
                  mangaTitle: t?.english ?? t?.romaji,
                  chapter: chapter,
                );
              },
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: KumoriyaColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;
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
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
