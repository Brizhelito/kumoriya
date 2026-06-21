import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_button.dart';
import '../primitives/cloud_progress.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// 21:9 cinematic continue-watching card with resume button on hover.
class ContinueWatchingCard extends StatefulWidget {
  const ContinueWatchingCard({
    super.key,
    required this.animeTitle,
    required this.episodeLabel,
    required this.progress,
    required this.onResume,
    this.imageUrl,
  });

  final String animeTitle;
  final String episodeLabel;
  final double progress;
  final VoidCallback onResume;
  final String? imageUrl;

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: CloudMotion.base,
        curve: CloudMotion.easeCloud,
        width: 320,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CloudRadius.lg),
          boxShadow: _hovered ? colors.shadowHover : colors.shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Cinematic banner
            AspectRatio(
              aspectRatio: 21 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Background
                  AnimatedOpacity(
                    duration: CloudMotion.fast,
                    opacity: _hovered ? 0.8 : 0.6,
                    child: ColoredBox(
                      color: colors.surface2,
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: colors.textSoft,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            colors.bg.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Episode label
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Text(
                      widget.episodeLabel,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  // Resume button (visible on hover)
                  AnimatedPositioned(
                    duration: CloudMotion.fast,
                    bottom: _hovered ? 8 : -40,
                    right: 12,
                    child: CloudButton.primary(
                      onPressed: widget.onResume,
                      label: 'Resume',
                      icon: Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: CloudSpacing.s3,
                vertical: CloudSpacing.s2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.animeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: CloudSpacing.s1),
                  CloudProgress(value: widget.progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
