import 'dart:developer' as developer;

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'download_manager_service.dart';

/// Resolves the best stream for an episode and enqueues a download.
class EnqueueDownloadUseCase {
  const EnqueueDownloadUseCase({
    required DownloadManagerService downloadManager,
    required ResolveSourceServerLinkUseCase resolveUseCase,
  }) : _downloadManager = downloadManager,
       _resolveUseCase = resolveUseCase;

  final DownloadManagerService _downloadManager;
  final ResolveSourceServerLinkUseCase _resolveUseCase;

  /// Enqueue a single episode download. Resolves the [serverLink] to get a
  /// direct stream URL, picks the best quality (or the one matching
  /// [preferredQuality]), then creates a [DownloadTask].
  Future<Result<void, KumoriyaError>> call({
    required int anilistId,
    required double episodeNumber,
    required SourceServerLink serverLink,
    String? preferredQuality,
    String? sourcePluginId,
  }) async {
    _log(
      'enqueue(anime=$anilistId, ep=$episodeNumber, '
      'server=${serverLink.serverName})',
    );

    final resolveResult = await _resolveUseCase.call(serverLink);
    return resolveResult.fold(
      onFailure: (error) {
        _log('resolve failed: ${error.message}');
        return Failure(error);
      },
      onSuccess: (resolved) {
        if (resolved.streams.isEmpty) {
          return const Failure(
            SimpleError(
              code: 'download.no_streams',
              message: 'No streams available for download.',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }

        final stream = _pickStream(resolved.streams, preferredQuality);

        final taskId =
            '${anilistId}_${episodeNumber}_${DateTime.now().millisecondsSinceEpoch}';
        final ext = stream.isHls ? '.ts' : _guessExtension(stream);
        final fileName = '${anilistId}_ep${episodeNumber.toInt()}$ext';

        final task = DownloadTask(
          id: taskId,
          anilistId: anilistId,
          episodeNumber: episodeNumber,
          sourceUrl: stream.url,
          status: DownloadStatus.pending,
          createdAt: DateTime.now(),
          fileName: fileName,
          sourcePluginId: sourcePluginId,
          serverName: serverLink.serverName,
          detectedHost: stream.url.host,
          headers: stream.headers,
          isHls: stream.isHls,
        );

        _downloadManager.enqueue(task);
        _log(
          'enqueued taskId=$taskId quality=${stream.qualityLabel} '
          'isHls=${stream.isHls} headers=${stream.headers.keys.join(",")}',
        );
        return const Success(null);
      },
    );
  }

  ResolvedStream _pickStream(List<ResolvedStream> streams, String? preferred) {
    if (preferred != null) {
      final match = streams.where(
        (s) => s.qualityLabel?.toLowerCase() == preferred.toLowerCase(),
      );
      if (match.isNotEmpty) return match.first;
    }
    // Prefer non-HLS streams for direct download, fall back to HLS.
    final nonHls = streams.where((s) => !s.isHls).toList();
    if (nonHls.isNotEmpty) return nonHls.first;
    return streams.first;
  }

  String _guessExtension(ResolvedStream stream) {
    if (stream.mimeType?.contains('mp4') == true) return '.mp4';
    if (stream.mimeType?.contains('webm') == true) return '.webm';
    final path = stream.url.path.toLowerCase();
    if (path.endsWith('.mp4')) return '.mp4';
    if (path.endsWith('.webm')) return '.webm';
    if (path.endsWith('.mkv')) return '.mkv';
    return '.mp4';
  }

  void _log(String message) {
    developer.log(message, name: 'EnqueueDownloadUseCase');
  }
}
