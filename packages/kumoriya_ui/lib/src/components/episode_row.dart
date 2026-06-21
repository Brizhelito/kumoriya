import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_progress.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Unified episode row with all state variants.
///
/// States: default, active, watched, notPlayable, downloading, downloaded.
class EpisodeRow extends StatefulWidget {
  const EpisodeRow({
    super.key,
    required this.episodeNumber,
    required this.title,
    this.subtitle,
    this.state = EpisodeRowState.defaultState,
    this.progress,
    this.onTap,
    this.sourceLabels = const <String>[],
  });

  final String episodeNumber;
  final String title;
  final String? subtitle;
  final EpisodeRowState state;
  final double? progress;
  final VoidCallback? onTap;
  final List<String> sourceLabels;

  @override
  State<EpisodeRow> createState() => _EpisodeRowState();
}

enum EpisodeRowState {
  defaultState,
  active,
  watched,
  notPlayable,
  downloading,
  downloaded,
}

class _EpisodeRowState extends State<EpisodeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);
    final isActive = widget.state == EpisodeRowState.active;
    final isNotPlayable = widget.state == EpisodeRowState.notPlayable;

    final bgColor = _resolveBg(colors, isActive);
    final borderColor = _resolveBorder(colors, isActive);

    return Opacity(
      opacity: isNotPlayable ? 0.45 : 1.0,
      child: MouseRegion(
        cursor: factor.isDesktop && widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: CloudMotion.fast,
            curve: CloudMotion.easeCloud,
            decoration: BoxDecoration(
              color: _hovered && factor.isDesktop ? colors.surface : bgColor,
              borderRadius: BorderRadius.circular(CloudRadius.lg),
              border: Border.all(
                color: _hovered && factor.isDesktop ? colors.mist : borderColor,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: CloudSpacing.s3,
            ),
            child: Row(
              children: <Widget>[
                // Episode number box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive ? colors.primarySoft : colors.surface2,
                    borderRadius: BorderRadius.circular(CloudRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.episodeNumber,
                    style: TextStyle(
                      color: isActive ? colors.text : colors.textMuted,
                      fontSize: isActive ? 15 : 14,
                      fontWeight: FontWeight.w800,
                    ),
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
                          color: isActive ? colors.text : colors.textMuted,
                          fontSize: 14,
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
                            color: colors.textSoft,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (widget.progress != null) ...[
                        SizedBox(height: CloudSpacing.s2),
                        CloudProgress(value: widget.progress!),
                      ],
                    ],
                  ),
                ),
                // Trailing icons
                if (widget.state == EpisodeRowState.watched)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: colors.success,
                  )
                else if (widget.state == EpisodeRowState.downloaded)
                  Icon(
                    Icons.download_done_rounded,
                    size: 14,
                    color: colors.success,
                  )
                else if (!isNotPlayable)
                  AnimatedOpacity(
                    duration: CloudMotion.fast,
                    opacity: _hovered || isActive ? 1.0 : 0.0,
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 28,
                      color: isActive ? colors.primary : colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _resolveBg(CloudColors colors, bool isActive) {
    if (isActive) return colors.primary.withValues(alpha: 0.2);
    return colors.surface.withValues(alpha: 0.5);
  }

  Color _resolveBorder(CloudColors colors, bool isActive) {
    if (isActive) return colors.primary.withValues(alpha: 0.3);
    return colors.surface2;
  }
}
