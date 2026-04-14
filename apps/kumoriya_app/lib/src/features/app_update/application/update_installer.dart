import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Installs the downloaded update for the current platform.
///
/// - **Android**: opens the APK via system install intent.
/// - **Windows**: launches the EXE installer and exits the app so the
///   installer can replace files.
class UpdateInstaller {
  /// Launches the installer at [filePath].
  ///
  /// On Windows this will exit the current process after launching the
  /// installer.
  static Future<void> install(String filePath) async {
    if (Platform.isAndroid) {
      await _installAndroid(filePath);
    } else if (Platform.isWindows) {
      await _installWindows(filePath);
    } else if (Platform.isLinux) {
      await _installLinux(filePath);
    }
  }

  static Future<void> _installAndroid(String filePath) async {
    final installPermission = await Permission.requestInstallPackages.status;
    if (!installPermission.isGranted) {
      final requested = await Permission.requestInstallPackages.request();
      if (!requested.isGranted) {
        if (requested.isPermanentlyDenied) {
          await openAppSettings();
        }
        throw Exception(
          'Install unknown apps permission is required to install updates.',
        );
      }
    }

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Failed to open APK: ${result.message}');
    }
  }

  static Future<void> _installWindows(String filePath) async {
    // Launch the installer detached so it keeps running after we exit.
    await Process.start(filePath, <String>[], mode: ProcessStartMode.detached);
    // Give a small grace period for the process to start, then exit.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  static Future<void> _installLinux(String filePath) async {
    // Make the downloaded file executable, then launch it detached.
    await Process.run('chmod', ['+x', filePath]);
    await Process.start(filePath, <String>[], mode: ProcessStartMode.detached);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    exit(0);
  }
}
