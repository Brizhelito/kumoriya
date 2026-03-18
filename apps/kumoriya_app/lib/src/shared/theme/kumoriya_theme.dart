import 'package:flutter/material.dart';

abstract final class KumoriyaColors {
  static const Color background = Color(0xFF130D1A);
  static const Color surface = Color(0xFF1E1629);
  static const Color navBackground = Color(0xFF171121);
  static const Color primary = Color(0xFF7C3BED);
  static const Color primaryDark = Color(0xFF6831C9);
  static const Color primaryLight = Color(0xFF9055EB);
  static const Color primaryContainer = Color(0xFF2A1654);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF64748B);
  static const Color statusAiring = Color(0xFF34D399);
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderMedium = Color(0xFF334155);

  static Color primarySurface10 = primary.withValues(alpha: 0.10);
  static Color primarySurface20 = primary.withValues(alpha: 0.20);
  static Color primaryBorder30 = primary.withValues(alpha: 0.30);

  // Semantic status colors
  static const Color statusSuccess = Color(0xFF34D399);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFF87171);
  static const Color statusInfo = Color(0xFF60A5FA);

  // Named surface variants (replace ad-hoc alpha usage)
  static Color get surfaceDim => surface.withValues(alpha: 0.50);
  static Color get surfaceBright => surface;

  // Overlay colors
  static Color get scrimLight => Colors.black.withValues(alpha: 0.40);
  static Color get scrimHeavy => Colors.black.withValues(alpha: 0.72);
  static Color get playerControlBg => Colors.black.withValues(alpha: 0.55);
}

abstract final class KumoriyaRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 9999.0;
}

abstract final class KumoriyaSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

abstract final class KumoriyaTheme {
  static ThemeData get dark {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: KumoriyaColors.primary,
      onPrimary: KumoriyaColors.textPrimary,
      primaryContainer: KumoriyaColors.primaryContainer,
      onPrimaryContainer: KumoriyaColors.textPrimary,
      secondary: KumoriyaColors.primaryLight,
      onSecondary: KumoriyaColors.textPrimary,
      secondaryContainer: KumoriyaColors.surface,
      onSecondaryContainer: KumoriyaColors.textSecondary,
      surface: KumoriyaColors.surface,
      onSurface: KumoriyaColors.textPrimary,
      surfaceContainerLowest: Color(0xFF0D0915),
      surfaceContainerLow: KumoriyaColors.background,
      surfaceContainer: KumoriyaColors.surface,
      surfaceContainerHigh: Color(0xFF231B30),
      surfaceContainerHighest: Color(0xFF2A2035),
      onSurfaceVariant: KumoriyaColors.textMuted,
      outline: KumoriyaColors.borderMedium,
      outlineVariant: KumoriyaColors.borderSubtle,
      error: Color(0xFFCF6679),
      onError: KumoriyaColors.textPrimary,
      errorContainer: Color(0xFF4A1020),
      onErrorContainer: Color(0xFFFFB3C1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KumoriyaColors.background,
      fontFamily: 'Be Vietnam Pro',
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: KumoriyaColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: KumoriyaColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: KumoriyaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
          side: const BorderSide(color: KumoriyaColors.borderSubtle),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: KumoriyaColors.navBackground.withValues(alpha: 0.95),
        selectedItemColor: KumoriyaColors.primary,
        unselectedItemColor: KumoriyaColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: KumoriyaColors.navBackground.withValues(alpha: 0.95),
        selectedIconTheme: const IconThemeData(
          color: KumoriyaColors.primary,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: KumoriyaColors.textDisabled,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: KumoriyaColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: KumoriyaColors.textDisabled,
          fontSize: 10,
        ),
        indicatorColor: Color(0x1A7C3BED),
        elevation: 0,
        minWidth: 88,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KumoriyaColors.surface,
        side: const BorderSide(color: KumoriyaColors.borderSubtle),
        labelStyle: const TextStyle(
          color: KumoriyaColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: KumoriyaColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(KumoriyaColors.surface),
        elevation: const WidgetStatePropertyAll(0),
        overlayColor: WidgetStatePropertyAll(
          KumoriyaColors.primary.withValues(alpha: 0.08),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: KumoriyaColors.borderSubtle),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          ),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: KumoriyaColors.textDisabled, fontSize: 15),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(color: KumoriyaColors.textPrimary, fontSize: 15),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return KumoriyaColors.primaryDark;
            }
            return KumoriyaColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            KumoriyaColors.primary.withValues(alpha: 0.4),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(
            KumoriyaColors.textSecondary,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: KumoriyaColors.borderSubtle),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            KumoriyaColors.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(
            KumoriyaColors.textMuted,
          ),
          overlayColor: WidgetStatePropertyAll(
            KumoriyaColors.primary.withValues(alpha: 0.1),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: KumoriyaColors.textMuted,
        textColor: KumoriyaColors.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KumoriyaColors.primary,
        linearTrackColor: KumoriyaColors.borderSubtle,
        circularTrackColor: KumoriyaColors.borderSubtle,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KumoriyaColors.surface,
        contentTextStyle: const TextStyle(color: KumoriyaColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KumoriyaColors.surface,
        hintStyle: const TextStyle(color: KumoriyaColors.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          borderSide: const BorderSide(color: KumoriyaColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          borderSide: const BorderSide(color: KumoriyaColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          borderSide: const BorderSide(
            color: KumoriyaColors.primary,
            width: 1.5,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: KumoriyaColors.primary,
        selectionColor: KumoriyaColors.primary.withValues(alpha: 0.30),
        selectionHandleColor: KumoriyaColors.primary,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: KumoriyaColors.textPrimary,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: KumoriyaColors.textPrimary,
        height: 1.1,
      ),
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: KumoriyaColors.textPrimary,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: KumoriyaColors.textPrimary,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: KumoriyaColors.textPrimary,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: KumoriyaColors.textPrimary,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: KumoriyaColors.textPrimary,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: KumoriyaColors.textPrimary,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: KumoriyaColors.textSecondary,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: KumoriyaColors.textSecondary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: KumoriyaColors.textMuted,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: KumoriyaColors.textMuted,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: KumoriyaColors.textPrimary,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: KumoriyaColors.textMuted,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: KumoriyaColors.textDisabled,
        letterSpacing: 0.8,
      ),
    );
  }
}
