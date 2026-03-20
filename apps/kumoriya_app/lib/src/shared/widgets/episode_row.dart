import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';
import 'translated_dynamic_text.dart';

class EpisodeRow extends StatefulWidget {
  const EpisodeRow({
    super.key,
    required this.number,
    required this.displayTitle,
    required this.secondaryText,
    required this.sourceBadges,
    this.progressFraction,
    this.isCurrentEpisode = false,
    this.isPlayable = true,
    this.isWatched = false,
    this.activeLabel,
    this.trailingAccessory,
    this.playIconSize = 28,
    this.showWatchedCheck = true,
    this.onTap,
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<Widget> sourceBadges;
  final double? progressFraction;
  final bool isCurrentEpisode;
  final bool isPlayable;
  final bool isWatched;
  final String? activeLabel;
  final Widget? trailingAccessory;
  final double playIconSize;
  final bool showWatchedCheck;
  final VoidCallback? onTap;

  @override
  State<EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<EpisodeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isCurrentEpisode;
    final epNum = widget.number.toInt();

    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        onTap: widget.isPlayable ? widget.onTap : null,
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? KumoriyaColors.primary.withValues(alpha: 0.20)
                : _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surfaceDim,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: isActive
                  ? KumoriyaColors.primary.withValues(alpha: 0.30)
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _EpisodeNumberBox(
                number: epNum,
                isActive: isActive,
                isPlayable: widget.isPlayable,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TranslatedDynamicText(
                            widget.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: isActive
                                      ? KumoriyaColors.textPrimary
                                      : KumoriyaColors.textSecondary,
                                ),
                          ),
                        ),
                        if (isActive && widget.activeLabel != null)
                          _EpisodeStatusBadge(label: widget.activeLabel!)
                        else if (isActive)
                          const _NowPlayingBadge()
                        else if (widget.showWatchedCheck && widget.isWatched)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: KumoriyaColors.statusAiring,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (widget.sourceBadges.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: widget.sourceBadges,
                          ),
                        if (widget.sourceBadges.isNotEmpty)
                          const SizedBox(height: 6),
                        Text(
                          widget.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    if (widget.progressFraction != null) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                        child: LinearProgressIndicator(
                          value: widget.progressFraction,
                          minHeight: 3,
                          backgroundColor: KumoriyaColors.borderSubtle,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            KumoriyaColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailingAccessory != null) ...<Widget>[
                const SizedBox(width: 10),
                widget.trailingAccessory!,
              ],
              if (widget.isPlayable) ...<Widget>[
                const SizedBox(width: 10),
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: widget.playIconSize,
                  color: isActive
                      ? KumoriyaColors.primary
                      : _hovered
                      ? KumoriyaColors.textMuted
                      : KumoriyaColors.textDisabled,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!widget.isPlayable) {
      row = Opacity(opacity: 0.45, child: row);
    }
    return row;
  }
}

class _EpisodeNumberBox extends StatelessWidget {
  const _EpisodeNumberBox({
    required this.number,
    required this.isActive,
    required this.isPlayable,
  });

  final int number;
  final bool isActive;
  final bool isPlayable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isActive
            ? KumoriyaColors.primaryContainer
            : isPlayable
            ? KumoriyaColors.surface
            : KumoriyaColors.borderSubtle,
        borderRadius: BorderRadius.circular(KumoriyaRadius.md),
        border: isActive
            ? null
            : Border.all(color: KumoriyaColors.borderSubtle),
        boxShadow: isActive
            ? <BoxShadow>[
                BoxShadow(
                  color: KumoriyaColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString().padLeft(2, '0'),
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: isActive
              ? KumoriyaColors.textPrimary
              : isPlayable
              ? KumoriyaColors.textMuted
              : KumoriyaColors.textDisabled,
        ),
      ),
    );
  }
}

class _EpisodeStatusBadge extends StatelessWidget {
  const _EpisodeStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: KumoriyaColors.primary.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: KumoriyaColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NowPlayingBadge extends StatefulWidget {
  const _NowPlayingBadge();

  @override
  State<_NowPlayingBadge> createState() => _NowPlayingBadgeState();
}

class _NowPlayingBadgeState extends State<_NowPlayingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: KumoriyaColors.primary.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        ),
        child: Text(
          context.l10n.episodePlaying,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: KumoriyaColors.primary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class EpisodeAudioBadge extends StatelessWidget {
  const EpisodeAudioBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: KumoriyaColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: KumoriyaColors.textDisabled,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
