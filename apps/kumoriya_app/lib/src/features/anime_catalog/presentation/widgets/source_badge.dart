import 'package:flutter/material.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../application/models/source_availability.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.name,
    required this.iconUrl,
    this.audioKinds = const <SourceAudioKind>{},
    this.highlighted = false,
    this.compact = false,
    this.iconOnly = false,
  });

  final String name;
  final String? iconUrl;
  final Set<SourceAudioKind> audioKinds;
  final bool highlighted;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? KumoriyaColors.primaryContainer
        : KumoriyaColors.surface;
    final borderColor = highlighted
        ? KumoriyaColors.primary.withValues(alpha: 0.60)
        : KumoriyaColors.primary.withValues(alpha: 0.25);
    final textColor = highlighted
        ? KumoriyaColors.primaryLight
        : KumoriyaColors.primary;

    if (iconOnly) {
      return Tooltip(
        message: name,
        child: Container(
          width: compact ? 26 : 30,
          height: compact ? 26 : 30,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: _SourceIcon(name: name, iconUrl: iconUrl, size: compact ? 16 : 18),
          ),
        ),
      );
    }

    return Container(
      height: compact ? 26 : 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SourceIcon(name: name, iconUrl: iconUrl, size: compact ? 16 : 18),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
          if (audioKinds.isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            ...audioKinds.map(
              (kind) => _AudioPill(label: _audioLabel(kind), compact: compact),
            ),
          ],
        ],
      ),
    );
  }

  String _audioLabel(SourceAudioKind kind) {
    return switch (kind) {
      SourceAudioKind.sub => 'SUB',
      SourceAudioKind.dub => 'DUB',
    };
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({
    required this.name,
    required this.iconUrl,
    required this.size,
  });

  final String name;
  final String? iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        color: KumoriyaColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            color: KumoriyaColors.primary,
          ),
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: iconUrl == null || iconUrl!.trim().isEmpty
            ? fallback
            : KumoriyaCachedImage(
                url: iconUrl,
                bucket: KumoriyaImageCacheBucket.sourceIcon,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorFallback: fallback,
              ),
      ),
    );
  }
}

class _AudioPill extends StatelessWidget {
  const _AudioPill({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: KumoriyaColors.borderSubtle,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
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
