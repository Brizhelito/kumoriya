import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'download_directory_service.dart';

/// Persists anime cover images to the downloads directory so they survive
/// OS cache clears and remain available offline.
final class DownloadCoverService {
  DownloadCoverService({
    required DownloadDirectoryService directoryService,
    http.Client? httpClient,
  }) : _directoryService = directoryService,
       _httpClient = httpClient ?? http.Client();

  final DownloadDirectoryService _directoryService;
  final http.Client _httpClient;

  /// Ensures a cover image is persisted for [anilistId]. No-op if already
  /// saved. Safe to call concurrently — duplicate downloads are harmless.
  Future<void> ensureCover(int anilistId, String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final file = await _coverFile(anilistId);
    if (file.existsSync()) return;

    try {
      final response = await _httpClient.get(Uri.parse(imageUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      if (response.bodyBytes.isEmpty) return;

      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(response.bodyBytes, flush: true);
      await tmp.rename(file.path);
    } on Exception {
      // Best-effort — do not block downloads on cover failures.
    }
  }

  /// Returns the local cover file path if it exists, or null.
  Future<String?> getCoverPath(int anilistId) async {
    final file = await _coverFile(anilistId);
    return file.existsSync() ? file.path : null;
  }

  Future<File> _coverFile(int anilistId) async {
    final root = await _directoryService.resolveDownloadsDirectory();
    return File(p.join(root.path, 'covers', '$anilistId.jpg'));
  }
}
