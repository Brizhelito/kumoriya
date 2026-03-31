import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_update_service.dart';

/// Singleton service provider.
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// State for the update check + download flow.
sealed class AppUpdateState {
  const AppUpdateState();
}

class AppUpdateIdle extends AppUpdateState {
  const AppUpdateIdle();
}

class AppUpdateChecking extends AppUpdateState {
  const AppUpdateChecking();
}

class AppUpdateAvailable extends AppUpdateState {
  const AppUpdateAvailable(this.update);
  final AvailableUpdate update;
}

class AppUpdateDownloading extends AppUpdateState {
  const AppUpdateDownloading({required this.received, required this.total});
  final int received;
  final int total;

  double get progress => total > 0 ? received / total : 0;
}

class AppUpdateReadyToInstall extends AppUpdateState {
  const AppUpdateReadyToInstall({required this.filePath, required this.update});
  final String filePath;
  final AvailableUpdate update;
}

class AppUpdateError extends AppUpdateState {
  const AppUpdateError(this.message);
  final String message;
}

/// Notifier that drives the update UI flow.
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateIdle();

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  Future<void> checkForUpdate() async {
    state = const AppUpdateChecking();

    final result = await _service.checkForUpdate();
    result.fold(
      onSuccess: (update) {
        if (update != null) {
          state = AppUpdateAvailable(update);
        } else {
          state = const AppUpdateIdle();
        }
      },
      onFailure: (error) {
        // Silently fall back to idle on network errors during auto-check.
        state = const AppUpdateIdle();
      },
    );
  }

  Future<void> downloadAndInstall(AvailableUpdate update) async {
    state = const AppUpdateDownloading(received: 0, total: -1);

    final result = await _service.downloadUpdate(
      update,
      onProgress: (received, total) {
        state = AppUpdateDownloading(received: received, total: total);
      },
    );

    result.fold(
      onSuccess: (filePath) {
        state = AppUpdateReadyToInstall(filePath: filePath, update: update);
      },
      onFailure: (error) {
        state = AppUpdateError(error.message);
      },
    );
  }

  void dismiss() {
    state = const AppUpdateIdle();
  }

  void setErrorMessage(String message) {
    state = AppUpdateError(message);
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
