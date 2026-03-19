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
      if (entity is! File || !entity.path.endsWith(downloadSidecarSuffix)) {
        continue;
      }

      report = report.copyWith(
        scannedManifestCount: report.scannedManifestCount + 1,
      );

      final manifest = await _readManifest(entity);
      if (manifest == null) {
        continue;
      }

      final mediaPath =
          manifest.mediaPath ?? _mediaPathFromSidecar(entity.path);
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

final class _DownloadSidecarManifest {
  const _DownloadSidecarManifest({
    required this.version,
    required this.taskId,
    required this.identityKey,
    required this.signature,
    required this.anilistId,
    required this.episodeNumber,
    required this.mediaPath,
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
    final anilistId = json['anilistId'];
    final episodeNumber = json['episodeNumber'];
    final taskId = json['taskId'];
    final identityKey = json['identityKey'];
    final signature = json['signature'];
    if (anilistId is! num ||
        episodeNumber is! num ||
        taskId is! String ||
        identityKey is! String ||
        signature is! String) {
      return null;
    }

    return _DownloadSidecarManifest(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      taskId: taskId,
      identityKey: identityKey,
      signature: signature,
      anilistId: anilistId.toInt(),
      episodeNumber: episodeNumber.toDouble(),
      mediaPath: json['mediaPath'] as String?,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      animeTitle: json['animeTitle'] as String?,
      sourcePluginId: json['sourcePluginId'] as String?,
      serverName: json['serverName'] as String?,
      detectedHost: json['detectedHost'] as String?,
      qualityLabel: json['qualityLabel'] as String?,
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

  static String _signatureFor({
    required String identityKey,
    required String mediaPath,
  }) {
    return sha256.convert(utf8.encode('$identityKey|$mediaPath')).toString();
  }
}
