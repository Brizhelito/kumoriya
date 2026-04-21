import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

import '../auth/authenticated_http_client.dart';
import '../auth/secure_token_store.dart';
import '../notifications/fcm_providers.dart';
import '../notifications/fcm_topic_sync_service.dart';
import '../sync/anonymous_to_auth_migration.dart';
import '../sync/local_user_data_cleaner.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_refresh.dart';
import '../storage_providers.dart';

const _apiBaseUrl = 'https://api.kumoriya.online';

final secureTokenStoreProvider = Provider<SecureTokenStore>((_) {
  return SecureTokenStore();
});

final authServiceProvider = Provider<AuthService>((_) {
  return HttpAuthService(baseUrl: _apiBaseUrl);
});

final authenticatedHttpClientProvider = Provider<AuthenticatedHttpClient>((
  ref,
) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  final client = AuthenticatedHttpClient(
    tokenStore: tokenStore,
    baseUrl: _apiBaseUrl,
  );

  // Wire up refresh callback.
  client.onRefreshToken = () async {
    final store = ref.read(secureTokenStoreProvider);
    final tokens = await store.loadTokens();
    final user = await store.loadUser();
    if (tokens == null || user == null) return null;

    final authService = ref.read(authServiceProvider);
    final result = await authService.refreshToken(
      userId: user.id,
      refreshToken: tokens.refreshToken,
    );
    return result.fold(
      onSuccess: (newTokens) => newTokens,
      onFailure: (_) => null,
    );
  };

  client.onAuthExpired = () {
    ref.read(authStateProvider.notifier).logout();
  };

  return client;
});

final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final store = ref.read(secureTokenStoreProvider);
    final tokens = await store.loadTokens();
    final user = await store.loadUser();

    if (tokens == null || user == null) {
      return const UnauthenticatedAuthState();
    }

    // If tokens are expired, try refreshing.
    if (tokens.isExpired) {
      final authService = ref.read(authServiceProvider);
      final result = await authService.refreshToken(
        userId: user.id,
        refreshToken: tokens.refreshToken,
      );
      return result.fold(
        onSuccess: (newTokens) async {
          await store.saveTokens(newTokens);
          _scheduleTopicSync();
          return AuthenticatedAuthState(user: user, tokens: newTokens);
        },
        onFailure: (_) async {
          await store.clearAll();
          return const UnauthenticatedAuthState();
        },
      );
    }

    _scheduleTopicSync();
    return AuthenticatedAuthState(user: user, tokens: tokens);
  }

  /// Fires FCM topic reconciliation in the background. Used on app boot
  /// for already-authenticated sessions so topics survive app data
  /// wipes, Firebase token rotations, or reinstalls on the same device.
  /// Best-effort; failures are swallowed.
  ///
  /// Deferred to a microtask so this runs AFTER [build] has returned and
  /// Riverpod has fully propagated the AsyncNotifier's future resolution
  /// to every listener. Reading providers synchronously from within
  /// [build] would trigger `libraryStoreProvider` initialization in the
  /// same frame the AsyncNotifier is settling, which can interleave with
  /// listener notification and surface unrelated defunct-element races.
  void _scheduleTopicSync() {
    Future.microtask(() async {
      try {
        final topicSync = FcmTopicSyncService(
          libraryStore: ref.read(libraryStoreProvider),
          fcm: ref.read(fcmServiceProvider),
        );
        await topicSync.syncTopicsWithLibrary();
      } catch (_) {
        // Next boot or login will retry.
      }
    });
  }

  Future<void> onOAuthCallback(Uri callbackUri) async {
    state = const AsyncLoading();
    final authService = ref.read(authServiceProvider);
    final result = await authService.completeOAuthLogin(callbackUri);

    await result.fold(
      onSuccess: (authState) async {
        if (authState is AuthenticatedAuthState) {
          final store = ref.read(secureTokenStoreProvider);
          await store.saveTokens(authState.tokens);
          await store.saveUser(authState.user);

          // Flip authenticated state first so SyncAware wrappers begin
          // routing further writes to the sync queue while migration runs.
          state = AsyncData(authState);

          // Anonymous → authenticated migration: force-push everything that
          // was stored locally while the user was signed out, then pull the
          // server state. Runs in the background so the UI is not blocked.
          final migration = AnonymousToAuthMigration(
            progressStore: ref.read(animeProgressStoreProvider),
            libraryStore: ref.read(libraryStoreProvider),
            syncQueue: ref.read(syncQueueStoreProvider),
            syncService: ref.read(syncServiceProvider),
          );
          unawaited(
            migration.migrate().then((_) async {
              ref.read(syncDataRefreshEpochProvider.notifier).bump();

              // Reconcile FCM topic subscriptions with whatever the
              // server just pulled down. Idempotent; a failure here
              // does not block the login flow.
              try {
                final topicSync = FcmTopicSyncService(
                  libraryStore: ref.read(libraryStoreProvider),
                  fcm: ref.read(fcmServiceProvider),
                );
                await topicSync.syncTopicsWithLibrary();
              } catch (_) {
                // Best-effort; next login or app-start will retry.
              }
            }),
          );
          return;
        }
        state = AsyncData(authState);
      },
      onFailure: (error) async {
        state = AsyncError(error, StackTrace.current);
      },
    );
  }

  Future<void> logout() async {
    final currentState = state.value;
    if (currentState is AuthenticatedAuthState) {
      final authService = ref.read(authServiceProvider);
      await authService.logout(refreshToken: currentState.tokens.refreshToken);
    }

    // Wipe user-scoped local data BEFORE flipping auth state so SyncAware
    // wrappers do not enqueue deletions against the account being signed
    // out of. Also prevents leakage to a different account on next login.
    final cleaner = LocalUserDataCleaner(
      progressStore: ref.read(animeProgressStoreProvider),
      libraryStore: ref.read(libraryStoreProvider),
      syncQueue: ref.read(syncQueueStoreProvider),
    );
    await cleaner.wipe();

    final store = ref.read(secureTokenStoreProvider);
    await store.clearAll();
    state = const AsyncData(UnauthenticatedAuthState());

    ref.read(syncDataRefreshEpochProvider.notifier).bump();
    ref.invalidate(lastSyncAtProvider);
  }
}

final currentUserProvider = Provider<AuthUser?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState is AuthenticatedAuthState) {
    return authState.user;
  }
  return null;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
