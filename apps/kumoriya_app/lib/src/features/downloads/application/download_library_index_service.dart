import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import 'download_directory_service.dart';
import 'download_identity.dart';

const downloadSidecarSuffix = '.kumoriya.json';

final class DownloadLibrarySyncReport {
  const DownloadLibrarySyncReport({
    this.scannedManifestCount = 0,
    this.importedCount = 0,
    this.updatedCount = 0,
    this.removedMissingCount = 0,
  });

  final int scannedManifestCount;
  final int importedCount;
  final int updatedCount;
  final int removedMissingCount;

  bool get changed =>
      importedCount > 0 || updatedCount > 0 || removedMissingCount > 0;

  DownloadLibrarySyncReport copyWith({
    int? scannedManifestCount,
    int? importedCount,
    int? updatedCount,
    int? removedMissingCount,
  }) {
    return DownloadLibrarySyncReport(
      scannedManifestCount: scannedManifestCount ?? this.scannedManifestCount,
      importedCount: importedCount ?? this.importedCount,
      updatedCount: updatedCount ?? this.updatedCount,
      removedMissingCount: removedMissingCount ?? this.removedMissingCount,
    );
  }
}

final class DownloadLibraryIndexService {
  DownloadLibraryIndexService({
    required DownloadStore store,
    required DownloadDirectoryService directoryService,
  }) : _store = store,
       _directoryService = directoryService;

  final DownloadStore _store;
  final DownloadDirectoryService _directoryService;

  Future<DownloadLibrarySyncReport> syncCurrentLibrary() async {
    final root = await _directoryService.resolveDownloadsDirectory();
    return syncDirectory(root);
  }

  Future<DownloadLibrarySyncReport> syncDirectory(Directory root) async {
    final allTasksResult = await _store.getAllTasks();
    final allTasks = allTasksResult.fold(
      onSuccess: (tasks) => tasks,
      onFailure: (_) => <DownloadTask>[],
    );

    var report = const DownloadLibrarySyncReport();
    final tasksById = <String, DownloadTask>{
      for (final task in allTasks) task.id: task,
    };

    for (final task in allTasks) {
      if (task.status != DownloadStatus.completed || task.filePath == null) {
        continue;
      }

      final mediaFile = File(task.filePath!);
      if (!await mediaFile.exists()) {
        await _store.deleteTask(task.id);
        tasksById.remove(task.id);
        report = report.copyWith(
          removedMissingCount: report.removedMissingCount + 1,
        );
        continue;
      }

      final actualSize = await mediaFile.length();
      if (task.totalBytes != actualSize || task.downloadedBytes != actualSize) {
        final updated = _copyTask(
          task,
          totalBytes: actualSize,
          downloadedBytes: actualSize,
        );
        await _store.updateTask(updated);
        tasksById[updated.id] = updated;
        report = report.copyWith(updatedCount: report.updatedCount + 1);
      }
    }

    if (!await root.exists()) {
      return report;
    }

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !_isDownloadManifestCandidate(entity.path)) {
        continue;
      }

      report = report.copyWith(
        scannedManifestCount: report.scannedManifestCount + 1,
      );

      final manifest = await _readManifest(entity);
      if (manifest == null) {
        continue;
      }

      final mediaPath = await _resolveManifestMediaPath(manifest, entity);
      if (mediaPath == null) {
        continue;
      }

      final mediaFile = File(mediaPath);
      if (!await mediaFile.exists()) {
        continue;
      }

      final actualSize = await mediaFile.length();
      final importedTask = manifest.toTask(
        mediaPath: mediaFile.path,
        totalBytes: actualSize,
      );

      final existingByEpisodeResult = await _store.getTaskByEpisode(
        importedTask.anilistId,
        importedTask.episodeNumber,
      );
      final existingByEpisode = existingByEpisodeResult.fold(
        onSuccess: (task) => task,
        onFailure: (_) => null,
      );

      if (existingByEpisode != null &&
          existingByEpisode.id != importedTask.id) {
        final existingPath = existingByEpisode.filePath;
        final samePhysicalFile =
            existingPath != null &&
            p.normalize(existingPath) == p.normalize(mediaFile.path);
        final existingExists =
            existingPath != null && File(existingPath).existsSync();
        if (samePhysicalFile || !existingExists) {
          await _store.deleteTask(existingByEpisode.id);
          tasksById.remove(existingByEpisode.id);
          report = report.copyWith(updatedCount: report.updatedCount + 1);
        } else {
          continue;
        }
      }

      final existingById = tasksById[importedTask.id];
      if (existingById == null) {
        await _store.insertTask(importedTask);
        tasksById[importedTask.id] = importedTask;
        report = report.copyWith(importedCount: report.importedCount + 1);
        continue;
      }

      if (_shouldUpdate(existingById, importedTask)) {
        await _store.updateTask(importedTask);
        tasksById[importedTask.id] = importedTask;
        report = report.copyWith(updatedCount: report.updatedCount + 1);
      }
    }

    return report;
  }

  Future<void> writeManifest({
    required DownloadTask task,
    required String mediaPath,
    required int totalBytes,
  }) async {
    final mediaFile = File(mediaPath);
    final manifest = _DownloadSidecarManifest.fromTask(
      task,
      mediaPath: mediaFile.path,
      totalBytes: totalBytes,
    );
    final sidecar = File(sidecarPathForMedia(mediaFile.path));
    await sidecar.parent.create(recursive: true);
    await sidecar.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
      flush: true,
    );
  }

  Future<void> deleteManifestForMedia(String mediaPath) async {
    final manifestFile = File(sidecarPathForMedia(mediaPath));
    if (await manifestFile.exists()) {
      await manifestFile.delete();
    }
  }

  String sidecarPathForMedia(String mediaPath) {
    return '$mediaPath$downloadSidecarSuffix';
  }

  Future<_DownloadSidecarManifest?> _readManifest(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _DownloadSidecarManifest.tryParse(decoded);
    } catch (_) {
      return null;
    }
  }

  bool _shouldUpdate(DownloadTask existing, DownloadTask imported) {
    return existing.status != imported.status ||
        existing.filePath != imported.filePath ||
        existing.fileName != imported.fileName ||
        existing.totalBytes != imported.totalBytes ||
        existing.downloadedBytes != imported.downloadedBytes ||
        existing.animeTitle != imported.animeTitle ||
        existing.serverName != imported.serverName ||
        existing.sourcePluginId != imported.sourcePluginId ||
        existing.qualityLabel != imported.qualityLabel;
  }

  String? _mediaPathFromSidecar(String sidecarPath) {
    if (!sidecarPath.endsWith(downloadSidecarSuffix)) {
      return null;
    }
    return sidecarPath.substring(
      0,
      sidecarPath.length - downloadSidecarSuffix.length,
    );
  }

  bool _isDownloadManifestCandidate(String path) {
    final lowerPath = path.toLowerCase();
    if (!lowerPath.endsWith('.json')) {
      return false;
    }
    return !lowerPath.endsWith('.chunks.json') &&
        !lowerPath.endsWith('.chunks.json.tmp');
  }

  Future<String?> _resolveManifestMediaPath(
    _DownloadSidecarManifest manifest,
    File manifestFile,
  ) async {
    final explicitMediaPath = manifest.mediaPath?.trim();
    if (explicitMediaPath != null && explicitMediaPath.isNotEmpty) {
      if (p.isAbsolute(explicitMediaPath)) {
        return explicitMediaPath;
      }
      return p.normalize(p.join(manifestFile.parent.path, explicitMediaPath));
    }

    final sidecarPath = _mediaPathFromSidecar(manifestFile.path);
    if (sidecarPath != null) {
      return sidecarPath;
    }

    final explicitFileName = manifest.fileName?.trim();
    if (explicitFileName != null && explicitFileName.isNotEmpty) {
      return p.normalize(p.join(manifestFile.parent.path, explicitFileName));
    }

    final stem = p.withoutExtension(manifestFile.path);
    for (final extension in _mediaFileExtensions) {
      final siblingPath = '$stem$extension';
      if (await File(siblingPath).exists()) {
        return siblingPath;
      }
    }

    return null;
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    int? totalBytes,
    int? downloadedBytes,
  }) {
    return DownloadTask(
      id: task.id,
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
      sourceUrl: task.sourceUrl,
      status: task.status,
      createdAt: task.createdAt,
      fileName: task.fileName,
      filePath: task.filePath,
      totalBytes: totalBytes ?? task.totalBytes,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      sourcePluginId: task.sourcePluginId,
      serverName: task.serverName,
      detectedHost: task.detectedHost,
      errorMessage: task.errorMessage,
      updatedAt: DateTime.now(),
      headers: task.headers,
      isHls: task.isHls,
      animeTitle: task.animeTitle,
      qualityLabel: task.qualityLabel,
    );
  }
}

const _mediaFileExtensions = <String>[
  '.mp4',
  '.mkv',
  '.webm',
  '.ts',
  '.m4v',
  '.mov',
];

final class _DownloadSidecarManifest {
  const _DownloadSidecarManifest({
    required this.version,
    required this.taskId,
    required this.identityKey,
    required this.signature,
    required this.anilistId,
    required this.episodeNumber,
    required this.mediaPath,
    required this.fileName,
    required this.totalBytes,
    this.animeTitle,
    this.sourcePluginId,
    this.serverName,
    this.detectedHost,
    this.qualityLabel,
    this.isHls = false,
    this.completedAtEpochMs,
  });

  static const currentVersion = 1;

  final int version;
  final String taskId;
  final String identityKey;
  final String signature;
  final int anilistId;
  final double episodeNumber;
  final String? mediaPath;
  final String? fileName;
  final int totalBytes;
  final String? animeTitle;
  final String? sourcePluginId;
  final String? serverName;
  final String? detectedHost;
  final String? qualityLabel;
  final bool isHls;
  final int? completedAtEpochMs;

  factory _DownloadSidecarManifest.fromTask(
    DownloadTask task, {
    required String mediaPath,
    required int totalBytes,
  }) {
    final identityKey = buildDownloadIdentityKey(
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
    );
    return _DownloadSidecarManifest(
      version: currentVersion,
      taskId: task.id,
      identityKey: identityKey,
      signature: _signatureFor(identityKey: identityKey, mediaPath: mediaPath),
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
      mediaPath: mediaPath,
      fileName: task.fileName,
      totalBytes: totalBytes,
      animeTitle: task.animeTitle,
      sourcePluginId: task.sourcePluginId,
      serverName: task.serverName,
      detectedHost: task.detectedHost,
      qualityLabel: task.qualityLabel,
      isHls: task.isHls,
      completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static _DownloadSidecarManifest? tryParse(Map<String, dynamic> json) {
    final anilistId = _readNum(json, const ['anilistId', 'animeId']);
    final episodeNumber = _readNum(json, const [
      'episodeNumber',
      'episode',
      'episodeNo',
    ]);
    if (anilistId == null || episodeNumber == null) {
      return null;
    }
    final taskId =
        _readString(json, const ['taskId', 'id']) ??
        buildDownloadTaskId(
          anilistId: anilistId.toInt(),
          episodeNumber: episodeNumber.toDouble(),
        );
    final identityKey =
        _readString(json, const ['identityKey']) ??
        buildDownloadIdentityKey(
          anilistId: anilistId.toInt(),
          episodeNumber: episodeNumber.toDouble(),
        );
    final signature = _readString(json, const ['signature']) ?? '';

    return _DownloadSidecarManifest(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      taskId: taskId,
      identityKey: identityKey,
      signature: signature,
      anilistId: anilistId.toInt(),
      episodeNumber: episodeNumber.toDouble(),
      mediaPath: _readString(json, const ['mediaPath', 'filePath', 'path']),
      fileName: _readString(json, const ['fileName', 'filename', 'name']),
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      animeTitle: _readString(json, const ['animeTitle', 'title']),
      sourcePluginId: _readString(json, const ['sourcePluginId', 'sourceId']),
      serverName: _readString(json, const ['serverName', 'server']),
      detectedHost: _readString(json, const ['detectedHost', 'host']),
      qualityLabel: _readString(json, const ['qualityLabel', 'quality']),
      isHls: json['isHls'] == true,
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'taskId': taskId,
      'identityKey': identityKey,
      'signature': signature,
      'anilistId': anilistId,
      'episodeNumber': episodeNumber,
      'mediaPath': mediaPath,
      'fileName': fileName,
      'totalBytes': totalBytes,
      'animeTitle': animeTitle,
      'sourcePluginId': sourcePluginId,
      'serverName': serverName,
      'detectedHost': detectedHost,
      'qualityLabel': qualityLabel,
      'isHls': isHls,
      'completedAtEpochMs': completedAtEpochMs,
    };
  }

  DownloadTask toTask({required String mediaPath, required int totalBytes}) {
    final importedTaskId = taskId.isNotEmpty
        ? taskId
        : buildDownloadTaskId(
            anilistId: anilistId,
            episodeNumber: episodeNumber,
          );
    return DownloadTask(
      id: importedTaskId,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      sourceUrl: Uri.file(mediaPath),
      status: DownloadStatus.completed,
      createdAt: completedAtEpochMs != null
          ? DateTime.fromMillisecondsSinceEpoch(completedAtEpochMs!)
          : DateTime.now(),
      fileName: p.basename(mediaPath),
      filePath: mediaPath,
      totalBytes: totalBytes,
      downloadedBytes: totalBytes,
      sourcePluginId: sourcePluginId,
      serverName: serverName,
      detectedHost: detectedHost,
      updatedAt: DateTime.now(),
      headers: const <String, String>{},
      isHls: isHls,
      animeTitle: animeTitle,
      qualityLabel: qualityLabel,
    );
  }

  static num? _readNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value;
      }
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _signatureFor({
    required String identityKey,
    required String mediaPath,
  }) {
    return sha256.convert(utf8.encode('$identityKey|$mediaPath')).toString();
  }
}
