import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cloud_colors.dart';

/// Cloudy Cozy typography — Serif rounded (Zen Maru Gothic + M PLUS Rounded 1c)
/// with JP fallback, loaded via google_fonts for automatic caching.
///
/// Display font: Zen Maru Gothic (rounded serif, warm, JP-friendly).
/// Body font: M PLUS Rounded 1c (rounded sans, clean, JP-friendly).
/// Mono font: JetBrains Mono (technical labels, code).
abstract final class CloudTypography {
  /// Builds the [TextTheme] for the given palette.
  static TextTheme build(CloudColors colors) {
    final display = GoogleFonts.zenMaruGothic(
      color: colors.text,
      height: 1.2,
      letterSpacing: -0.3,
    );
    final body = GoogleFonts.mPlusRounded1c(
      color: colors.textMuted,
      height: 1.6,
    );

    return TextTheme(
      // Display — hero, splash, large headers.
      displayLarge: display.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      displayMedium: display.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      displaySmall: display.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),

      // Headline — page titles, dialog titles.
      headlineLarge: display.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      headlineMedium: display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      headlineSmall: display.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),

      // Title — section headers (L1/L2), card titles.
      titleLarge: display.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      titleMedium: display.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),
      titleSmall: display.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),

      // Body — paragraphs, descriptions.
      bodyLarge: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
      ),
      bodyMedium: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
      ),
      bodySmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSoft,
      ),

      // Label — buttons, chips, badges, captions.
      labelLarge: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      labelMedium: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),
      labelSmall: body.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: colors.textSoft,
      ),
    );
  }

  /// Mono font for technical labels, section tags, code.
  static TextStyle mono({Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      color: color,
    );
  }
}
