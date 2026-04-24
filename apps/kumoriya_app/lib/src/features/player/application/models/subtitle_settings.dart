import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ── Font size ─────────────────────────────────────────────────────────────
enum SubtitleFontSize {
  small(32),
  medium(48),
  large(64),
  extraLarge(80);

  const SubtitleFontSize(this.pixels);
  final double pixels;
}

// ── Font color ────────────────────────────────────────────────────────────
enum SubtitleFontColor {
  white(Color(0xFFFFFFFF)),
  yellow(Color(0xFFFFFF00)),
  green(Color(0xFF00FF00)),
  cyan(Color(0xFF00FFFF)),
  magenta(Color(0xFFFF00FF));

  const SubtitleFontColor(this.color);
  final Color color;
}

// ── Background color ──────────────────────────────────────────────────────
enum SubtitleBackgroundColor {
  black(Color(0xFF000000)),
  darkGray(Color(0xFF333333)),
  transparent(Color(0x00000000));

  const SubtitleBackgroundColor(this.color);
  final Color color;
}

// ── Edge / outline style (FCC / Netflix standard) ─────────────────────────
enum SubtitleEdgeStyle { none, outline, dropShadow, raised, depressed }

class SubtitleSettings {
  const SubtitleSettings({
    this.fontSize = SubtitleFontSize.medium,
    this.fontColor = SubtitleFontColor.white,
    this.fontOpacity = 1.0,
    this.backgroundColor = SubtitleBackgroundColor.black,
    this.backgroundOpacity = 0.67,
    this.edgeStyle = SubtitleEdgeStyle.outline,
    this.bottomPadding = 24.0,
  });

  final SubtitleFontSize fontSize;
  final SubtitleFontColor fontColor;
  final double fontOpacity; // 0.0 – 1.0
  final SubtitleBackgroundColor backgroundColor;
  final double backgroundOpacity; // 0.0 – 1.0
  final SubtitleEdgeStyle edgeStyle;
  final double bottomPadding; // 8 – 64

  SubtitleSettings copyWith({
    SubtitleFontSize? fontSize,
    SubtitleFontColor? fontColor,
    double? fontOpacity,
    SubtitleBackgroundColor? backgroundColor,
    double? backgroundOpacity,
    SubtitleEdgeStyle? edgeStyle,
    double? bottomPadding,
  }) {
    return SubtitleSettings(
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      fontOpacity: fontOpacity ?? this.fontOpacity,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      edgeStyle: edgeStyle ?? this.edgeStyle,
      bottomPadding: bottomPadding ?? this.bottomPadding,
    );
  }

  // ── Edge style → Flutter paint shadows / foreground ──────────────────
  List<Shadow> _edgeShadows() {
    return switch (edgeStyle) {
      SubtitleEdgeStyle.none => const <Shadow>[],
      SubtitleEdgeStyle.outline => const <Shadow>[
        Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
        Shadow(offset: Offset(-1, -1), blurRadius: 1, color: Colors.black),
        Shadow(offset: Offset(1, -1), blurRadius: 1, color: Colors.black),
        Shadow(offset: Offset(-1, 1), blurRadius: 1, color: Colors.black),
      ],
      SubtitleEdgeStyle.dropShadow => const <Shadow>[
        Shadow(offset: Offset(2, 2), blurRadius: 3, color: Colors.black),
      ],
      SubtitleEdgeStyle.raised => const <Shadow>[
        Shadow(offset: Offset(1, 1), blurRadius: 0, color: Colors.black54),
        Shadow(offset: Offset(2, 2), blurRadius: 2, color: Colors.black38),
      ],
      SubtitleEdgeStyle.depressed => const <Shadow>[
        Shadow(offset: Offset(-1, -1), blurRadius: 0, color: Colors.black54),
        Shadow(offset: Offset(-2, -2), blurRadius: 2, color: Colors.black38),
      ],
    };
  }

  SubtitleViewConfiguration toViewConfiguration() {
    final effectiveFontColor = fontColor.color.withValues(alpha: fontOpacity);
    final effectiveBgColor =
        backgroundColor == SubtitleBackgroundColor.transparent
        ? Colors.transparent
        : backgroundColor.color.withValues(alpha: backgroundOpacity);

    return SubtitleViewConfiguration(
      style: TextStyle(
        fontSize: fontSize.pixels,
        color: effectiveFontColor,
        fontWeight: FontWeight.normal,
        backgroundColor: effectiveBgColor,
        shadows: _edgeShadows(),
      ),
      textAlign: TextAlign.center,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
    );
  }

  /// Logical-pixel mapping for the native Kumoriya ExoPlayer overlay.
  /// The media_kit values (32/48/64/80) are video-pixel sized; the
  /// native Flutter Text widget lives in logical space and needs
  /// values tuned to typical phone widths (≈360–430 dp).
  double get _overlayFontPixels => switch (fontSize) {
    SubtitleFontSize.small => 14,
    SubtitleFontSize.medium => 18,
    SubtitleFontSize.large => 22,
    SubtitleFontSize.extraLarge => 26,
  };

  SubtitleViewConfiguration toOverlayConfiguration() {
    final effectiveFontColor = fontColor.color.withValues(alpha: fontOpacity);
    final effectiveBgColor =
        backgroundColor == SubtitleBackgroundColor.transparent
        ? Colors.transparent
        : backgroundColor.color.withValues(alpha: backgroundOpacity);
    return SubtitleViewConfiguration(
      style: TextStyle(
        fontSize: _overlayFontPixels,
        color: effectiveFontColor,
        fontWeight: FontWeight.w600,
        backgroundColor: effectiveBgColor,
        shadows: _edgeShadows(),
      ),
      textAlign: TextAlign.center,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize.name,
    'fontColor': fontColor.name,
    'fontOpacity': fontOpacity,
    'backgroundColor': backgroundColor.name,
    'backgroundOpacity': backgroundOpacity,
    'edgeStyle': edgeStyle.name,
    'bottomPadding': bottomPadding,
  };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    T? enumByName<T extends Enum>(List<T> values, String? name) {
      if (name == null) return null;
      return values.where((e) => e.name == name).firstOrNull;
    }

    // Migrate legacy showBackground → backgroundOpacity
    final legacyShowBg = json['showBackground'] as bool?;

    return SubtitleSettings(
      fontSize:
          enumByName(SubtitleFontSize.values, json['fontSize'] as String?) ??
          SubtitleFontSize.medium,
      fontColor:
          enumByName(SubtitleFontColor.values, json['fontColor'] as String?) ??
          SubtitleFontColor.white,
      fontOpacity: (json['fontOpacity'] as num?)?.toDouble() ?? 1.0,
      backgroundColor:
          enumByName(
            SubtitleBackgroundColor.values,
            json['backgroundColor'] as String?,
          ) ??
          SubtitleBackgroundColor.black,
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ??
          (legacyShowBg == false ? 0.0 : 0.67),
      edgeStyle:
          enumByName(SubtitleEdgeStyle.values, json['edgeStyle'] as String?) ??
          SubtitleEdgeStyle.outline,
      bottomPadding: (json['bottomPadding'] as num?)?.toDouble() ?? 24.0,
    );
  }
}

class SubtitleSettingsNotifier extends AsyncNotifier<SubtitleSettings> {
  @override
  Future<SubtitleSettings> build() async => _load();

  Future<SubtitleSettings> _load() async {
    final file = await _settingsFile();
    if (!await file.exists()) return const SubtitleSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return SubtitleSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const SubtitleSettings();
  }

  Future<void> _persist(SubtitleSettings settings) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  Future<void> save(SubtitleSettings Function(SubtitleSettings) updater) async {
    final current = state.value ?? const SubtitleSettings();
    final next = updater(current);
    state = AsyncData(next);
    await _persist(next);
  }

  // Kept for backward compatibility with existing settings page
  Future<void> setFontSize(SubtitleFontSize size) =>
      save((s) => s.copyWith(fontSize: size));

  static Future<File> _settingsFile() async {
    final appSupportDir = await getApplicationSupportDirectory();
    return File(
      p.join(appSupportDir.path, 'kumoriya', 'subtitle_settings.json'),
    );
  }
}

final subtitleSettingsProvider =
    AsyncNotifierProvider<SubtitleSettingsNotifier, SubtitleSettings>(
      SubtitleSettingsNotifier.new,
    );
