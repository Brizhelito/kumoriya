import 'package:flutter/material.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';
import 'kumoriya_cached_image.dart';

class ContinueWatchingCard extends StatefulWidget {
  const ContinueWatchingCard({
    super.key,
    required this.entry,
    required this.title,
    required this.imageUrl,
    required this.onResume,
    this.isLaunching = false,
  });

  final AnimeWatchHistory entry;
  final String title;
  final String? imageUrl;
  final VoidCallback onResume;
  final bool isLaunching;

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final epNumber = widget.entry.lastEpisodeNumber.toInt();
    final progressFraction = (widget.entry.progressFraction ?? 0).clamp(
      0.0,
      1.0,
    );
    final progressPercent = (progressFraction * 100).round().clamp(0, 100);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLaunching ? null : widget.onResume,
        child: Container(
          width: 320,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(color: KumoriyaColors.borderSubtle),
            color: KumoriyaColors.surface,
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AnimatedOpacity(
                      opacity: _hovered ? 0.88 : 0.72,
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedScale(
                        scale: _hovered ? 1.04 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        child: KumoriyaCachedImage(
                          url: widget.imageUrl,
                          bucket: KumoriyaImageCacheBucket.artwork,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Color(0xAA130D1A),
                          ],
                          stops: <double>[0.25, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _EpisodePill(epNumber: epNumber),
                          const Spacer(),
                          if (widget.isLaunching)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: KumoriyaColors.surfaceBright.withValues(alpha: 0.96),
                    border: Border(
                      top: BorderSide(
                        color: KumoriyaColors.borderSubtle.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: KumoriyaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${context.l10n.continueWatchingEpisode(epNumber)} · $progressPercent%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: KumoriyaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedScale(
                        scale: _hovered ? 1.03 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        child: _ResumeButton(
                          onTap: widget.isLaunching ? null : widget.onResume,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 2.5,
                  backgroundColor: KumoriyaColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    KumoriyaColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodePill extends StatelessWidget {
  const _EpisodePill({required this.epNumber});

  final int epNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: KumoriyaColors.primary,
        borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: KumoriyaColors.primary.withValues(alpha: 0.30),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        'EP $epNumber',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? (desktop ? 36 : 40) : (desktop ? 44 : 50),
        width: compact ? (desktop ? 112 : 118) : double.infinity,
        decoration: BoxDecoration(
          color: KumoriyaColors.primary,
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: KumoriyaColors.primary.withValues(alpha: 0.30),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: compact ? (desktop ? 16 : 18) : (desktop ? 18 : 20),
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              context.l10n.resumeLabel,
              style: TextStyle(
                fontSize: compact ? (desktop ? 10 : 11) : (desktop ? 11 : 12),
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: compact ? 0.8 : 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
