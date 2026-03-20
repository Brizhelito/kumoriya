import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'anime_detail_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.calendarSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: KumoriyaColors.textTertiary,
                ),
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
                  onSuccess: (animeList) =>
                      _buildTabCalendar(context, animeList),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCalendar(BuildContext context, List<Anime> animeList) {
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
        icon: KumoriyaIcons.navCalendarActive,
      );
    }

    final grouped = <int, List<Anime>>{};
    final todayWeekday = DateTime.now().weekday;

    for (final anime in airing) {
      final nextAiringAt = anime.nextAiringAt?.toLocal();
      if (nextAiringAt == null) {
        grouped.putIfAbsent(todayWeekday, () => <Anime>[]).add(anime);
        continue;
      }
      grouped.putIfAbsent(nextAiringAt.weekday, () => <Anime>[]).add(anime);
    }

    for (final items in grouped.values) {
      items.sort((left, right) {
        final leftDate = left.nextAiringAt;
        final rightDate = right.nextAiringAt;
        if (leftDate == null && rightDate == null) {
          return left.title.romaji.compareTo(right.title.romaji);
        }
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;
        final byDate = leftDate.compareTo(rightDate);
        if (byDate != 0) return byDate;
        return left.title.romaji.compareTo(right.title.romaji);
      });
    }

    // Build ordered list of (weekday, label, items) tuples for tabs.
    final tabs =
        <({int weekday, String label, List<Anime> items, bool showTime})>[];

    for (final weekday in <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ]) {
      final items = grouped[weekday] ?? const <Anime>[];
      tabs.add((
        weekday: weekday,
        label: _weekdayShortLabel(context, weekday),
        items: List<Anime>.from(items, growable: false),
        showTime: true,
      ));
    }

    // Find the initial tab index — default to today's weekday.
    final todayIndex = tabs.indexWhere((t) => t.weekday == todayWeekday);
    final initialIndex = todayIndex >= 0 ? todayIndex : 0;

    // Recreate the tab controller only when the tab count changes.
    if (_tabController == null || _tabController!.length != tabs.length) {
      _tabController?.dispose();
      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: initialIndex,
      );
    }

    return Column(
      children: <Widget>[
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: KumoriyaColors.primary,
          unselectedLabelColor: KumoriyaColors.navInactive,
          indicatorColor: KumoriyaColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: tabs.map((tab) {
            final isToday = tab.weekday == todayWeekday;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(tab.label),
                  if (isToday) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: KumoriyaColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: tabs.map((tab) {
              if (tab.items.isEmpty) {
                return EmptyStateView(
                  message: context.l10n.calendarNoAiring,
                  icon: Icons.event_busy_rounded,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: tab.items.length,
                itemBuilder: (context, index) {
                  final anime = tab.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AiringRow(
                      anime: anime,
                      showTime: tab.showTime,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AnimeDetailPage(anilistId: anime.anilistId),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

String _weekdayShortLabel(BuildContext context, int weekday) {
  final now = DateTime.now();
  final daysUntilWeekday = (weekday - now.weekday) % 7;
  final date = now.add(Duration(days: daysUntilWeekday));
  return DateFormat.E(
    Localizations.localeOf(context).toString(),
  ).format(date).toUpperCase();
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
        : DateFormat.jm(
            Localizations.localeOf(context).toString(),
          ).format(localNextAiring);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surfaceDim,
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
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (anime.releaseYear != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        anime.releaseYear.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KumoriyaColors.textDisabled,
                        ),
                      ),
                    ],
                    if (anime.nextAiringEpisodeNumber != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.downloadEpisodeLabel(
                          anime.nextAiringEpisodeNumber!.toInt(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  KumoriyaStatusPill(status: anime.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
