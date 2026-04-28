import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists whether finished HLS downloads should be remuxed to MP4.
///
/// When `true` (default), the native pipeline transmuxes the concatenated
/// `.ts` into a universal `.mp4` via Media3's Transformer — slower but
/// compatible with every player.
///
/// When `false`, the `.ts` is kept as the final artifact — instant, but
/// some players (Android default gallery, iOS Photos) won't open it.
class HlsRemuxModeStore {
  HlsRemuxModeStore({Future<File> Function()? fileProvider})
    : _fileProvider = fileProvider ?? _defaultFile;

  final Future<File> Function() _fileProvider;

  Future<bool> read() async {
    try {
      final file = await _fileProvider();
      if (!file.existsSync()) return true; // default ON
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return true;
      return json['remux_to_mp4'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> write(bool enabled) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'remux_to_mp4': enabled}),
      flush: true,
    );
  }

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'kumoriya', 'hls_remux_settings.json'));
  }
}

class HlsRemuxModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.watch(hlsRemuxModeStoreProvider).read();
  }

  Future<void> setEnabled(bool enabled) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(hlsRemuxModeStoreProvider).write(enabled);
      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final hlsRemuxModeStoreProvider = Provider<HlsRemuxModeStore>((ref) {
  return HlsRemuxModeStore();
});

final hlsRemuxModeNotifierProvider =
    AsyncNotifierProvider<HlsRemuxModeNotifier, bool>(HlsRemuxModeNotifier.new);
