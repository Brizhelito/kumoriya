import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the user's last-selected media universe (`anime` / `manga`)
/// across app restarts.
///
/// File-based, mirroring `SeenAppVersionStore`: a single text file in
/// the application support directory storing the [MediaKind.wireValue].
/// Best-effort — read failures and unknown values fall back to the
/// caller-provided default.
class ActiveUniverseStore {
  /// Creates a store that resolves the file under the platform's
  /// application support directory.
  const ActiveUniverseStore() : _resolveDirectory = _defaultResolveDirectory;

  /// Test-only constructor that injects a directory resolver, avoiding
  /// any dependency on `path_provider` plumbing in tests.
  const ActiveUniverseStore.forTesting({
    required Future<Directory> Function() resolveDirectory,
  }) : _resolveDirectory = resolveDirectory;

  final Future<Directory> Function() _resolveDirectory;

  static const String _fileName = 'active_universe.txt';

  static Future<Directory> _defaultResolveDirectory() {
    return getApplicationSupportDirectory();
  }

  Future<MediaKind?> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      final value = (await file.readAsString()).trim();
      if (value.isEmpty) return null;
      return MediaKind.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(MediaKind kind) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(kind.wireValue, flush: true);
  }

  Future<File> _resolveFile() async {
    final directory = await _resolveDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
