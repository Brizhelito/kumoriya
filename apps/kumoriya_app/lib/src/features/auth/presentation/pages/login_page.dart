import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  String? _error;

  Future<void> _loginWith(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.beginOAuthLogin(
      provider: provider,
      callbackUri: Uri.parse('kumoriya://auth/callback'),
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
            _error = 'Could not open browser';
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
                'Welcome to Kumoriya',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to sync your progress across devices',
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
                label: 'Continue with Discord',
                icon: Icons.discord,
                backgroundColor: const Color(0xFF5865F2),
                onPressed: _loading ? null : () => _loginWith(OAuthProvider.discord),
              ),
              const SizedBox(height: 12),
              _OAuthButton(
                label: 'Continue with Google',
                icon: Icons.account_circle,
                backgroundColor: KumoriyaColors.surface,
                onPressed: _loading ? null : () => _loginWith(OAuthProvider.google),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(
                    color: KumoriyaColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: KumoriyaColors.textMuted,
                  ),
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
