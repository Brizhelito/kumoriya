import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

import '../auth/authenticated_http_client.dart';
import '../auth/secure_token_store.dart';
import '../sync/anonymous_to_auth_migration.dart';
import '../sync/sync_providers.dart';
import '../storage_providers.dart';

const _apiBaseUrl = 'https://api.kumoriya.online';

final secureTokenStoreProvider = Provider<SecureTokenStore>((_) {
  return SecureTokenStore();
});

final authServiceProvider = Provider<AuthService>((_) {
  return HttpAuthService(baseUrl: _apiBaseUrl);
});

final authenticatedHttpClientProvider = Provider<AuthenticatedHttpClient>((ref) {
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

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

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
          return AuthenticatedAuthState(user: user, tokens: newTokens);
        },
        onFailure: (_) async {
          await store.clearAll();
          return const UnauthenticatedAuthState();
        },
      );
    }

    return AuthenticatedAuthState(user: user, tokens: tokens);
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

          // Trigger anonymous → authenticated migration (force-push local data).
          final migration = AnonymousToAuthMigration(
            progressStore: ref.read(animeProgressStoreProvider),
            libraryStore: ref.read(libraryStoreProvider),
            syncQueue: ref.read(syncQueueStoreProvider),
            syncService: ref.read(syncServiceProvider),
          );
          unawaited(migration.migrate());
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
      await authService.logout(
        refreshToken: currentState.tokens.refreshToken,
      );
    }

    final store = ref.read(secureTokenStoreProvider);
    await store.clearAll();
    state = const AsyncData(UnauthenticatedAuthState());
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
