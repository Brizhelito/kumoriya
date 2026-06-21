import 'package:flutter/material.dart';

import 'cloud_colors.dart';

/// Cloudy Cozy typography — Cozy (Fredoka + Quicksand) with JP fallback.
///
/// Display font: Fredoka (rounded, geometric, friendly).
/// Body font: Quicksand (rounded, geometric, clean).
/// JP fallback: Zen Maru Gothic (display) + M PLUS Rounded 1c (body).
abstract final class CloudTypography {
  /// Builds the [TextTheme] for the given palette.
  static TextTheme build(CloudColors colors) {
    return TextTheme(
      // Display — hero, splash, large headers.
      displayLarge: _display(48, FontWeight.w700, colors.text),
      displayMedium: _display(40, FontWeight.w700, colors.text),
      displaySmall: _display(32, FontWeight.w600, colors.text),

      // Headline — page titles, dialog titles.
      headlineLarge: _display(28, FontWeight.w700, colors.text),
      headlineMedium: _display(24, FontWeight.w700, colors.text),
      headlineSmall: _display(20, FontWeight.w600, colors.text),

      // Title — section headers (L1/L2), card titles.
      titleLarge: _display(18, FontWeight.w700, colors.text),
      titleMedium: _display(15, FontWeight.w600, colors.text),
      titleSmall: _display(14, FontWeight.w600, colors.textMuted),

      // Body — paragraphs, descriptions.
      bodyLarge: _body(16, FontWeight.w500, colors.textMuted),
      bodyMedium: _body(14, FontWeight.w500, colors.textMuted),
      bodySmall: _body(12, FontWeight.w500, colors.textSoft),

      // Label — buttons, chips, badges, captions.
      labelLarge: _body(14, FontWeight.w700, colors.text),
      labelMedium: _body(12, FontWeight.w600, colors.textMuted),
      labelSmall: _body(10, FontWeight.w600, colors.textSoft),
    );
  }

  static TextStyle _display(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: 'Fredoka',
      fontFamilyFallback: const <String>[
        'Zen Maru Gothic',
        'M PLUS Rounded 1c',
        'Nunito',
        'sans-serif',
      ],
      fontWeight: weight,
      fontSize: size,
      height: 1.2,
      letterSpacing: -0.01 * size,
      color: color,
    );
  }

  static TextStyle _body(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: 'Quicksand',
      fontFamilyFallback: const <String>[
        'M PLUS Rounded 1c',
        'Nunito',
        'sans-serif',
      ],
      fontWeight: weight,
      fontSize: size,
      height: 1.6,
      color: color,
    );
  }

  /// Mono font for technical labels, section tags, code.
  static const TextStyle mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );
}
