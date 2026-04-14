import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Dart wrapper around the Android Credential Manager passkey platform channel.
///
/// On non-Android platforms the methods throw [UnsupportedError].
class PasskeyAuthenticator {
  static const _channel = MethodChannel('dev.kumoriya.app/passkey');

  /// Calls the platform authenticator to create a new passkey credential.
  ///
  /// [optionsJson] is the raw JSON string returned by the server's
  /// `/auth/passkeys/register/begin` endpoint (the `CredentialCreation` object).
  /// The server wraps the options in `{"publicKey": {...}}` per the WebAuthn
  /// spec, but Android Credential Manager expects only the inner object.
  ///
  /// Returns the attestation response JSON to send to `/register/finish`.
  static Future<String> create(String optionsJson) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Passkeys are only supported on Android');
    }
    final result = await _channel.invokeMethod<String>('create', {
      'options': _extractPublicKey(optionsJson),
    });
    if (result == null) {
      throw PlatformException(
        code: 'NO_RESPONSE',
        message: 'Platform returned null attestation response',
      );
    }
    return result;
  }

  /// Calls the platform authenticator to authenticate with an existing passkey.
  ///
  /// [optionsJson] is the raw JSON string returned by the server's
  /// `/auth/passkeys/authenticate/begin` endpoint (the `CredentialAssertion`
  /// object). The server wraps it in `{"publicKey": {...}}` — Android expects
  /// only the inner object.
  ///
  /// Returns the assertion response JSON to send to `/authenticate/finish`.
  static Future<String> get(String optionsJson) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Passkeys are only supported on Android');
    }
    final result = await _channel.invokeMethod<String>('get', {
      'options': _extractPublicKey(optionsJson),
    });
    if (result == null) {
      throw PlatformException(
        code: 'NO_RESPONSE',
        message: 'Platform returned null assertion response',
      );
    }
    return result;
  }

  /// Whether passkeys are supported on the current platform.
  static bool get isSupported => Platform.isAndroid;

  /// Extracts the inner `publicKey` object from a go-webauthn JSON response.
  ///
  /// go-webauthn wraps the options as `{"publicKey": {...}}` per the WebAuthn
  /// spec, but Android Credential Manager expects only the inner object.
  /// If the JSON doesn't have a `publicKey` key, returns the original string.
  static String _extractPublicKey(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic> && decoded.containsKey('publicKey')) {
        return jsonEncode(decoded['publicKey']);
      }
    } catch (_) {}
    return json;
  }
}
