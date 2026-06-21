import 'package:flutter/painting.dart';

import 'cloud_colors.dart';

/// Cloudy Cozy gradient tokens.
///
/// Gradients define the atmospheric backgrounds and card surfaces.
class CloudGradients {
  const CloudGradients._();

  /// Grad-cloud — the primary card surface gradient.
  /// Subtle vertical fade from elevated bg to surface2.
  static LinearGradient cloud(CloudColors colors) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[colors.bgElev, colors.bg, colors.surface2],
      stops: const <double>[0.0, 0.5, 1.0],
    );
  }

  /// Grad-sky — anime universe background gradient.
  /// Deep sky fading into the base background.
  static LinearGradient sky(CloudColors colors) {
    if (colors.isDark) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[colors.surface, colors.bg, const Color(0xFF15152F)],
        stops: const <double>[0.0, 0.6, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        const Color(0xFFDDE5EF),
        const Color(0xFFE8EBF0),
        colors.bg,
      ],
      stops: const <double>[0.0, 0.6, 1.0],
    );
  }

  /// Was overlay — manga universe paper texture overlay.
  /// Warm sepia gradient with subtle transparency.
  static LinearGradient washi() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[const Color(0xFFF0E8D8), const Color(0xFFE8DFCB)],
    );
  }

  /// Scrim — background overlay behind bottom sheets and dialogs.
  static LinearGradient scrim() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[const Color(0x00000000), const Color(0x99000000)],
    );
  }
}
