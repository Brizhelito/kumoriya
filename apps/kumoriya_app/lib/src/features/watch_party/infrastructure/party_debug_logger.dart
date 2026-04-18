import 'dart:io';
import 'dart:developer' as dev;

/// Shared debug logger for Watch Party — writes to both console and a local
/// file so logs can be inspected after a cross-device test session.
final class PartyDebugLogger {
  PartyDebugLogger._();

  static const bool enabled = bool.fromEnvironment(
    'WATCH_PARTY_DEBUG_LOGS',
    defaultValue: false,
  );

  static File? _logFile;
  static bool _initialized = false;

  static void _log(String msg) => dev.log(msg, name: 'PartyDebug');

  /// Call this once at app startup or before a party session.
  static Future<void> initialize() async {
    if (!enabled) return;
    if (_initialized) return;
    try {
      final dir = Directory.systemTemp;
      _logFile = File('${dir.path}/kumoriya_party_debug.log');
      // Truncate on each session.
      await _logFile!.writeAsString(
        '=== Kumoriya Party Debug Session ${DateTime.now().toIso8601String()} ===\n',
      );
      _initialized = true;
      _log('Logger initialized at ${_logFile!.path}');
    } catch (e) {
      dev.log('PartyDebugLogger: failed to init file logger: $e');
    }
  }

  static void log(String tag, String msg) {
    if (!enabled) return;
    final line = '[${DateTime.now().toIso8601String()}] [$tag] $msg';
    dev.log(line, name: 'Party');
    final f = _logFile;
    if (f != null) {
      f
          .writeAsString('$line\n', mode: FileMode.append)
          .catchError((Object _) => f);
    }
  }

  static String get logPath => _logFile?.path ?? '(not initialized)';

  static Future<String> readAll() async {
    final f = _logFile;
    if (f == null || !f.existsSync()) return '(no log file)';
    return f.readAsString();
  }
}
