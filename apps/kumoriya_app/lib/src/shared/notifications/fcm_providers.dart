import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fcm_service.dart';

/// Singleton `FcmService` for the running app. Initialisation is
/// performed in `main.dart` (Android-only) before the provider tree
/// starts using it.
///
/// On platforms where Firebase is not supported (Windows, Linux, macOS,
/// web), returns a [NoopFcmTopicSubscriber] to avoid constructing
/// [FcmService] which eagerly accesses [FirebaseMessaging.instance].
final fcmServiceProvider = Provider<FcmTopicSubscriber>((ref) {
  if (!FcmService.isSupported) {
    return NoopFcmTopicSubscriber();
  }
  final service = FcmService();
  ref.onDispose(() {
    // Best-effort cleanup; errors here shouldn't crash shutdown.
    service.dispose();
  });
  return service;
});
