import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_card.dart';
import '../primitives/cloud_badge.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Poster card for anime/manga — cloud gradient bg, hover scale + lift.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
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

    return MouseRegion(
      cursor: factor.isDesktop
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CloudMotion.base,
          curve: CloudMotion.easeCloud,
          transform: _hovered && factor.isDesktop
              ? (Matrix4.identity()
                  ..translate(0.0, -6.0)
                  ..scale(1.05))
              : Matrix4.identity(),
          child: CloudCard(
            gradient: true,
            padding: EdgeInsets.zero,
            radius: CloudRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Poster image slot
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(CloudRadius.lg),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Image placeholder
                        ColoredBox(
                          color: colors.surface2,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: colors.textSoft,
                              size: 32,
                            ),
                          ),
                        ),
                        // Badge
                        if (widget.badge != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: CloudBadge(label: widget.badge!),
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
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
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
