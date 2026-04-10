import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_auth/kumoriya_auth.dart';

import 'secure_token_store.dart';

/// HTTP client that automatically attaches JWT access tokens and refreshes
/// on 401 responses. Uses a single retry per request to avoid loops.
final class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    required SecureTokenStore tokenStore,
    required String baseUrl,
    http.Client? inner,
  }) : _tokenStore = tokenStore,
       _baseUrl = baseUrl,
       _inner = inner ?? http.Client();

  final SecureTokenStore _tokenStore;
  final String _baseUrl;
  final http.Client _inner;

  /// Callback set by the auth provider to perform token refresh.
  /// Returns new [TokenPair] or null on failure (forces re-login).
  Future<TokenPair?> Function()? onRefreshToken;

  /// Callback when refresh fails — user must re-authenticate.
  void Function()? onAuthExpired;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final tokens = await _tokenStore.loadTokens();
    if (tokens != null) {
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    request.headers['Content-Type'] ??= 'application/json';

    var response = await _inner.send(request);

    if (response.statusCode == 401 && onRefreshToken != null) {
      final newTokens = await onRefreshToken!();
      if (newTokens != null) {
        await _tokenStore.saveTokens(newTokens);
        // Retry with new token - must create a new request copy
        final retryRequest = _copyRequest(request, newTokens.accessToken);
        response = await _inner.send(retryRequest);
      } else {
        onAuthExpired?.call();
      }
    }

    return response;
  }

  /// Convenience: GET with base URL prepended.
  Future<http.Response> getJson(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    return http.Response.fromStream(await send(http.Request('GET', uri)));
  }

  /// Convenience: POST JSON with base URL prepended.
  Future<http.Response> postJson(String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('POST', uri);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return http.Response.fromStream(await send(request));
  }

  /// Convenience: PATCH JSON with base URL prepended.
  Future<http.Response> patchJson(String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('PATCH', uri);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return http.Response.fromStream(await send(request));
  }

  /// Convenience: DELETE with base URL prepended.
  Future<http.Response> deleteRequest(String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return http.Response.fromStream(await send(request));
  }

  http.BaseRequest _copyRequest(http.BaseRequest original, String accessToken) {
    final copy = http.Request(original.method, original.url);
    copy.headers.addAll(original.headers);
    copy.headers['Authorization'] = 'Bearer $accessToken';
    if (original is http.Request) {
      copy.body = original.body;
    }
    return copy;
  }

  @override
  void close() {
    _inner.close();
  }
}
