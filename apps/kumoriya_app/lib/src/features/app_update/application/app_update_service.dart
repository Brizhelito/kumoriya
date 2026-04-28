import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _manifestUrl = 'https://api.kumoriya.online/releases/latest';

const _parallelDownloadPartCount = 4;
const _parallelDownloadMinSizeBytes = 16 * 1024 * 1024; // 16 MB
const _downloadRequestTimeout = Duration(seconds: 45);

/// Represents the update information for one platform.
class PlatformUpdateInfo {
  const PlatformUpdateInfo({
    required this.latestVersion,
    required this.url,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String url;
  final String releaseNotes;
}

/// Describes an available update with enough data for the UI.
class AvailableUpdate {
  const AvailableUpdate({
    required this.currentVersion,
    required this.newVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.sizeBytes,
  });

  final String currentVersion;
  final String newVersion;
  final String downloadUrl;
  final String releaseNotes;

  /// APK size in bytes, if known from the manifest. Useful for progress
  /// estimation before the download starts.
  final int? sizeBytes;
}

/// Progress callback for the download phase.
typedef DownloadProgressCallback = void Function(int received, int total);

class AppUpdateService {
  AppUpdateService({http.Client? httpClient})
    : _client = httpClient ?? _buildDefaultClient();

  final http.Client _client;

  /// On Android, use Chromium's Cronet engine (the same HTTP stack used by
  /// Android's WebView). It supports HTTP/2, has properly sized TCP receive
  /// buffers, and is significantly faster than Dart's built-in HttpClient for
  /// large file downloads. Falls back to the default client on other platforms
  /// or if Cronet is unavailable.
  static http.Client _buildDefaultClient() {
    if (!Platform.isAndroid) return http.Client();
    try {
      return CronetClient.fromCronetEngine(
        CronetEngine.build(cacheMode: CacheMode.disabled),
        closeEngine: true,
      );
    } catch (_) {
      return http.Client();
    }
  }

  /// Checks the remote manifest and returns an [AvailableUpdate] if the remote
  /// version is strictly newer than the current app version, or `null` if up to
  /// date.
  ///
  /// [platformOverride] is intended for testing on hosts where
  /// [Platform.isAndroid] would otherwise be false.
  Future<Result<AvailableUpdate?, KumoriyaError>> checkForUpdate({
    String? currentVersion,
    String? platformOverride,
  }) async {
    try {
      final currentVersion_ =
          currentVersion ?? (await PackageInfo.fromPlatform()).version;

      final response = await _client
          .get(Uri.parse(_manifestUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Failure(
          SimpleError(
            code: 'update_manifest_fetch',
            message:
                'Failed to fetch update manifest (HTTP ${response.statusCode})',
            kind: KumoriyaErrorKind.transport,
          ),
        );
      }

      final Map<String, dynamic> manifest =
          jsonDecode(response.body) as Map<String, dynamic>;

      final String platformKey;
      if (platformOverride != null) {
        platformKey = platformOverride;
      } else if (Platform.isAndroid) {
        platformKey = 'android';
      } else if (Platform.isWindows) {
        platformKey = 'windows';
      } else if (Platform.isLinux) {
        platformKey = 'linux';
      } else {
        return const Success(null); // unsupported platform — no update
      }

      final platformData = manifest[platformKey] as Map<String, dynamic>?;
      if (platformData == null) {
        return const Success(null);
      }

      final String? resolvedUrl;
      final int? resolvedSize;
      if (platformKey == 'android') {
        (resolvedUrl, resolvedSize) = await _resolveAndroidDownloadUrl(
          platformData,
        );
      } else {
        resolvedUrl = platformData['url'] as String?;
        resolvedSize = null;
      }

      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        return const Success(null);
      }

      final latestVersion = platformData['latest_version'] as String? ?? '';
      final releaseNotes = platformData['release_notes'] as String? ?? '';
      if (latestVersion.isEmpty) {
        return const Success(null);
      }

      if (_isNewer(latestVersion, currentVersion_)) {
        return Success(
          AvailableUpdate(
            currentVersion: currentVersion_,
            newVersion: latestVersion,
            downloadUrl: resolvedUrl,
            releaseNotes: releaseNotes,
            sizeBytes: resolvedSize,
          ),
        );
      }

      return const Success(null);
    } on SocketException catch (e) {
      return Failure(
        SimpleError(
          code: 'update_network',
          message: 'Network error checking for update: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    } on HttpException catch (e) {
      return Failure(
        SimpleError(
          code: 'update_http',
          message: 'HTTP error checking for update: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'update_check_failed',
          message: 'Unexpected error checking for update: $e',
        ),
      );
    }
  }

  /// Detects the device's primary ABI via [DeviceInfoPlugin] and resolves the
  /// best matching APK URL from the manifest. Falls back to `universal`, then
  /// `url` (legacy top-level) if the ABI map is missing.
  static Future<(String?, int?)> _resolveAndroidDownloadUrl(
    Map<String, dynamic> platformData,
  ) async {
    final abisData = platformData['abis'] as Map<String, dynamic>?;
    final universalData = platformData['universal'] as Map<String, dynamic>?;
    final legacyUrl = platformData['url'] as String?;

    // Map from Build.SUPPORTED_ABIS value → manifest ABI key.
    const manifestKey = <String, String>{
      'arm64-v8a': 'arm64_v8a',
      'armeabi-v7a': 'armeabi_v7a',
      'x86_64': 'x86_64',
    };

    String? url;
    int? size;
    Map<String, dynamic>? artifact;

    if (abisData != null && abisData.isNotEmpty) {
      try {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        for (final supported in deviceInfo.supportedAbis) {
          final key = manifestKey[supported];
          if (key == null) continue;
          final data = abisData[key] as Map<String, dynamic>?;
          if (data != null && data['url'] is String) {
            artifact = data;
            break;
          }
        }
      } catch (_) {
        // Not running on Android (e.g., test runner / CI) — fall through to
        // universal so the update check still works.
      }
    }

    if (artifact == null && universalData != null) {
      artifact = universalData;
    }

    if (artifact != null) {
      url = artifact['url'] as String?;
      size = artifact['size_bytes'] as int?;
    }

    if (url == null || url.isEmpty) {
      url = legacyUrl;
    }

    return (url, size);
  }

  /// Downloads the installer to a temporary directory and returns the file
  /// path. Reports progress through [onProgress].
  Future<Result<String, KumoriyaError>> downloadUpdate(
    AvailableUpdate update, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      final uri = Uri.parse(update.downloadUrl);
      final fileName = uri.pathSegments.lastOrNull ?? 'update_installer';
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, fileName);
      final file = File(filePath);

      if (Platform.isAndroid) {
        final accelerated = await _tryParallelRangeDownload(
          uri: uri,
          file: file,
          onProgress: onProgress,
        );
        if (accelerated != null) {
          return Success(accelerated);
        }
      }

      return _downloadSingleStream(
        uri: uri,
        file: file,
        onProgress: onProgress,
      );
    } on SocketException catch (e) {
      return Failure(
        SimpleError(
          code: 'update_download_network',
          message: 'Network error downloading update: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'update_download_failed',
          message: 'Unexpected error downloading update: $e',
        ),
      );
    }
  }

  Future<Result<String, KumoriyaError>> _downloadSingleStream({
    required Uri uri,
    required File file,
    required DownloadProgressCallback? onProgress,
  }) async {
    final request = http.Request('GET', uri)
      ..headers['Accept-Encoding'] = 'identity';
    final streamedResponse = await _client
        .send(request)
        .timeout(_downloadRequestTimeout);

    if (streamedResponse.statusCode != 200) {
      return Failure(
        SimpleError(
          code: 'update_download_http',
          message: 'Download failed (HTTP ${streamedResponse.statusCode})',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    final contentLength = streamedResponse.contentLength ?? -1;
    final sink = file.openWrite();
    var received = 0;
    var lastProgressTickBytes = 0;
    final progressWatch = Stopwatch()..start();

    bool shouldEmitProgress(int bytes) {
      const minBytesStep = 2 * 1024 * 1024; // 2 MB
      const minMillisStep = 350;

      if (bytes == 0) {
        return true;
      }
      if (contentLength > 0 && bytes >= contentLength) {
        return true;
      }
      if (bytes - lastProgressTickBytes >= minBytesStep) {
        return true;
      }
      if (progressWatch.elapsedMilliseconds >= minMillisStep) {
        return true;
      }
      return false;
    }

    try {
      onProgress?.call(0, contentLength);
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (shouldEmitProgress(received)) {
          onProgress?.call(received, contentLength);
          lastProgressTickBytes = received;
          progressWatch.reset();
        }
      }
      onProgress?.call(received, contentLength);
    } finally {
      progressWatch.stop();
      await sink.flush();
      await sink.close();
    }

    return Success(file.path);
  }

  Future<String?> _tryParallelRangeDownload({
    required Uri uri,
    required File file,
    required DownloadProgressCallback? onProgress,
  }) async {
    final partFiles = <File>[];

    try {
      final headRequest = http.Request('HEAD', uri)
        ..headers['Accept-Encoding'] = 'identity';
      final headResponse = await _client
          .send(headRequest)
          .timeout(_downloadRequestTimeout);

      final totalBytes = headResponse.contentLength ?? -1;
      final acceptRanges = (headResponse.headers['accept-ranges'] ?? '')
          .toLowerCase();

      if (headResponse.statusCode < 200 ||
          headResponse.statusCode >= 400 ||
          totalBytes < _parallelDownloadMinSizeBytes ||
          !acceptRanges.contains('bytes')) {
        return null;
      }

      final partSize = (totalBytes / _parallelDownloadPartCount).ceil();
      var totalReceived = 0;
      var lastProgressTickBytes = 0;
      final progressWatch = Stopwatch()..start();

      bool shouldEmitProgress(int bytes) {
        const minBytesStep = 4 * 1024 * 1024; // 4 MB
        const minMillisStep = 350;

        if (bytes == 0 || bytes >= totalBytes) {
          return true;
        }
        if (bytes - lastProgressTickBytes >= minBytesStep) {
          return true;
        }
        if (progressWatch.elapsedMilliseconds >= minMillisStep) {
          return true;
        }
        return false;
      }

      Future<void> downloadPart(int index) async {
        final start = index * partSize;
        final end = (start + partSize - 1).clamp(0, totalBytes - 1);
        if (start > end) {
          return;
        }

        final partFile = File('${file.path}.part$index');
        partFiles.add(partFile);

        final request = http.Request('GET', uri)
          ..headers['Range'] = 'bytes=$start-$end'
          ..headers['Accept-Encoding'] = 'identity';
        final response = await _client
            .send(request)
            .timeout(_downloadRequestTimeout);

        if (response.statusCode != 206) {
          throw Exception(
            'Range request unsupported (HTTP ${response.statusCode})',
          );
        }

        final sink = partFile.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            totalReceived += chunk.length;
            if (shouldEmitProgress(totalReceived)) {
              onProgress?.call(totalReceived, totalBytes);
              lastProgressTickBytes = totalReceived;
              progressWatch.reset();
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }

      onProgress?.call(0, totalBytes);
      await Future.wait(
        List<Future<void>>.generate(
          _parallelDownloadPartCount,
          downloadPart,
          growable: false,
        ),
      );

      final outputSink = file.openWrite();
      try {
        for (var i = 0; i < _parallelDownloadPartCount; i++) {
          final partFile = File('${file.path}.part$i');
          if (await partFile.exists()) {
            await outputSink.addStream(partFile.openRead());
          }
        }
      } finally {
        await outputSink.flush();
        await outputSink.close();
      }

      onProgress?.call(totalBytes, totalBytes);
      progressWatch.stop();
      return file.path;
    } catch (_) {
      return null;
    } finally {
      for (final partFile in partFiles) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
      }
    }
  }

  /// Compares two semver-ish version strings. Returns true if [remote] is
  /// strictly newer than [current].
  static bool _isNewer(String remote, String current) {
    final remoteParts = _parseVersion(remote);
    final currentParts = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false; // equal
  }

  static List<int> _parseVersion(String version) {
    final cleaned = version.replaceFirst(RegExp(r'^v'), '');
    final parts = cleaned.split('.');
    return [
      parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0,
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0,
    ];
  }
}
