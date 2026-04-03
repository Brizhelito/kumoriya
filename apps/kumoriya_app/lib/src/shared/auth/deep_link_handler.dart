import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/oauth_callback_page.dart';

/// Listens for incoming deep links (`kumoriya://auth/callback?…`) and
/// navigates to [OAuthCallbackPage] when an OAuth redirect arrives.
///
/// Must be initialised once from a widget that holds a root [NavigatorState].
class DeepLinkHandler {
  DeepLinkHandler({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

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
    }
  }
}
