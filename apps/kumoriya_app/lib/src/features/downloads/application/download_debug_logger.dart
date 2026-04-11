import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

final dlLog = _DownloadDebugLogger();

final class _DownloadDebugLogger {
  Future<void> log(String category, String message) async {
    final tag = 'kumoriya.download.$category';
    developer.log(message, name: tag);
    debugPrint('[$tag] $message');
  }

  Future<void> error(
    String category,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) async {
    final tag = 'kumoriya.download.$category';
    developer.log(
      message,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    debugPrint('[$tag] ERROR $message'
        '${error != null ? '\n  error: $error' : ''}'
        '${stackTrace != null ? '\n  stack: ${stackTrace.toString().split('\n').take(5).join('\n  ')}' : ''}');
  }

  Future<void> dumpBytes(
    String category,
    String label,
    List<int> bytes, {
    int maxBytes = 128,
  }) async {
    final tag = 'kumoriya.download.$category';
    final preview = bytes.take(maxBytes).toList(growable: false);
    final hexPreview = preview
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final truncated = bytes.length > maxBytes;
    final summary = truncated
        ? '$label: $hexPreview ... (${bytes.length} bytes total)'
        : '$label: $hexPreview (${bytes.length} bytes)';

    developer.log(summary, name: tag);
    developer.log(
      '$label utf8-preview: ${utf8.decode(preview, allowMalformed: true)}',
      name: tag,
    );
    debugPrint('[$tag] $summary');
  }

  Future<void> flush() async {}
}
