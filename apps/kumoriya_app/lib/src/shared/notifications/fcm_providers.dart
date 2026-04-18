import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fcm_service.dart';

/// Singleton `FcmService` for the running app. Initialisation is
/// performed in `main.dart` (Android-only) before the provider tree
/// starts using it.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  ref.onDispose(() {
    // Best-effort cleanup; errors here shouldn't crash shutdown.
    service.dispose();
  });
  return service;
});
