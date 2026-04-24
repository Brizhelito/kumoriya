import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'download_cover_service.dart';
import 'download_debug_logger.dart';
import 'download_identity.dart';
import '../domain/download_backend.dart';

/// Resolves the best stream for an episode and enqueues a download.
class EnqueueDownloadUseCase {
  const EnqueueDownloadUseCase({
    required DownloadBackend downloadManager,
    required ResolveSourceServerLinkUseCase resolveUseCase,
    DownloadCoverService? coverService,
  }) : _downloadManager = downloadManager,
       _resolveUseCase = resolveUseCase,
       _coverService = coverService;

  final DownloadBackend _downloadManager;
  final ResolveSourceServerLinkUseCase _resolveUseCase;
  final DownloadCoverService? _coverService;

  /// Enqueue a single episode download. Resolves the [serverLink] to get a
  /// direct stream URL, picks the best quality (or the one matching
  /// [preferredQuality]), then creates a [DownloadTask].
  Future<Result<void, KumoriyaError>> call({
    required int anilistId,
    required double episodeNumber,
    required SourceServerLink serverLink,
    String? preferredQuality,
    String? sourcePluginId,
    String? animeTitle,
    String? coverImageUrl,
    String? episodeTitle,
    DateTime? createdAt,
  }) async {
    // Persist cover image for offline display (best-effort, non-blocking).
    unawaited(_coverService?.ensureCover(anilistId, coverImageUrl));
    _log(
      'enqueue(anime=$anilistId, ep=$episodeNumber, '
      'server=${serverLink.serverName})',
    );

    final existingTask = await _downloadManager.findTaskByEpisode(
      anilistId,
      episodeNumber,
    );
    if (existingTask != null) {
      if (existingTask.status == DownloadStatus.completed &&
          existingTask.filePath != null &&
          !File(existingTask.filePath!).existsSync()) {
        await _downloadManager.syncDownloadedLibrary();
      } else {
        return const Failure(
          SimpleError(
            code: 'download.duplicate',
            message: 'This episode is already queued or downloaded.',
            kind: KumoriyaErrorKind.cancelled,
          ),
        );
      }
    }

    await dlLog.log(
      'Enqueue',
      'resolving server=${serverLink.serverName} url=${serverLink.initialUrl}',
    );
    final resolveResult = await _resolveUseCase.call(serverLink);

    // Propagate resolution failure immediately.
    if (resolveResult.isFailure) {
      return resolveResult.fold(
        onSuccess: (_) => throw StateError('unreachable'),
        onFailure: (error) {
          _log('resolve failed: ${error.message}');
          dlLog.error(
            'Enqueue',
            'resolve FAILED server=${serverLink.serverName}',
            error,
          );
          return Failure(error);
        },
      );
    }

    final resolved = resolveResult.fold(
      onSuccess: (v) => v,
      onFailure: (_) => null,
    )!;

    if (resolved.streams.isEmpty) {
      return const Failure(
        SimpleError(
          code: 'download.no_streams',
          message: 'No streams available for download.',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    final stream = _pickStream(
      resolved.streams,
      preferredQuality,
      sourcePluginId,
    );

    final taskId = buildDownloadTaskId(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    final quality = stream.qualityLabel;
    final server = serverLink.serverName;
    final ext = stream.isHls ? '.ts' : _guessExtension(stream);
    // Pretty file name: "EP 01 - StreamWish [1080p].mp4"
    final epNum = episodeNumber.toInt().toString().padLeft(2, '0');
    final qualitySuffix = quality != null ? ' [$quality]' : '';
    final fileName = 'EP $epNum - $server$qualitySuffix$ext';

    dlLog.log(
      'Enqueue',
      'resolved: url=${stream.url} isHls=${stream.isHls} '
          'quality=${stream.qualityLabel} headers=${stream.headers}',
    );

    final task = DownloadTask(
      id: taskId,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      sourceUrl: stream.url,
      status: DownloadStatus.pending,
      createdAt: createdAt ?? DateTime.now(),
      fileName: _sanitizeFileName(fileName),
      sourcePluginId: sourcePluginId,
      serverName: server,
      detectedHost: stream.url.host,
      headers: stream.headers,
      isHls: stream.isHls,
      animeTitle: animeTitle,
      qualityLabel: quality,
      episodeTitle: episodeTitle,
    );

    // Await enqueue so the task is persisted before we return success.
    // This ensures the download list updates before the caller's snackbar fires.
    await _downloadManager.enqueue(task);
    _log(
      'enqueued taskId=$taskId quality=${stream.qualityLabel} '
      'isHls=${stream.isHls} headers=${stream.headers.keys.join(",")}',
    );
    return const Success(null);
  }

  /// Picks the best stream from [streams] for download.
  ///
  /// - Respects [preferredQuality] when set.
  /// - For AnimeAV1, HLS (Zilla Networks) is the primary server — prefer it.
  /// - Otherwise prefers non-HLS (direct download) over HLS.
  ResolvedStream _pickStream(
    List<ResolvedStream> streams,
    String? preferredQuality,
    String? sourcePluginId,
  ) {
    if (preferredQuality != null) {
      final match = streams.where(
        (s) => s.qualityLabel?.toLowerCase() == preferredQuality.toLowerCase(),
      );
      if (match.isNotEmpty) {
        final s = match.first;
        _log(
          '[pick] quality match: "${s.qualityLabel}" isHls=${s.isHls} host=${s.url.host}',
        );
        return s;
      }
    }
    // AnimeAV1 distributes via Zilla Networks (HLS) — always prefer HLS.
    if (sourcePluginId == 'kumoriya.source.animeav1') {
      final hls = streams.where((s) => s.isHls).toList();
      if (hls.isNotEmpty) {
        final s = hls.first;
        _log(
          '[pick] animeav1→HLS preferred: "${s.qualityLabel}" host=${s.url.host}',
        );
        return s;
      }
    }
    // Prefer non-HLS streams for direct download, fall back to HLS.
    // Pick the HIGHEST-resolution stream — resolvers like Okru list
    // qualities ascending (144p → 2160p) and taking .first yielded 144p.
    final nonHls = streams.where((s) => !s.isHls).toList();
    if (nonHls.isNotEmpty) {
      nonHls.sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));
      final s = nonHls.first;
      _log('[pick] non-HLS direct: "${s.qualityLabel}" host=${s.url.host}');
      return s;
    }
    final s = streams.first;
    _log(
      '[pick] fallback HLS: "${s.qualityLabel}" host=${s.url.host} (no non-HLS available)',
    );
    return s;
  }

  /// Numeric rank for a [ResolvedStream] quality label — higher is better.
  /// Handles labels like "1080p", "720", "FullHD", "unknown".
  static int _qualityRank(ResolvedStream stream) {
    final label = stream.qualityLabel?.toLowerCase().trim() ?? '';
    if (label.isEmpty || label == 'unknown' || label == 'auto') return 0;
    final digits = RegExp(r'(\d{3,4})').firstMatch(label)?.group(1);
    if (digits != null) return int.tryParse(digits) ?? 0;
    // Fallback: map named tiers when the resolver didn't normalize.
    const named = <String, int>{
      'mobile': 144,
      'lowest': 240,
      'low': 360,
      'sd': 480,
      'hd': 720,
      'fullhd': 1080,
      'full': 1080,
      'quad': 1440,
      'ultra': 2160,
    };
    return named[label] ?? 0;
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
    developer.log(message, name: 'kumoriya.download.Enqueue');
    debugPrint('[kumoriya.download.Enqueue] $message');
  }

  /// Removes characters not allowed in file names on Windows/Android.
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }
}
