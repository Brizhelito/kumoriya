import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
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

class _CalendarPageState extends ConsumerState<CalendarPage> {
  @override
  void initState() {
    super.initState();
    // Prefetch prev + next month in the background so swiping left/right
    // through the month navigator is instant. The currently-focused month
    // is already driven by [calendarFocusedMonthSlotsProvider] in build().
    //
    // Deferred to a post-frame callback so Riverpod has finished wiring
    // this widget's subscriptions before we trigger additional providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = ref.read(calendarFocusMonthProvider);
      final prev = DateTime(focus.year, focus.month - 1);
      final next = DateTime(focus.year, focus.month + 1);
      // Fire-and-forget: the FutureProviders keep themselves alive for
      // 10 min, which is longer than a typical calendar browsing session.
      ref.read(calendarMonthSlotsProvider(prev).future).ignore();
      ref.read(calendarMonthSlotsProvider(next).future).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(calendarFocusedMonthSlotsProvider);
    // Fast-path: reuse the home-page week data (already cached) so today's
    // schedule is visible immediately while the full month loads.
    final weekSlotsAsync = ref.watch(calendarCatalogProvider);

    final partialSlots = weekSlotsAsync.maybeWhen(
      data: (r) => r.fold(onFailure: (_) => null, onSuccess: (s) => s),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: slotsAsync.when(
          loading: () => partialSlots != null && partialSlots.isNotEmpty
              ? _CalendarBody(slots: partialSlots)
              : const LoadingStateView(),
          error: (_, _) => ErrorStateView(
            message: context.l10n.genericLoadFailure,
            onRetry: () => _retryFocusedMonth(ref),
          ),
          data: (result) => result.fold(
            onFailure: (error) => ErrorStateView(
              message: mapErrorMessage(context, error),
              onRetry: () => _retryFocusedMonth(ref),
            ),
            onSuccess: (slots) => _CalendarBody(slots: slots),
          ),
        ),
      ),
    );
  }
}

void _retryFocusedMonth(WidgetRef ref) {
  final month = calendarMonthKey(ref.read(calendarFocusMonthProvider));
  ref.invalidate(calendarMonthSlotsProvider(month));
  ref.invalidate(calendarFocusedMonthSlotsProvider);
}

// ---------------------------------------------------------------------------
// Calendar body: header + month grid + day detail list
// ---------------------------------------------------------------------------

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.slots});

  final List<Anime> slots;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  late Map<DateTime, List<Anime>> _grouped;

  @override
  void initState() {
    super.initState();
    _grouped = _groupByDate(widget.slots);
  }

  @override
  void didUpdateWidget(covariant _CalendarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.slots, widget.slots)) {
      _grouped = _groupByDate(widget.slots);
    }
  }

  static Map<DateTime, List<Anime>> _groupByDate(List<Anime> slots) {
    final map = <DateTime, List<Anime>>{};
    for (final anime in slots) {
      final at = anime.nextAiringAt?.toLocal();
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day);
      map.putIfAbsent(day, () => <Anime>[]).add(anime);
    }
    // Sort each day's list by airing time.
    for (final list in map.values) {
      list.sort((a, b) {
        final at = a.nextAiringAt ?? DateTime(2100);
        final bt = b.nextAiringAt ?? DateTime(2100);
        return at.compareTo(bt);
      });
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final focusMonth = ref.watch(calendarFocusMonthProvider);
    final selectedDay = ref.watch(calendarSelectedDayProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Allowed navigation range: [prevMonth .. nextMonth].
    final minMonth = DateTime(now.year, now.month - 1);
    final maxMonth = DateTime(now.year, now.month + 1);

    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat.yMMMM(locale).format(focusMonth);

    final canGoBack = focusMonth.isAfter(minMonth);
    final canGoForward =
        focusMonth.isBefore(maxMonth) ||
        (focusMonth.year == maxMonth.year &&
            focusMonth.month == maxMonth.month &&
            false);

    final selectedAnime = _grouped[selectedDay] ?? const <Anime>[];

    return CustomScrollView(
      slivers: <Widget>[
        // Title + subtitle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              context.l10n.calendarTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.l10n.calendarSubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: KumoriyaColors.textTertiary,
              ),
            ),
          ),
        ),

        // Month navigation row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: canGoBack
                      ? () {
                          final prev = DateTime(
                            focusMonth.year,
                            focusMonth.month - 1,
                          );
                          ref
                              .read(calendarFocusMonthProvider.notifier)
                              .set(prev);
                          ref
                              .read(calendarSelectedDayProvider.notifier)
                              .set(DateTime(prev.year, prev.month));
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: KumoriyaColors.textPrimary,
                  disabledColor: KumoriyaColors.textDisabled,
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canGoForward
                      ? () {
                          final next = DateTime(
                            focusMonth.year,
                            focusMonth.month + 1,
                          );
                          ref
                              .read(calendarFocusMonthProvider.notifier)
                              .set(next);
                          ref
                              .read(calendarSelectedDayProvider.notifier)
                              .set(DateTime(next.year, next.month));
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: KumoriyaColors.textPrimary,
                  disabledColor: KumoriyaColors.textDisabled,
                ),
              ],
            ),
          ),
        ),

        // Week-day header + month grid
        SliverToBoxAdapter(child: _WeekdayHeader(locale: locale)),
        SliverToBoxAdapter(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -200 && canGoForward) {
                final next = DateTime(focusMonth.year, focusMonth.month + 1);
                ref.read(calendarFocusMonthProvider.notifier).set(next);
                ref
                    .read(calendarSelectedDayProvider.notifier)
                    .set(DateTime(next.year, next.month));
              } else if (details.primaryVelocity! > 200 && canGoBack) {
                final prev = DateTime(focusMonth.year, focusMonth.month - 1);
                ref.read(calendarFocusMonthProvider.notifier).set(prev);
                ref
                    .read(calendarSelectedDayProvider.notifier)
                    .set(DateTime(prev.year, prev.month));
              }
            },
            child: _MonthGrid(
              focusMonth: focusMonth,
              selectedDay: selectedDay,
              today: today,
              grouped: _grouped,
              minMonth: minMonth,
              maxMonth: maxMonth,
              onDayTapped: (day) {
                ref.read(calendarSelectedDayProvider.notifier).set(day);
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Selected-day anime list
        if (selectedAnime.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                context.l10n.calendarNoAiring,
                style: const TextStyle(
                  fontSize: 13,
                  color: KumoriyaColors.textDisabled,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: selectedAnime.length,
              itemBuilder: (context, index) {
                final anime = selectedAnime[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AiringRow(
                    anime: anime,
                    showTime: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AnimeDetailPage(anilistId: anime.anilistId),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday header row (Mon – Sun)
// ---------------------------------------------------------------------------

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    // Generate short weekday labels starting from Monday.
    final labels = List<String>.generate(7, (i) {
      // DateTime weekday: Monday = 1 ... Sunday = 7
      // Find the next Monday from epoch reference.
      final date = DateTime(2024, 1, 1 + i); // Jan 1 2024 is a Monday.
      return DateFormat.E(locale).format(date).toUpperCase();
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: KumoriyaColors.textDisabled,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusMonth,
    required this.selectedDay,
    required this.today,
    required this.grouped,
    required this.minMonth,
    required this.maxMonth,
    required this.onDayTapped,
  });

  final DateTime focusMonth;
  final DateTime selectedDay;
  final DateTime today;
  final Map<DateTime, List<Anime>> grouped;
  final DateTime minMonth;
  final DateTime maxMonth;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focusMonth.year, focusMonth.month);
    final daysInMonth = DateTime(focusMonth.year, focusMonth.month + 1, 0).day;
    // Monday = 1. Offset so column 0 = Monday.
    final startWeekday = (firstOfMonth.weekday - 1) % 7;

    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List<Widget>.generate(rowCount, (row) {
          return Row(
            children: List<Widget>.generate(7, (col) {
              final cellIndex = row * 7 + col;
              if (cellIndex < startWeekday ||
                  cellIndex >= startWeekday + daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }

              final day = cellIndex - startWeekday + 1;
              final date = DateTime(focusMonth.year, focusMonth.month, day);
              final isToday = date == today;
              final isSelected = date == selectedDay;
              final hasAiring = grouped.containsKey(date);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTapped(date),
                  child: _DayCell(
                    day: day,
                    isToday: isToday,
                    isSelected: isSelected,
                    hasAiring: hasAiring,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasAiring,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasAiring;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    if (isSelected) {
      bgColor = KumoriyaColors.primary;
      textColor = KumoriyaColors.textPrimary;
    } else if (isToday) {
      bgColor = KumoriyaColors.primaryContainer;
      textColor = KumoriyaColors.primary;
    } else {
      bgColor = Colors.transparent;
      textColor = KumoriyaColors.textSecondary;
    }

    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          if (hasAiring)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected
                    ? KumoriyaColors.primary
                    : KumoriyaColors.statusAiring,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 7),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airing row (reused from before)
// ---------------------------------------------------------------------------

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
