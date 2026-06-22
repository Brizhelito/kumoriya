import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_badge.dart';
import '../primitives/cloud_cached_image.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Poster card for anime/manga — cloud-styled image, hover effects, badges.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    this.episodeCount,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
  final int? episodeCount;
  final VoidCallback onTap;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);
    final isDesktop = factor.isDesktop;

    return MouseRegion(
      cursor: isDesktop ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CloudMotion.base,
          curve: CloudMotion.easeCloud,
          transform: _hovered && isDesktop
              ? (Matrix4.identity()
                  ..translate(0.0, -6.0)
                  ..scale(1.05))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CloudRadius.lg),
            boxShadow: _hovered && isDesktop
                ? colors.shadowHover
                : colors.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Poster image
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(CloudRadius.lg),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Image
                      CloudCachedImage(
                        url: widget.imageUrl,
                        bucket: CloudImageCacheBucket.artwork,
                        fit: BoxFit.cover,
                      ),
                      // Hover gradient overlay
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.0,
                        duration: CloudMotion.fast,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.80),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Corner badge
                      if (widget.badge != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: CloudBadge(label: widget.badge!),
                        ),
                      // Episode count badge
                      if (widget.episodeCount != null)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: _EpisodeBadge(
                            count: widget.episodeCount!,
                            colors: colors,
                          ),
                        ),
                      // Hover play button
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.0,
                        duration: CloudMotion.fast,
                        child: Center(
                          child: AnimatedScale(
                            scale: _hovered ? 1.0 : 0.7,
                            duration: CloudMotion.fast,
                            curve: CloudMotion.easeCloud,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.90),
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.40,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: colors.text,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              Padding(
                padding: EdgeInsets.all(CloudSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 10),
                      ),
                    ],
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

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.count, required this.colors});
  final int count;
  final CloudColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(CloudRadius.sm),
        border: Border.all(color: colors.surface2),
      ),
      child: Text(
        'Ep $count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }
}
