import 'package:flutter/material.dart';

import 'cloud_colors.dart';
import 'cloud_gradients.dart';
import 'cloud_radius.dart';
import 'cloud_spacing.dart';
import 'cloud_typography.dart';

/// Builds a [ThemeData] from cloud tokens.
///
/// Material 3 is kept as the invisible infrastructure (Scrollable,
/// Scaffold, gestures, accessibility) but all visible components
/// are overridden with cloud aesthetics.
abstract final class CloudTheme {
  /// Builds a [ThemeData] from the given cloud palette.
  static ThemeData build(CloudColors colors) {
    final textTheme = CloudTypography.build(colors);

    final colorScheme = ColorScheme(
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: colors.isDark ? colors.bg : Colors.white,
      primaryContainer: colors.primarySoft,
      onPrimaryContainer: colors.text,
      secondary: colors.accent,
      onSecondary: colors.text,
      secondaryContainer: colors.accentSoft,
      onSecondaryContainer: colors.text,
      surface: colors.surface,
      onSurface: colors.text,
      surfaceContainerLowest: colors.bg,
      surfaceContainerLow: colors.bgElev,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surface2,
      surfaceContainerHighest: colors.mist,
      onSurfaceVariant: colors.textMuted,
      outline: colors.textSoft,
      outlineVariant: colors.surface2,
      error: colors.error,
      onError: colors.isDark ? colors.bg : Colors.white,
      errorContainer: colors.error.withValues(alpha: 0.15),
      onErrorContainer: colors.error,
      shadow: colors.isDark ? const Color(0x80000000) : const Color(0x142B3144),
      scrim: const Color(0x99000000),
      inverseSurface: colors.isDark ? colors.surface2 : colors.bg,
      onInverseSurface: colors.isDark ? colors.text : colors.bg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CloudRadius.lg),
        ),
        shadowColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CloudRadius.lg),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.text,
        unselectedItemColor: colors.textSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface2,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CloudRadius.pill),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: CloudSpacing.s3,
          vertical: CloudSpacing.s1,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.surface2,
        thickness: 1,
        space: 1,
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(colors.surface2),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: colors.surface2)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CloudRadius.pill),
          ),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: colors.textSoft, fontSize: 14),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(color: colors.text, fontSize: 14),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.primary.withValues(alpha: 0.85);
            }
            return colors.text;
          }),
          foregroundColor: WidgetStatePropertyAll(
            colors.isDark ? colors.bg : Colors.white,
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CloudRadius.pill),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: CloudSpacing.s5,
              vertical: CloudSpacing.s3,
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.textMuted),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: CloudSpacing.s4,
              vertical: CloudSpacing.s3,
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: colors.surface2)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CloudRadius.md),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.textMuted),
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: CloudSpacing.s3,
              vertical: CloudSpacing.s2,
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CloudRadius.md),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.textMuted),
          minimumSize: const WidgetStatePropertyAll(Size.square(44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: 0.1),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: colors.textMuted,
        textColor: colors.text,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surface2,
        circularTrackColor: colors.surface2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surface,
        contentTextStyle: TextStyle(color: colors.text),
        actionTextColor: colors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CloudRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface2,
        hintStyle: TextStyle(color: colors.textSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CloudRadius.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CloudRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CloudRadius.pill),
          borderSide: BorderSide(color: colors.primarySoft, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CloudRadius.sm),
          boxShadow: colors.shadowSm,
        ),
        textStyle: TextStyle(
          color: colors.text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
