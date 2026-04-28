import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
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
                const SizedBox(height: 20),
                Text(
                  l10n.mangaDetailSynopsis,
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (detail.synopsis == null || detail.synopsis!.isEmpty)
                      ? l10n.mangaDetailNoSynopsis
                      : _stripHtml(detail.synopsis!),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: KumoriyaColors.textSecondary,
                    height: 1.55,
                  ),
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
                Text(
                  l10n.mangaDetailChapters,
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        _ChaptersSliver(anilistId: manga.anilistId),
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

class _ChaptersSliver extends ConsumerWidget {
  const _ChaptersSliver({required this.anilistId});
  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChapters = ref.watch(mangaChaptersProvider(anilistId));
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
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) =>
                _ChapterRow(chapter: chapters[i], mangaAnilistId: anilistId),
            childCount: chapters.length,
          ),
        );
      },
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
