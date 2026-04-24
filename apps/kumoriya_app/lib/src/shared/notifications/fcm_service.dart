import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_topic.dart';

/// Minimal surface used by decorators and reconciliation services to
/// mirror library state to FCM topics. Extracted so those consumers
/// can be unit-tested against a fake, without spinning up a real
/// `FirebaseMessaging` instance.
abstract interface class FcmTopicSubscriber {
  Future<void> subscribeToMedia(int anilistId);
  Future<void> unsubscribeFromMedia(int anilistId);
}

/// Background message handler. Must be a top-level or static function so
/// it can be passed across the Dart isolate boundary the FCM plugin
/// spins up for background messages.
///
/// Kept minimal in Slice 3 — Slice 4 will wire this to deep-links and
/// local persistence.
@pragma('vm:entry-point')
Future<void> kumoriyaFcmBackgroundHandler(RemoteMessage message) async {
  // Background isolates must re-run `Firebase.initializeApp()` before
  // touching any Firebase API. Calling it is safe even if the plugin
  // already did it here — it's idempotent.
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint(
      '[FCM/background] received messageId=${message.messageId} '
      'data=${message.data}',
    );
  }
}

/// Thin wrapper around `FirebaseMessaging` that exposes only what the
/// app actually uses. Keeps direct Firebase imports out of widget code
/// so the domain can be unit-tested without a live Firebase runtime.
///
/// Responsibilities are deliberately narrow: initialize, observe token,
/// subscribe/unsubscribe by AniList media id, and forward incoming
/// foreground messages through a Stream. No UI, no persistence —
/// Slice 4 will build on top of this.
class FcmService implements FcmTopicSubscriber {
  FcmService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  /// Latest FCM registration token known to the service, or `null`
  /// before the first successful call to `getToken()`.
  String? get currentToken => _currentToken;
  String? _currentToken;

  /// Emits every new token seen (initial + refreshes). Useful for the
  /// server-side sync that associates a token with the logged-in user.
  Stream<String> get tokens => _tokenController.stream;

  /// Foreground messages forwarded from `FirebaseMessaging.onMessage`.
  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;

  /// Only enabled on Android for now. iOS/Desktop return `false`.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Idempotent. Safe to call multiple times; subsequent calls are
  /// cheap no-ops.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!isSupported) {
      if (kDebugMode) {
        debugPrint('[FCM] disabled on this platform');
      }
      return;
    }

    // Permissions: POST_NOTIFICATIONS is already requested by the
    // first-launch gate via permission_handler. We still call
    // `requestPermission()` so FCM records its own authorization
    // state; on Android 13+ this is a no-op if already granted.
    await _messaging.requestPermission();

    // Ensure foreground messages still surface a notification banner
    // (iOS). On Android this is controlled by the channel importance.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      _handleToken,
      onError: (Object err, StackTrace st) {
        if (kDebugMode) {
          debugPrint('[FCM] token refresh error: $err');
        }
      },
    );

    FirebaseMessaging.onMessage.listen(_foregroundController.add);

    // Fire-and-forget initial fetch; we don't block init on it.
    unawaited(_fetchInitialToken());

    _initialized = true;
  }

  Future<void> _fetchInitialToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _handleToken(token);
      }
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[FCM] getToken failed: $err');
      }
    }
  }

  void _handleToken(String token) {
    _currentToken = token;
    if (kDebugMode) {
      // Only the first 12 chars — the full token is sensitive.
      final preview = token.length <= 12 ? token : token.substring(0, 12);
      debugPrint('[FCM] token=$preview…');
    }
    _tokenController.add(token);
  }

  /// Subscribes to the `media_{anilistId}` topic. No-op if the id is
  /// invalid or the service is not supported on this platform.
  @override
  Future<void> subscribeToMedia(int anilistId) async {
    if (!isSupported) return;
    final topic = mediaTopicForAnilistId(anilistId);
    if (topic == null) return;
    await _messaging.subscribeToTopic(topic);
    if (kDebugMode) {
      debugPrint('[FCM] subscribed topic=$topic');
    }
  }

  /// Unsubscribes from the `media_{anilistId}` topic. Mirrors
  /// [subscribeToMedia] — same no-op conditions.
  @override
  Future<void> unsubscribeFromMedia(int anilistId) async {
    if (!isSupported) return;
    final topic = mediaTopicForAnilistId(anilistId);
    if (topic == null) return;
    await _messaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      debugPrint('[FCM] unsubscribed topic=$topic');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _tokenController.close();
    await _foregroundController.close();
  }
}
