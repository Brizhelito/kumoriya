import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SeenAppVersionStore {
  const SeenAppVersionStore();

  static const String _fileName = 'last_seen_app_version.txt';

  Future<String?> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String version) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(version, flush: true);
  }

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
