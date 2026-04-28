import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../presentation/download_providers.dart';

/// Persists the WiFi-only mode preference in a JSON file under the
/// application support directory.
class WifiOnlyModeStore {
  WifiOnlyModeStore({Future<File> Function()? fileProvider})
    : _fileProvider = fileProvider ?? _defaultFile;

  final Future<File> Function() _fileProvider;

  Future<bool> read() async {
    try {
      final file = await _fileProvider();
      if (!file.existsSync()) return false;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return false;
      return json['wifi_only_mode'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> write(bool enabled) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'wifi_only_mode': enabled}),
      flush: true,
    );
  }

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'kumoriya', 'wifi_only_settings.json'));
  }
}

/// Manages WiFi-only mode setting for downloads.
///
/// When enabled, downloads will only proceed on WiFi networks.
/// On mobile data, downloads are automatically paused and resumed when WiFi is restored.
class WifiOnlyModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.watch(wifiOnlyModeStoreProvider);
    final enabled = await store.read();

    // Apply the saved setting to the download backend on startup.
    if (enabled) {
      await ref.read(downloadManagerProvider).setWifiOnly(enabled);
    }

    return enabled;
  }

  /// Enable or disable WiFi-only mode for downloads.
  Future<void> setEnabled(bool enabled) async {
    state = const AsyncValue.loading();

    try {
      // Save to file
      final store = ref.read(wifiOnlyModeStoreProvider);
      await store.write(enabled);

      // Apply to download backend.
      await ref.read(downloadManagerProvider).setWifiOnly(enabled);

      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for WiFi-only mode store.
final wifiOnlyModeStoreProvider = Provider<WifiOnlyModeStore>((ref) {
  return WifiOnlyModeStore();
});

/// Provider for WiFi-only mode setting.
final wifiOnlyModeNotifierProvider =
    AsyncNotifierProvider<WifiOnlyModeNotifier, bool>(WifiOnlyModeNotifier.new);
