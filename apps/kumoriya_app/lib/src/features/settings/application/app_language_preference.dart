import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// User's app-language choice.
///
/// `system` means: do not pin a locale; let `MaterialApp` resolve it
/// from the device. The other variants force the matching `Locale`.
enum AppLanguagePreference {
  system,
  english,
  spanish;

  /// Maps the preference to a concrete [Locale] for `MaterialApp.locale`.
  /// Returns `null` for [AppLanguagePreference.system] so Flutter falls
  /// back to the device locale (resolved against `supportedLocales`).
  Locale? toLocale() => switch (this) {
    AppLanguagePreference.system => null,
    AppLanguagePreference.english => const Locale('en'),
    AppLanguagePreference.spanish => const Locale('es'),
  };

  static AppLanguagePreference fromName(String? name) {
    return AppLanguagePreference.values
            .where((e) => e.name == name)
            .firstOrNull ??
        AppLanguagePreference.system;
  }
}

/// Persists the language preference as JSON in the app-support dir,
/// mirroring the storage pattern used by `SubtitleSettingsNotifier`.
class AppLanguageNotifier extends AsyncNotifier<AppLanguagePreference> {
  @override
  Future<AppLanguagePreference> build() async => _load();

  Future<AppLanguagePreference> _load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return AppLanguagePreference.system;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return AppLanguagePreference.fromName(decoded['preference'] as String?);
      }
    } catch (_) {
      // Corrupt or unreadable file → silently fall back to system.
    }
    return AppLanguagePreference.system;
  }

  Future<void> _persist(AppLanguagePreference preference) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, dynamic>{'preference': preference.name}),
      flush: true,
    );
  }

  Future<void> setPreference(AppLanguagePreference preference) async {
    state = AsyncData(preference);
    await _persist(preference);
  }

  static Future<File> _settingsFile() async {
    final appSupportDir = await getApplicationSupportDirectory();
    return File(p.join(appSupportDir.path, 'kumoriya', 'app_language.json'));
  }
}

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageNotifier, AppLanguagePreference>(
      AppLanguageNotifier.new,
    );
