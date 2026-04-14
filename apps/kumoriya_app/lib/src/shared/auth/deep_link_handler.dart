import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/oauth_callback_page.dart';
import '../../features/watch_party/presentation/pages/party_lobby_page.dart';

/// Listens for incoming deep links and navigates accordingly.
///
/// Supported schemes:
/// - `kumoriya://auth/callback?…` → OAuth callback
/// - `kumoriya://party/join?code=XXXX` → Watch party invite
///
/// Must be initialised once from a widget that holds a root [NavigatorState].
class DeepLinkHandler {
  DeepLinkHandler({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Callback invoked when a party invite deep link is received.
  /// Set this from the widget that creates the handler.
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
    if (uri.scheme != 'kumoriya') return;

    // OAuth callback.
    if (uri.host == 'auth' && uri.path.startsWith('/callback')) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => OAuthCallbackPage(callbackUri: uri),
        ),
      );
      return;
    }

    // Watch party invite: kumoriya://party/join?code=XXXX
    if (uri.host == 'party' && uri.path.startsWith('/join')) {
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) return;

      if (onPartyInvite != null) {
        onPartyInvite!(code);
      } else {
        // Fallback: navigate to lobby page.
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const PartyLobbyPage(),
          ),
        );
      }
    }
  }
}
