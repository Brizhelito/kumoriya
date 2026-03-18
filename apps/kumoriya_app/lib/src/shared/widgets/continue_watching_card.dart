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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLaunching ? null : widget.onResume,
        child: Container(
          width: 320,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(color: KumoriyaColors.borderSubtle),
            color: KumoriyaColors.surface.withValues(alpha: 0.5),
          ),
          child: AspectRatio(
            aspectRatio: 21 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedOpacity(
                  opacity: _hovered ? 0.80 : 0.60,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedScale(
                    scale: _hovered ? 1.05 : 1.0,
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
                      colors: <Color>[Colors.transparent, Color(0xD9130D1A)],
                      stops: <double>[0.3, 1.0],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[Color(0xCC130D1A), Colors.transparent],
                      stops: <double>[0.0, 0.6],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _EpisodePill(epNumber: epNumber),
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
                      const Spacer(),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: KumoriyaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Episode $epNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: KumoriyaColors.textPrimary,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedScale(
                        scale: _hovered ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        child: _ResumeButton(
                          onTap: widget.isLaunching ? null : widget.onResume,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  const _ResumeButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
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
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              context.l10n.resumeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
