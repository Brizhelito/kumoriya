import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'anime_detail_page.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(calendarCatalogProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                context.l10n.calendarTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: KumoriyaColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                context.l10n.calendarSubtitle,
                style: const TextStyle(fontSize: 13, color: KumoriyaColors.textMuted),
              ),
            ),
            Expanded(
              child: catalogState.when(
                loading: () => const LoadingStateView(),
                error: (_, _) => ErrorStateView(
                  message: context.l10n.genericLoadFailure,
                  onRetry: () => ref.invalidate(calendarCatalogProvider),
                ),
                data: (result) => result.fold(
                  onFailure: (error) => ErrorStateView(
                    message: mapErrorMessage(context, error),
                    onRetry: () => ref.invalidate(calendarCatalogProvider),
                  ),
                  onSuccess: (animeList) {
                    final airing = animeList
                        .where(
                          (a) =>
                              a.status == AnimeStatus.releasing ||
                              a.status == AnimeStatus.notYetReleased,
                        )
                        .toList(growable: false);

                    if (airing.isEmpty) {
                      return EmptyStateView(
                        message: context.l10n.calendarNoAiring,
                      );
                    }

                    final grouped = <int, List<Anime>>{};
                    final unknownSchedule = <Anime>[];

                    for (final anime in airing) {
                      final nextAiringAt = anime.nextAiringAt?.toLocal();
                      if (nextAiringAt == null) {
                        unknownSchedule.add(anime);
                        continue;
                      }

                      grouped
                          .putIfAbsent(nextAiringAt.weekday, () => <Anime>[])
                          .add(anime);
                    }

                    for (final items in grouped.values) {
                      items.sort((left, right) {
                        final leftDate = left.nextAiringAt;
                        final rightDate = right.nextAiringAt;
                        if (leftDate == null && rightDate == null) {
                          return left.title.romaji.compareTo(
                            right.title.romaji,
                          );
                        }
                        if (leftDate == null) {
                          return 1;
                        }
                        if (rightDate == null) {
                          return -1;
                        }
                        final byDate = leftDate.compareTo(rightDate);
                        if (byDate != 0) {
                          return byDate;
                        }
                        return left.title.romaji.compareTo(right.title.romaji);
                      });
                    }

                    unknownSchedule.sort(
                      (left, right) =>
                          left.title.romaji.compareTo(right.title.romaji),
                    );

                    final sections = <Widget>[];
                    for (final weekday in <int>[
                      DateTime.monday,
                      DateTime.tuesday,
                      DateTime.wednesday,
                      DateTime.thursday,
                      DateTime.friday,
                      DateTime.saturday,
                      DateTime.sunday,
                    ]) {
                      final items = grouped[weekday];
                      if (items == null || items.isEmpty) {
                        continue;
                      }

                      sections.add(
                        _CalendarSection(
                          title: _weekdayLabel(context, weekday),
                          items: items,
                        ),
                      );
                    }

                    if (unknownSchedule.isNotEmpty) {
                      sections.add(
                        _CalendarSection(
                          title: _unknownScheduleLabel(context),
                          items: unknownSchedule,
                          showTime: false,
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: sections,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayLabel(BuildContext context, int weekday) {
  final now = DateTime.now();
  final daysUntilWeekday = (weekday - now.weekday) % 7;
  final date = now.add(Duration(days: daysUntilWeekday));
  return DateFormat.EEEE(Localizations.localeOf(context).toString()).format(date);
}

String _unknownScheduleLabel(BuildContext context) {
  return context.l10n.calendarUnknownSchedule;
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.title,
    required this.items,
    this.showTime = true,
  });

  final String title;
  final List<Anime> items;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: KumoriyaColors.textPrimary,
              ),
            ),
          ),
          ...items.map(
            (anime) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AiringRow(
                anime: anime,
                showTime: showTime,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnimeDetailPage(anilistId: anime.anilistId),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiringRow extends StatefulWidget {
  const _AiringRow({
    required this.anime,
    required this.onTap,
    required this.showTime,
  });

  final Anime anime;
  final VoidCallback onTap;
  final bool showTime;

  @override
  State<_AiringRow> createState() => _AiringRowState();
}

class _AiringRowState extends State<_AiringRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final localNextAiring = anime.nextAiringAt?.toLocal();
    final timeLabel = localNextAiring == null
        ? '--:--'
        : DateFormat.Hm(
            Localizations.localeOf(context).toString(),
          ).format(localNextAiring);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                child: KumoriyaCachedImage(
                  url: anime.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      anime.title.romaji,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    if (anime.releaseYear != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        anime.releaseYear.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: KumoriyaColors.textDisabled,
                        ),
                      ),
                    ],
                    if (anime.nextAiringEpisodeNumber != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Episode ${anime.nextAiringEpisodeNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KumoriyaColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (widget.showTime)
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                  if (widget.showTime) const SizedBox(height: 6),
                  _StatusPill(status: anime.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AnimeStatus status;

  @override
  Widget build(BuildContext context) {
    final isReleasing = status == AnimeStatus.releasing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isReleasing
            ? KumoriyaColors.primary.withValues(alpha: 0.14)
            : KumoriyaColors.borderSubtle,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        isReleasing ? 'AIRING' : 'UPCOMING',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isReleasing
              ? KumoriyaColors.primary
              : KumoriyaColors.textDisabled,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
