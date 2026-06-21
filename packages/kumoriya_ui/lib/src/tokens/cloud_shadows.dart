import 'package:flutter/painting.dart';

import 'cloud_colors.dart';

/// Helper to build a `BoxDecoration` with cloud shadows.
///
/// Usage:
/// ```dart
/// BoxDecoration(
///   color: colors.surface,
///   borderRadius: BorderRadius.circular(CloudRadius.lg),
///   boxShadow: CloudShadows.of(colors).sm,
/// )
/// ```
class CloudShadows {
  const CloudShadows({
    required this.sm,
    required this.base,
    required this.lg,
    required this.hover,
  });

  factory CloudShadows.of(CloudColors colors) {
    return CloudShadows(
      sm: colors.shadowSm,
      base: colors.shadow,
      lg: colors.shadowLg,
      hover: colors.shadowHover,
    );
  }

  /// Small — resting cards, chips, compact surfaces.
  final List<BoxShadow> sm;

  /// Base — default elevation for most interactive surfaces.
  final List<BoxShadow> base;

  /// Large — prominent cards, dialogs, modals.
  final List<BoxShadow> lg;

  /// Hover — elevated state for desktop hover interactions.
  final List<BoxShadow> hover;
}
