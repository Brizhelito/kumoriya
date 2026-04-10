import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/auth_service.dart';
import '../models/auth_state.dart';
import '../models/oauth_provider.dart';
import '../models/token_pair.dart';
import '../models/user.dart';

/// Concrete [AuthService] that talks to the Kumoriya Go backend over HTTP.
final class HttpAuthService implements AuthService {
  HttpAuthService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<Result<Uri, KumoriyaError>> beginOAuthLogin({
    required OAuthProvider provider,
    required Uri callbackUri,
    String? deviceName,
  }) async {
    try {
      final providerName = provider == OAuthProvider.discord
          ? 'discord'
          : 'google';
      final queryParams = <String, String>{
        'redirect_uri': callbackUri.toString(),
        if (deviceName != null) 'device_name': deviceName,
      };
      final uri = Uri.parse(
        '$_baseUrl/auth/oauth/$providerName',
      ).replace(queryParameters: queryParams);

      // We need to get the redirect URL without following it.
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request);

      // Accept any redirect status (301, 302, 303, 307, 308)
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        if (location != null) {
          return Success(Uri.parse(location));
        }
      }

      return const Failure(
        SimpleError(
          code: 'auth.oauth.no_redirect',
          message: 'Server did not return a redirect URL',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'auth.oauth.begin_failed',
          message: 'Failed to begin OAuth: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  @override
  Future<Result<AuthState, KumoriyaError>> completeOAuthLogin(
    Uri callbackUri,
  ) async {
    try {
      final accessToken = callbackUri.queryParameters['access_token'];
      final refreshToken = callbackUri.queryParameters['refresh_token'];
      final expiresIn = callbackUri.queryParameters['expires_in'];
      final userId = callbackUri.queryParameters['user_id'];

      if (accessToken == null || refreshToken == null || userId == null) {
        final error = callbackUri.queryParameters['error'];
        return Failure(
          SimpleError(
            code: 'auth.oauth.incomplete',
            message: error ?? 'Missing tokens in callback',
            kind: KumoriyaErrorKind.unexpected,
          ),
        );
      }

      final expiresSeconds = int.tryParse(expiresIn ?? '900') ?? 900;
      final tokens = TokenPair(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresSeconds)),
      );

      // Fetch user profile with the new token.
      final userResult = await _fetchProfile(accessToken);
      return userResult.fold(
        onSuccess: (user) =>
            Success(AuthenticatedAuthState(user: user, tokens: tokens)),
        onFailure: (error) => Failure(error),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'auth.oauth.complete_failed',
          message: 'Failed to complete OAuth: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  @override
  Future<Result<TokenPair, KumoriyaError>> refreshToken({
    required String userId,
    required String refreshToken,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(
          TokenPair(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
            expiresAt: DateTime.now().add(
              Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 900),
            ),
          ),
        );
      }

      if (response.statusCode == 401) {
        return const Failure(
          SimpleError(
            code: 'auth.refresh.expired',
            message: 'Session expired, please log in again',
            kind: KumoriyaErrorKind.cancelled,
          ),
        );
      }

      return Failure(
        SimpleError(
          code: 'auth.refresh.failed',
          message: 'Refresh failed: ${response.statusCode}',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'auth.refresh.transport',
          message: 'Network error during refresh: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> beginPasskeyRegistration() async {
    // Passkey registration requires platform authenticator APIs.
    // This is a stub — full implementation needs webauthn client library.
    return const Failure(
      SimpleError(
        code: 'auth.passkey.not_implemented',
        message: 'Passkey registration not yet implemented on client',
        kind: KumoriyaErrorKind.unexpected,
      ),
    );
  }

  @override
  Future<Result<void, KumoriyaError>> finishPasskeyRegistration(
    Object payload,
  ) async {
    return const Failure(
      SimpleError(
        code: 'auth.passkey.not_implemented',
        message: 'Passkey registration not yet implemented on client',
        kind: KumoriyaErrorKind.unexpected,
      ),
    );
  }

  @override
  Future<Result<void, KumoriyaError>> beginPasskeyAuthentication({
    required String userId,
  }) async {
    return const Failure(
      SimpleError(
        code: 'auth.passkey.not_implemented',
        message: 'Passkey authentication not yet implemented on client',
        kind: KumoriyaErrorKind.unexpected,
      ),
    );
  }

  @override
  Future<Result<AuthState, KumoriyaError>> finishPasskeyAuthentication({
    required String userId,
    required Object payload,
    String? deviceName,
  }) async {
    return const Failure(
      SimpleError(
        code: 'auth.passkey.not_implemented',
        message: 'Passkey authentication not yet implemented on client',
        kind: KumoriyaErrorKind.unexpected,
      ),
    );
  }

  @override
  Future<Result<AuthUser?, KumoriyaError>> getCurrentUser() async {
    // This is called at app startup to check persisted state.
    // The actual user data is loaded from secure storage by the provider layer.
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> logout({
    required String refreshToken,
  }) async {
    try {
      // Fire and forget — server revokes session.
      await _client.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      return const Success(null);
    } catch (_) {
      // Best-effort: even if server call fails, client clears local state.
      return const Success(null);
    }
  }

  Future<Result<AuthUser, KumoriyaError>> _fetchProfile(
    String accessToken,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/profile'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;
        return Success(
          AuthUser(
            id: userData['id'] as String,
            displayName: userData['display_name'] as String,
            avatarUrl: userData['avatar_url'] != null
                ? Uri.tryParse(userData['avatar_url'] as String)
                : null,
          ),
        );
      }

      return Failure(
        SimpleError(
          code: 'auth.profile.fetch_failed',
          message: 'Failed to fetch profile: ${response.statusCode}',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'auth.profile.transport',
          message: 'Network error fetching profile: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }
}
