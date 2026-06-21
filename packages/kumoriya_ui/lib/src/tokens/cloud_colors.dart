import 'package:flutter/painting.dart';

/// Nublado (cloudy day) — light, default palette.
///
/// Warm cream backgrounds, soft blue primary, coral accent.
/// Shadows use `rgba(43,49,68, 0.0X)` for diffuse cloud feel.
abstract final class NubladoPalette {
  // Surfaces
  static const Color bg = Color(0xFFF4F1EC);
  static const Color bgElev = Color(0xFFFBF9F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEDE9E2);
  static const Color mist = Color(0xFFE8EBF0);

  // Text
  static const Color text = Color(0xFF2B3144);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textSoft = Color(0xFF9AA0AE);

  // Brand
  static const Color primary = Color(0xFF5B7BB5);
  static const Color primarySoft = Color(0xFFA8B8D4);
  static const Color accent = Color(0xFFE8A598);
  static const Color accentSoft = Color(0xFFF5CFC6);

  // Semantic
  static const Color success = Color(0xFF7FB069);
  static const Color warning = Color(0xFFE6B450);
  static const Color error = Color(0xFFD97B7B);
  static const Color star = Color(0xFFF0C667);

  // Cloud shadows (3-layer diffuse)
  static const List<BoxShadow> shadowSm = <BoxShadow>[
    BoxShadow(color: Color(0x0A2B3144), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F2B3144), offset: Offset(0, 2), blurRadius: 8),
    BoxShadow(color: Color(0x0D2B3144), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(color: Color(0x0D2B3144), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x122B3144), offset: Offset(0, 8), blurRadius: 16),
    BoxShadow(color: Color(0x0F2B3144), offset: Offset(0, 16), blurRadius: 48),
  ];

  static const List<BoxShadow> shadowLg = <BoxShadow>[
    BoxShadow(color: Color(0x0F2B3144), offset: Offset(0, 4), blurRadius: 8),
    BoxShadow(color: Color(0x142B3144), offset: Offset(0, 16), blurRadius: 32),
    BoxShadow(color: Color(0x142B3144), offset: Offset(0, 32), blurRadius: 80),
  ];

  static const List<BoxShadow> shadowHover = <BoxShadow>[
    BoxShadow(color: Color(0x142B3144), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x1A2B3144), offset: Offset(0, 16), blurRadius: 36),
    BoxShadow(color: Color(0x1A2B3144), offset: Offset(0, 32), blurRadius: 80),
  ];
}

/// Noche (starry night) — dark palette.
///
/// Deep navy backgrounds, soft blue primary, golden accent.
/// Shadows use heavier `rgba(0,0,0, 0.3-0.6)` alphas.
abstract final class NochePalette {
  // Surfaces
  static const Color bg = Color(0xFF1B1B3A);
  static const Color bgElev = Color(0xFF232352);
  static const Color surface = Color(0xFF2A2A5A);
  static const Color surface2 = Color(0xFF343468);
  static const Color mist = Color(0xFF3D3D78);

  // Text
  static const Color text = Color(0xFFE8E6F5);
  static const Color textMuted = Color(0xFFB8B5D4);
  static const Color textSoft = Color(0xFF8A87B0);

  // Brand
  static const Color primary = Color(0xFF8A9DD9);
  static const Color primarySoft = Color(0xFF5E6BA8);
  static const Color accent = Color(0xFFE8C668);
  static const Color accentSoft = Color(0xFFC9A855);

  // Semantic
  static const Color success = Color(0xFF8FBD7D);
  static const Color warning = Color(0xFFE8C668);
  static const Color error = Color(0xFFE08A8A);
  static const Color star = Color(0xFFFFE9A8);

  // Cloud shadows (3-layer diffuse, heavier for dark)
  static const List<BoxShadow> shadowSm = <BoxShadow>[
    BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8),
    BoxShadow(color: Color(0x4D000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 8), blurRadius: 16),
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 16), blurRadius: 48),
  ];

  static const List<BoxShadow> shadowLg = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 8),
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 16), blurRadius: 32),
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 32), blurRadius: 80),
  ];

  static const List<BoxShadow> shadowHover = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 16), blurRadius: 36),
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 32), blurRadius: 80),
  ];
}

/// Semantic access to the active palette.
///
/// Components should read `CloudColors.of(context)` via `CloudTheme`
/// rather than referencing palette classes directly.
class CloudColors {
  const CloudColors({
    required this.bg,
    required this.bgElev,
    required this.surface,
    required this.surface2,
    required this.mist,
    required this.text,
    required this.textMuted,
    required this.textSoft,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.error,
    required this.star,
    required this.shadowSm,
    required this.shadow,
    required this.shadowLg,
    required this.shadowHover,
    required this.isDark,
  });

  factory CloudColors.nublado() => CloudColors(
    bg: NubladoPalette.bg,
    bgElev: NubladoPalette.bgElev,
    surface: NubladoPalette.surface,
    surface2: NubladoPalette.surface2,
    mist: NubladoPalette.mist,
    text: NubladoPalette.text,
    textMuted: NubladoPalette.textMuted,
    textSoft: NubladoPalette.textSoft,
    primary: NubladoPalette.primary,
    primarySoft: NubladoPalette.primarySoft,
    accent: NubladoPalette.accent,
    accentSoft: NubladoPalette.accentSoft,
    success: NubladoPalette.success,
    warning: NubladoPalette.warning,
    error: NubladoPalette.error,
    star: NubladoPalette.star,
    shadowSm: NubladoPalette.shadowSm,
    shadow: NubladoPalette.shadow,
    shadowLg: NubladoPalette.shadowLg,
    shadowHover: NubladoPalette.shadowHover,
    isDark: false,
  );

  factory CloudColors.noche() => CloudColors(
    bg: NochePalette.bg,
    bgElev: NochePalette.bgElev,
    surface: NochePalette.surface,
    surface2: NochePalette.surface2,
    mist: NochePalette.mist,
    text: NochePalette.text,
    textMuted: NochePalette.textMuted,
    textSoft: NochePalette.textSoft,
    primary: NochePalette.primary,
    primarySoft: NochePalette.primarySoft,
    accent: NochePalette.accent,
    accentSoft: NochePalette.accentSoft,
    success: NochePalette.success,
    warning: NochePalette.warning,
    error: NochePalette.error,
    star: NochePalette.star,
    shadowSm: NochePalette.shadowSm,
    shadow: NochePalette.shadow,
    shadowLg: NochePalette.shadowLg,
    shadowHover: NochePalette.shadowHover,
    isDark: true,
  );

  final Color bg;
  final Color bgElev;
  final Color surface;
  final Color surface2;
  final Color mist;
  final Color text;
  final Color textMuted;
  final Color textSoft;
  final Color primary;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color error;
  final Color star;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowLg;
  final List<BoxShadow> shadowHover;
  final bool isDark;
}
