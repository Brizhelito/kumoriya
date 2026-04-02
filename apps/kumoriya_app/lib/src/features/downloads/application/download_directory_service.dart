import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DirectoryPathPicker = Future<String?> Function();
typedef DefaultDownloadDirectoryResolver = Future<Directory> Function();
typedef AndroidStoragePermissionRequester = Future<bool> Function();

final class DownloadDirectoryInfo {
  const DownloadDirectoryInfo({required this.path, required this.isCustom});

  final String path;
  final bool isCustom;
}

enum DownloadDirectorySelectionStatus { updated, cancelled }

final class DownloadDirectorySelectionOutcome {
  const DownloadDirectorySelectionOutcome({
    required this.status,
    required this.info,
  });

  final DownloadDirectorySelectionStatus status;
  final DownloadDirectoryInfo info;

  bool get changed => status == DownloadDirectorySelectionStatus.updated;
}

abstract interface class DownloadDirectoryStore {
  Future<String?> readCustomDirectoryPath();

  Future<void> writeCustomDirectoryPath(String? path);
}

final class FileDownloadDirectoryStore implements DownloadDirectoryStore {
  FileDownloadDirectoryStore({Future<File> Function()? settingsFileProvider})
    : _settingsFileProvider = settingsFileProvider ?? _defaultSettingsFile;

  final Future<File> Function() _settingsFileProvider;

  @override
  Future<String?> readCustomDirectoryPath() async {
    final file = await _settingsFileProvider();
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final rawPath = decoded['custom_download_directory_path'];
      if (rawPath is! String) {
        return null;
      }
      final trimmed = rawPath.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {
    final file = await _settingsFileProvider();
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'custom_download_directory_path': trimmed}),
      flush: true,
    );
  }

  static Future<File> _defaultSettingsFile() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final settingsDir = Directory(p.join(appSupportDir.path, 'kumoriya'));
    await settingsDir.create(recursive: true);
    return File(p.join(settingsDir.path, 'download_directory.json'));
  }
}

final class DownloadDirectoryService {
  DownloadDirectoryService({
    required DownloadDirectoryStore store,
    DirectoryPathPicker? directoryPicker,
    DefaultDownloadDirectoryResolver? defaultDirectoryResolver,
    AndroidStoragePermissionRequester? androidPermissionRequester,
  }) : _store = store,
       _directoryPicker = directoryPicker ?? _pickDirectoryPath,
       _defaultDirectoryResolver =
           defaultDirectoryResolver ?? _defaultDownloadsDirectory,
       _androidPermissionRequester =
           androidPermissionRequester ?? requestAndroidStorageAccess;

  final DownloadDirectoryStore _store;
  final DirectoryPathPicker _directoryPicker;
  final DefaultDownloadDirectoryResolver _defaultDirectoryResolver;
  final AndroidStoragePermissionRequester _androidPermissionRequester;

  Future<bool> hasConfiguredDownloadDirectory() async {
    final custom = await _store.readCustomDirectoryPath();
    return custom != null && custom.isNotEmpty;
  }

  Future<String> getDefaultSuggestionPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/Kumoriya';
    }
    final dir = await getDownloadsDirectory();
    return dir != null ? '${dir.path}/Kumoriya' : '/tmp/Kumoriya';
  }

  Future<DownloadDirectoryInfo> getDirectoryInfo() async {
    final customDirectory = await _validatedCustomDirectory(clearInvalid: true);
    if (customDirectory != null) {
      return DownloadDirectoryInfo(path: customDirectory.path, isCustom: true);
    }

    final defaultDirectory = await _ensureUsableDirectory(
      await _defaultDirectoryResolver(),
    );
    return DownloadDirectoryInfo(path: defaultDirectory.path, isCustom: false);
  }

  Future<Directory> resolveDownloadsDirectory() async {
    final customDirectory = await _validatedCustomDirectory(clearInvalid: true);
    if (customDirectory != null) {
      return customDirectory;
    }
    return _ensureUsableDirectory(await _defaultDirectoryResolver());
  }

  Future<Result<DownloadDirectorySelectionOutcome, KumoriyaError>>
  selectDirectory() async {
    try {
      if (Platform.isAndroid) {
        final granted = await _androidPermissionRequester();
        if (!granted) {
          return const Failure(
            SimpleError(
              code: 'download.directory_permission_denied',
              message:
                  'Storage permission was denied for download folder selection.',
              kind: KumoriyaErrorKind.cancelled,
            ),
          );
        }
      }

      final selectedPath = await _directoryPicker();
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        return Success(
          DownloadDirectorySelectionOutcome(
            status: DownloadDirectorySelectionStatus.cancelled,
            info: await getDirectoryInfo(),
          ),
        );
      }

      final directory = await _ensureUsableDirectory(
        Directory(selectedPath.trim()),
      );
      await _store.writeCustomDirectoryPath(directory.path);

      return Success(
        DownloadDirectorySelectionOutcome(
          status: DownloadDirectorySelectionStatus.updated,
          info: DownloadDirectoryInfo(path: directory.path, isCustom: true),
        ),
      );
    } catch (error) {
      return Failure(
        SimpleError(
          code: 'download.directory_update_failed',
          message: 'Failed to update the download directory: $error',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  Future<Result<DownloadDirectorySelectionOutcome, KumoriyaError>>
  selectAndPersistCustomDirectory() {
    return selectDirectory();
  }

  Future<Result<DownloadDirectorySelectionOutcome, KumoriyaError>>
  selectDirectoryPath(String directoryPath) async {
    final normalizedPath = directoryPath.trim();
    if (normalizedPath.isEmpty) {
      return Failure(
        SimpleError(
          code: 'download.directory_update_failed',
          message: 'Failed to update the download directory: empty path.',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }

    try {
      final directory = await _ensureUsableDirectory(Directory(normalizedPath));
      await _store.writeCustomDirectoryPath(directory.path);
      return Success(
        DownloadDirectorySelectionOutcome(
          status: DownloadDirectorySelectionStatus.updated,
          info: DownloadDirectoryInfo(path: directory.path, isCustom: true),
        ),
      );
    } catch (error) {
      return Failure(
        SimpleError(
          code: 'download.directory_update_failed',
          message: 'Failed to update the download directory: $error',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  Future<Result<DownloadDirectoryInfo, KumoriyaError>> resetToDefault() async {
    try {
      await _store.writeCustomDirectoryPath(null);
      return Success(await getDirectoryInfo());
    } catch (error) {
      return Failure(
        SimpleError(
          code: 'download.directory_reset_failed',
          message: 'Failed to reset the download directory: $error',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  Future<Directory?> _validatedCustomDirectory({
    required bool clearInvalid,
  }) async {
    final configuredPath = await _store.readCustomDirectoryPath();
    if (configuredPath == null || configuredPath.trim().isEmpty) {
      return null;
    }

    final directory = Directory(configuredPath.trim());
    try {
      return await _ensureUsableDirectory(directory);
    } catch (_) {
      if (clearInvalid) {
        await _store.writeCustomDirectoryPath(null);
      }
      return null;
    }
  }

  Future<Directory> _ensureUsableDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final probe = File(
      p.join(
        directory.path,
        '.kumoriya_write_probe_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(directory)}',
      ),
    );
    try {
      await probe.writeAsString('ok', flush: true);
    } on FileSystemException {
      rethrow;
    }
    try {
      if (await probe.exists()) {
        await probe.delete();
      }
    } on FileSystemException {
      // Probe cleanup is best-effort; the directory is still usable.
    }
    return directory;
  }

  static Future<bool> requestAndroidStorageAccess() async {
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return true;
    }

    final manageResult = await Permission.manageExternalStorage.request();
    if (manageResult.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) {
      return true;
    }

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) {
      return true;
    }

    final videosStatus = await Permission.videos.status;
    if (videosStatus.isGranted) {
      return true;
    }

    final videosResult = await Permission.videos.request();
    return videosResult.isGranted;
  }

  static Future<String?> _pickDirectoryPath() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select download folder',
      lockParentWindow: true,
    );
  }

  static Future<Directory> _defaultDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'kumoriya', 'downloads'));
  }
}
