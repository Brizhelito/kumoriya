import 'package:flutter/material.dart';

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
  });

  final String name;
  final String? iconUrl;
  final Set<SourceAudioKind> audioKinds;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = highlighted
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final borderColor = highlighted
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SourceIcon(name: name, iconUrl: iconUrl),
          const SizedBox(width: 8),
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (audioKinds.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: audioKinds
                  .map((kind) => _VariantPill(label: _audioLabel(kind)))
                  .toList(growable: false),
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
  const _SourceIcon({required this.name, required this.iconUrl});

  final String name;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: 24,
        height: 24,
        child: iconUrl == null || iconUrl!.trim().isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : KumoriyaCachedImage(
                url: iconUrl,
                bucket: KumoriyaImageCacheBucket.sourceIcon,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorFallback: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _VariantPill extends StatelessWidget {
  const _VariantPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
