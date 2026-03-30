import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import 'download_directory_service.dart';

/// File-based [AniSkipCacheStore] that stores one JSON file per anime.
///
/// Location: `{downloadsRoot}/aniskip/{anilistId}.json`
///
/// This store is designed as durable supplementary storage that survives
/// app reinstalls and Drift DB resets. It is meant to be consumed through
/// a [CompositeAniSkipCacheStore] alongside the primary Drift store.
///
/// JSON format example:
/// ```json
/// {
///   "v": 1,
///   "anilistId": 12345,
///   "updatedAtEpochMs": 1742000000000,
///   "episodes": {
///     "1": {
///       "payloadJson": "[{\"kind\":\"opening\",\"startMs\":5000,\"endMs\":95000}]",
///       "updatedAtEpochMs": 1742000000000,
///       "requestedEpisodeLengthSeconds": 1440
///     }
///   }
/// }
/// ```
final class DownloadAniSkipFileStore implements AniSkipCacheStore {
  DownloadAniSkipFileStore({required DownloadDirectoryService directoryService})
    : _directoryService = directoryService;

  final DownloadDirectoryService _directoryService;

  // ---------------------------------------------------------------------------
  // AniSkipCacheStore contract
  // ---------------------------------------------------------------------------

  @override
  Future<Result<AniSkipCacheRecord?, KumoriyaError>> getEpisode(
    int anilistId,
    int episodeNumber,
  ) async {
    try {
      final map = await _readEpisodeMap(anilistId);
      return Success(map?[episodeNumber]);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_file_read_failed',
          message: 'Failed to read AniSkip from file cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AniSkipCacheRecord>, KumoriyaError>> getEpisodesForAnime(
    int anilistId,
  ) async {
    try {
      final map = await _readEpisodeMap(anilistId);
      if (map == null) return const Success([]);
      final records = map.values.toList(growable: false)
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      return Success(records);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_file_list_failed',
          message: 'Failed to list AniSkip from file cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(AniSkipCacheRecord record) async {
    try {
      final existing = await _readEpisodeMap(record.anilistId) ?? {};
      existing[record.episodeNumber] = record;
      await _writeEpisodeMap(record.anilistId, existing);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_file_write_failed',
          message: 'Failed to write AniSkip to file cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAnime(int anilistId) async {
    try {
      final file = await _animeFile(anilistId);
      if (await file.exists()) {
        await file.delete();
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_file_clear_failed',
          message: 'Failed to clear AniSkip file cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    try {
      final dir = await _aniskipDirectory();
      if (!await dir.exists()) return const Success(0);

      final cutoff = DateTime.now().subtract(maxAge);
      var removedCount = 0;

      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          await _pruneStaleEntries(
            entity,
            cutoff,
            removedCount: (n) {
              removedCount += n;
            },
          );
        } catch (_) {
          // Skip corrupt files silently.
        }
      }

      return Success(removedCount);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_file_cleanup_failed',
          message: 'Failed to clean AniSkip file cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _aniskipDirectory() async {
    final root = await _directoryService.resolveDownloadsDirectory();
    return Directory(p.join(root.path, 'aniskip'));
  }

  Future<File> _animeFile(int anilistId) async {
    final dir = await _aniskipDirectory();
    return File(p.join(dir.path, '$anilistId.json'));
  }

  Future<Map<int, AniSkipCacheRecord>?> _readEpisodeMap(int anilistId) async {
    final file = await _animeFile(anilistId);
    if (!await file.exists()) return null;

    final dynamic json;
    try {
      json = jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }

    if (json is! Map<String, dynamic>) return null;
    final episodes = json['episodes'];
    if (episodes is! Map<String, dynamic>) return null;

    final result = <int, AniSkipCacheRecord>{};
    for (final entry in episodes.entries) {
      final epNum = int.tryParse(entry.key);
      if (epNum == null) continue;
      final epMap = entry.value;
      if (epMap is! Map<String, dynamic>) continue;
      final record = _recordFromMap(anilistId, epNum, epMap);
      if (record != null) result[epNum] = record;
    }
    return result;
  }

  Future<void> _writeEpisodeMap(
    int anilistId,
    Map<int, AniSkipCacheRecord> records,
  ) async {
    final dir = await _aniskipDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);

    final episodes = <String, Object?>{
      for (final e in records.entries) '${e.key}': _recordToMap(e.value),
    };
    final file = await _animeFile(anilistId);
    await _atomicWrite(file, <String, Object?>{
      'v': 1,
      'anilistId': anilistId,
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'episodes': episodes,
    });
  }

  Future<void> _atomicWrite(File file, Map<String, Object?> data) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<void> _pruneStaleEntries(
    File file,
    DateTime cutoff, {
    required void Function(int n) removedCount,
  }) async {
    final dynamic json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      await file.delete();
      return;
    }
    final episodes = json['episodes'];
    if (episodes is! Map<String, dynamic>) {
      await file.delete();
      return;
    }

    final toRemove = <String>[];
    for (final entry in episodes.entries) {
      final epMap = entry.value;
      if (epMap is! Map<String, dynamic>) {
        toRemove.add(entry.key);
        continue;
      }
      final epochMs = epMap['updatedAtEpochMs'];
      if (epochMs is! int) {
        toRemove.add(entry.key);
        continue;
      }
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(epochMs);
      if (updatedAt.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isEmpty) return;

    removedCount(toRemove.length);
    for (final key in toRemove) {
      episodes.remove(key);
    }

    if (episodes.isEmpty) {
      if (await file.exists()) await file.delete();
    } else {
      json['episodes'] = episodes;
      await _atomicWrite(file, Map<String, Object?>.from(json));
    }
  }

  AniSkipCacheRecord? _recordFromMap(
    int anilistId,
    int episodeNumber,
    Map<String, dynamic> map,
  ) {
    final payloadJson = map['payloadJson'];
    final epochMs = map['updatedAtEpochMs'];
    if (payloadJson is! String || epochMs is! int) return null;
    return AniSkipCacheRecord(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      payloadJson: payloadJson,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(epochMs),
      requestedEpisodeLengthSeconds:
          map['requestedEpisodeLengthSeconds'] as int?,
    );
  }

  Map<String, Object?> _recordToMap(AniSkipCacheRecord record) {
    return <String, Object?>{
      'payloadJson': record.payloadJson,
      'updatedAtEpochMs': record.updatedAt.millisecondsSinceEpoch,
      'requestedEpisodeLengthSeconds': record.requestedEpisodeLengthSeconds,
    };
  }
}
