import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_cached_image.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Ranked list tile for top anime lists — rank number, cover, info, chevron.
class RankedTile extends StatefulWidget {
  const RankedTile({
    super.key,
    required this.rank,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.score,
    required this.onTap,
  });

  final String rank;
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final String? score;
  final VoidCallback onTap;

  @override
  State<RankedTile> createState() => _RankedTileState();
}

class _RankedTileState extends State<RankedTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);
    final isDesktop = factor.isDesktop;

    return Padding(
      padding: EdgeInsets.only(bottom: CloudSpacing.s2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: CloudMotion.fast,
            curve: CloudMotion.easeCloud,
            padding: EdgeInsets.all(CloudSpacing.s3),
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.surface
                  : colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(CloudRadius.lg),
              border: Border.all(
                color: _hovered ? colors.mist : colors.surface2,
              ),
            ),
            child: Row(
              children: <Widget>[
                // Rank number
                SizedBox(
                  width: 32,
                  child: Text(
                    widget.rank,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.primary.withValues(alpha: 0.50),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SizedBox(width: CloudSpacing.s3),
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(CloudRadius.md),
                  child: CloudCachedImage(
                    url: widget.imageUrl,
                    bucket: CloudImageCacheBucket.artwork,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: CloudSpacing.s3),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.subtitle != null || widget.score != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            if (widget.subtitle != null && widget.score != null)
                              SizedBox(width: 4),
                            if (widget.score != null)
                              Text(
                                widget.score!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.warning,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: CloudSpacing.s2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
