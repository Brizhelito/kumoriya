import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_cached_image.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Source badge pill — shows plugin source name with optional audio kind.
class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.sourceName,
    this.isHighlighted = false,
    this.compact = false,
    this.iconUrl,
    this.audioKinds = const <SourceAudioKind>{},
    this.iconOnly = false,
  });

  final String sourceName;
  final bool isHighlighted;
  final bool compact;
  final String? iconUrl;
  final Set<SourceAudioKind> audioKinds;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);

    if (iconOnly) {
      return Tooltip(
        message: sourceName,
        child: Container(
          width: compact ? 26 : 30,
          height: compact ? 26 : 30,
          decoration: BoxDecoration(
            color: isHighlighted ? colors.primarySoft : colors.surface,
            borderRadius: BorderRadius.circular(CloudRadius.pill),
            border: Border.all(
              color: isHighlighted
                  ? colors.primary.withValues(alpha: 0.6)
                  : colors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Center(child: _iconOrFallback(colors, compact ? 14 : 16)),
        ),
      );
    }

    final hasIcon = iconUrl != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: compact ? 26 : 30,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: isHighlighted ? colors.primarySoft : colors.surface,
            borderRadius: BorderRadius.circular(CloudRadius.pill),
            border: Border.all(
              color: isHighlighted
                  ? colors.primary.withValues(alpha: 0.6)
                  : colors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasIcon) ...[
                  _iconOrFallback(colors, 12),
                  SizedBox(width: 4),
                ],
                Text(
                  sourceName,
                  style: TextStyle(
                    color: isHighlighted ? colors.primary : colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (audioKinds.isNotEmpty) ...[
          SizedBox(width: CloudSpacing.s1),
          ...audioKinds.map(
            (kind) => Padding(
              padding: EdgeInsets.only(right: CloudSpacing.s1),
              child: _audioPill(colors, kind),
            ),
          ),
        ],
      ],
    );
  }

  Widget _iconOrFallback(CloudColors colors, double size) {
    if (iconUrl != null) {
      return ClipOval(
        child: CloudCachedImage(
          url: iconUrl,
          bucket: CloudImageCacheBucket.sourceIcon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorFallback: _initialsWidget(colors, size),
        ),
      );
    }
    return _initialsWidget(colors, size);
  }

  Widget _initialsWidget(CloudColors colors, double size) {
    final initials = sourceName.isNotEmpty
        ? sourceName.substring(0, 1).toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: colors.textSoft,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _audioPill(CloudColors colors, SourceAudioKind kind) {
    final label = kind == SourceAudioKind.sub ? 'SUB' : 'DUB';
    return Container(
      height: 18,
      padding: EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: colors.textSoft,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
