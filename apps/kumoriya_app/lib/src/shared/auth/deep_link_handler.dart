import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/oauth_callback_page.dart';
import '../../features/watch_party/presentation/pages/party_lobby_page.dart';

/// Listens for incoming deep links and navigates accordingly.
///
/// Supported URIs:
/// - `kumoriya://auth/callback?…` → OAuth callback
/// - `kumoriya://party/join?code=XXXX` → Watch party invite (custom scheme)
/// - `https://join.kumoriya.online/XXXX` → Watch party invite (verified App Link)
///
/// Must be initialised once from a widget that holds a root [NavigatorState].
class DeepLinkHandler {
  DeepLinkHandler({required this.navigatorKey});

  static const String _partyHostHttps = 'join.kumoriya.online';

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Callback invoked when a party invite deep link is received.
  /// If null, the handler falls back to pushing [PartyLobbyPage] with an
  /// `autoJoinCode` so the lobby joins the room automatically on mount.
  void Function(String inviteCode)? onPartyInvite;

  /// Start listening. Call once from a top-level StatefulWidget's initState.
  void init() {
    // Handle link that launched the app (cold start).
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onLink(uri);
    });

    // Handle links while the app is running (warm start).
    _sub = _appLinks.uriLinkStream.listen(_onLink);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _onLink(Uri uri) {
    // OAuth callback (custom scheme only).
    if (uri.scheme == 'kumoriya' &&
        uri.host == 'auth' &&
        uri.path.startsWith('/callback')) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => OAuthCallbackPage(callbackUri: uri),
        ),
      );
      return;
    }

    final inviteCode = _extractInviteCode(uri);
    if (inviteCode != null) {
      _routeToParty(inviteCode);
    }
  }

  /// Returns a normalised invite code if [uri] matches any supported
  /// watch-party invite format, otherwise null.
  String? _extractInviteCode(Uri uri) {
    // kumoriya://party/join?code=XXXX
    if (uri.scheme == 'kumoriya' &&
        uri.host == 'party' &&
        uri.path.startsWith('/join')) {
      return _normaliseCode(uri.queryParameters['code']);
    }

    // https://join.kumoriya.online/XXXX (first non-empty path segment).
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.toLowerCase() == _partyHostHttps) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return _normaliseCode(segments.first);
      }
      // Also accept ?code=XXXX for defensive compatibility with any link
      // builder that falls back to query strings.
      return _normaliseCode(uri.queryParameters['code']);
    }

    return null;
  }

  static String? _normaliseCode(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return cleaned.isEmpty ? null : cleaned;
  }

  void _routeToParty(String inviteCode) {
    if (onPartyInvite != null) {
      onPartyInvite!(inviteCode);
      return;
    }
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Collapse the stack so the lobby becomes the visible route and the
    // user isn't stuck under whatever was on top before the link arrived.
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PartyLobbyPage(autoJoinCode: inviteCode),
      ),
    );
  }
}
