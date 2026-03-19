import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum SubtitleFontSize {
  small(32),
  medium(48),
  large(64),
  extraLarge(80);

  const SubtitleFontSize(this.pixels);
  final double pixels;
}

class SubtitleSettings {
  const SubtitleSettings({
    this.fontSize = SubtitleFontSize.medium,
    this.showBackground = true,
  });

  final SubtitleFontSize fontSize;
  final bool showBackground;

  SubtitleViewConfiguration toViewConfiguration() {
    return SubtitleViewConfiguration(
      style: TextStyle(
        fontSize: fontSize.pixels,
        color: Colors.white,
        fontWeight: FontWeight.normal,
        backgroundColor: showBackground
            ? const Color(0xAA000000)
            : Colors.transparent,
      ),
      textAlign: TextAlign.center,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize.name,
    'showBackground': showBackground,
  };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    final fontSizeName = json['fontSize'] as String?;
    final fontSize = SubtitleFontSize.values
        .where((e) => e.name == fontSizeName)
        .firstOrNull;
    return SubtitleSettings(
      fontSize: fontSize ?? SubtitleFontSize.medium,
      showBackground: json['showBackground'] as bool? ?? true,
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

  Future<void> setFontSize(SubtitleFontSize size) async {
    final current = state.value ?? const SubtitleSettings();
    final next = SubtitleSettings(
      fontSize: size,
      showBackground: current.showBackground,
    );
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> setShowBackground(bool show) async {
    final current = state.value ?? const SubtitleSettings();
    final next = SubtitleSettings(
      fontSize: current.fontSize,
      showBackground: show,
    );
    state = AsyncData(next);
    await _persist(next);
  }

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
