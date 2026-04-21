import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/auth/device_id_provider.dart';
import '../../../../shared/auth/device_name_provider.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  String? _error;

  void _cancelLogin() {
    // Resets the local waiting state so the user is not trapped when the
    // browser is closed without completing OAuth, the deep-link never fires,
    // or the provider page silently fails. We intentionally do not try to
    // cancel the already-issued /auth/oauth/begin HTTP request: it has
    // already completed by the time we reach the waiting state (we are only
    // waiting for the deep-link callback from the external browser).
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loginWith(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final deviceName = await ref.read(deviceNameProvider.future);
    final deviceId = await ref.read(deviceIdProvider.future);
    final result = await authService.beginOAuthLogin(
      provider: provider,
      callbackUri: Uri.parse('kumoriya://auth/callback'),
      deviceName: deviceName,
      deviceId: deviceId,
    );

    result.fold(
      onSuccess: (uri) async {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          setState(() {
            _loading = false;
            _error = context.l10n.authCouldNotOpenBrowser;
          });
        }
        // Keep loading state — callback will resolve via deep link.
      },
      onFailure: (error) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = error.message;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KumoriyaColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KumoriyaColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'K',
                  style: TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.authLoginWelcomeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authLoginSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KumoriyaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: KumoriyaColors.statusDanger),
                    textAlign: TextAlign.center,
                  ),
                ),
              _OAuthButton(
                label: context.l10n.authContinueWithDiscord,
                icon: Icons.discord,
                backgroundColor: const Color(0xFF5865F2),
                onPressed: _loading
                    ? null
                    : () => _loginWith(OAuthProvider.discord),
              ),
              const SizedBox(height: 12),
              _OAuthButton(
                label: context.l10n.authContinueWithGoogle,
                icon: Icons.account_circle,
                backgroundColor: KumoriyaColors.surface,
                onPressed: _loading
                    ? null
                    : () => _loginWith(OAuthProvider.google),
              ),
              const SizedBox(height: 24),
              if (_loading) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CircularProgressIndicator(
                    color: KumoriyaColors.primary,
                    strokeWidth: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    context.l10n.authWaitingForBrowser,
                    style: TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _cancelLogin,
                  child: Text(
                    context.l10n.authCancelLogin,
                    style: TextStyle(color: KumoriyaColors.statusDanger),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.authSkipForNow,
                  style: TextStyle(color: KumoriyaColors.textMuted),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: KumoriyaColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
