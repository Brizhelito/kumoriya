import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a human-readable device name for session identification.
///
/// Examples: "Samsung Galaxy S24", "Pixel 8 Pro", "Windows 11 (DESKTOP-ABC)"
final deviceNameProvider = FutureProvider<String>((ref) async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.brand;
      final model = android.model;
      // Avoid "Samsung Samsung Galaxy S24" duplication.
      if (model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model';
    }
    if (Platform.isWindows) {
      final windows = await info.windowsInfo;
      return 'Windows (${windows.computerName})';
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.name;
    }
    if (Platform.isMacOS) {
      final mac = await info.macOsInfo;
      return mac.computerName;
    }
    if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return linux.prettyName;
    }
  } catch (_) {
    // Fall through to default.
  }
  return Platform.operatingSystem;
});
