import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a persistent device fingerprint that survives app reinstalls.
///
/// - Android: `Settings.Secure.ANDROID_ID` (per-device, per-user; survives
///   reinstalls, resets on factory wipe).
/// - Windows: `deviceId` from `WindowsDeviceInfo` (machine-level GUID).
/// - iOS/macOS/Linux: best-effort identifiers (may change on reinstall).
///
/// The value is sent to the API so it can deduplicate sessions from the same
/// physical device instead of creating a new entry on every login.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      // android.id is Settings.Secure.ANDROID_ID — stable across installs.
      return 'android:${android.id}';
    }
    if (Platform.isWindows) {
      final windows = await info.windowsInfo;
      return 'windows:${windows.deviceId}';
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      // identifierForVendor changes on reinstall if no other app from the
      // same vendor is installed, but it's the best iOS offers.
      return 'ios:${ios.identifierForVendor ?? ios.name}';
    }
    if (Platform.isMacOS) {
      final mac = await info.macOsInfo;
      return 'macos:${mac.systemGUID ?? mac.computerName}';
    }
    if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return 'linux:${linux.machineId ?? linux.prettyName}';
    }
  } catch (_) {
    // Fall through to default.
  }
  return 'unknown:${Platform.operatingSystem}';
});
