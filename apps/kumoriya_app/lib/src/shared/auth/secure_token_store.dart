import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

/// Persists [TokenPair] and user ID in platform-secure storage.
final class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyAccess = 'auth_access_token';
  static const _keyRefresh = 'auth_refresh_token';
  static const _keyExpires = 'auth_expires_at';
  static const _keyUserId = 'auth_user_id';
  static const _keyDisplayName = 'auth_display_name';
  static const _keyAvatarUrl = 'auth_avatar_url';
  static const _keyLastSyncAt = 'sync_last_sync_at';

  Future<void> saveTokens(TokenPair tokens) async {
    await _storage.write(key: _keyAccess, value: tokens.accessToken);
    await _storage.write(key: _keyRefresh, value: tokens.refreshToken);
    await _storage.write(
      key: _keyExpires,
      value: tokens.expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<TokenPair?> loadTokens() async {
    final access = await _storage.read(key: _keyAccess);
    final refresh = await _storage.read(key: _keyRefresh);
    final expiresStr = await _storage.read(key: _keyExpires);
    if (access == null || refresh == null || expiresStr == null) return null;
    final expiresMs = int.tryParse(expiresStr);
    if (expiresMs == null) return null;
    return TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresMs),
    );
  }

  Future<void> saveUser(AuthUser user) async {
    await _storage.write(key: _keyUserId, value: user.id);
    await _storage.write(key: _keyDisplayName, value: user.displayName);
    if (user.avatarUrl != null) {
      await _storage.write(key: _keyAvatarUrl, value: user.avatarUrl.toString());
    }
  }

  Future<AuthUser?> loadUser() async {
    final id = await _storage.read(key: _keyUserId);
    final name = await _storage.read(key: _keyDisplayName);
    if (id == null || name == null) return null;
    final avatarStr = await _storage.read(key: _keyAvatarUrl);
    return AuthUser(
      id: id,
      displayName: name,
      avatarUrl: avatarStr != null ? Uri.tryParse(avatarStr) : null,
    );
  }

  Future<void> saveLastSyncAt(DateTime time) async {
    await _storage.write(
      key: _keyLastSyncAt,
      value: time.millisecondsSinceEpoch.toString(),
    );
  }

  Future<DateTime?> loadLastSyncAt() async {
    final str = await _storage.read(key: _keyLastSyncAt);
    if (str == null) return null;
    final ms = int.tryParse(str);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
    await _storage.delete(key: _keyExpires);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyDisplayName);
    await _storage.delete(key: _keyAvatarUrl);
    await _storage.delete(key: _keyLastSyncAt);
  }
}
