import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

/// Screen shown after OAuth provider redirects back.
/// Displays a loading spinner while tokens are exchanged (cold start can take 3-4s).
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key, required this.callbackUri});

  final Uri callbackUri;

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  bool _processed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    if (_processed) return;
    _processed = true;

    await ref
        .read(authStateProvider.notifier)
        .onOAuthCallback(widget.callbackUri);

    if (!mounted) return;

    final authState = ref.read(authStateProvider).value;
    if (authState is AuthenticatedAuthState) {
      // Success — pop back to where we came from.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // Error — go back to login.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authAsync.hasError)
              Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: KumoriyaColors.statusDanger,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.authLoginFailed,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${authAsync.error}',
                    style: const TextStyle(color: KumoriyaColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.authGoBack),
                  ),
                ],
              )
            else ...[
              const CircularProgressIndicator(
                color: KumoriyaColors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.authConnecting,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: KumoriyaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authMayTakeSeconds,
                style: TextStyle(color: KumoriyaColors.textMuted),
              ),
              const SizedBox(height: 24),
              // Escape hatch: if the server hangs or the network is slow we
              // let the user back out to the login page. The in-flight
              // `completeOAuthLogin` request is not aborted (the auth
              // notifier keeps running in the background); if it eventually
              // succeeds the app will reflect the authenticated state on the
              // next build. The user is not trapped in a loading screen.
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  context.l10n.profileCancel,
                  style: TextStyle(color: KumoriyaColors.statusDanger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
