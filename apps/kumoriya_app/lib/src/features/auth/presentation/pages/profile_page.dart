import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/auth/passkey_authenticator.dart';
import '../../../../shared/sync/sync_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import 'login_page.dart';

/// Profile details fetched from the backend.
final _profileDetailsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final isAuth = ref.watch(isAuthenticatedProvider);
      if (!isAuth) return null;

      final client = ref.read(authenticatedHttpClientProvider);
      try {
        final response = await client.getJson('/api/v1/profile');
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
      return null;
    });

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSyncAsync = ref.watch(lastSyncAtProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: KumoriyaColors.background,
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
          backgroundColor: KumoriyaColors.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline,
                size: 64,
                color: KumoriyaColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.profileNotSignedIn,
                style: TextStyle(color: KumoriyaColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _LoginRedirectPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KumoriyaColors.primary,
                  foregroundColor: KumoriyaColors.textPrimary,
                ),
                child: Text(context.l10n.profileSignIn),
              ),
            ],
          ),
        ),
      );
    }

    final profileAsync = ref.watch(_profileDetailsProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        title: Text(context.l10n.profileTitle),
        backgroundColor: KumoriyaColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: KumoriyaColors.statusDanger),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: KumoriyaColors.primaryContainer,
                  backgroundImage: user.avatarUrl != null
                      ? CachedNetworkImageProvider(user.avatarUrl.toString())
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            color: KumoriyaColors.textPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KumoriyaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Linked accounts section
          _SectionHeader(context.l10n.profileLinkedAccounts),
          profileAsync.when(
            data: (profile) {
              final accounts =
                  (profile?['linked_accounts'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              if (accounts.isEmpty) {
                return _EmptyCard(context.l10n.profileNoLinkedAccounts);
              }
              return Column(
                children: accounts.map((a) {
                  return _InfoTile(
                    icon: a['provider'] == 'discord'
                        ? Icons.discord
                        : Icons.account_circle,
                    title:
                        (a['provider'] as String?)?.toUpperCase() ??
                        context.l10n.profileUnknownProvider,
                    subtitle:
                        a['email'] as String? ?? context.l10n.profileNoEmail,
                  );
                }).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, _) =>
                _EmptyCard(context.l10n.profileCouldNotLoadAccounts),
          ),
          const SizedBox(height: 24),

          // Active sessions
          _SectionHeader(context.l10n.profileActiveSessions),
          profileAsync.when(
            data: (profile) {
              final sessions =
                  (profile?['active_sessions'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              if (sessions.isEmpty) {
                return _EmptyCard(context.l10n.profileNoActiveSessions);
              }
              return Column(
                children: sessions.map((s) {
                  return _InfoTile(
                    icon: Icons.devices,
                    title:
                        s['device_name'] as String? ??
                        context.l10n.profileUnknownDevice,
                    subtitle: s['ip_address'] as String? ?? '',
                  );
                }).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, _) =>
                _EmptyCard(context.l10n.profileCouldNotLoadSessions),
          ),
          const SizedBox(height: 24),

          // Registered passkeys
          _SectionHeader(context.l10n.profilePasskeys),
          profileAsync.when(
            data: (profile) {
              final passkeys =
                  (profile?['registered_passkeys'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              return Column(
                children: [
                  if (passkeys.isEmpty)
                    _EmptyCard(context.l10n.profileNoPasskeys)
                  else
                    ...passkeys.map((p) {
                      final id = p['id'] as String? ?? '';
                      return _PasskeyTile(
                        name:
                            p['friendly_name'] as String? ??
                            context.l10n.profileUnnamedPasskey,
                        subtitle: p['created_at'] as String? ?? '',
                        onDelete: id.isEmpty
                            ? null
                            : () => _confirmDeletePasskey(context, ref, id),
                      );
                    }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _registerPasskey(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.l10n.profileRegisterPasskey),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KumoriyaColors.primary,
                        side: const BorderSide(color: KumoriyaColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, _) =>
                _EmptyCard(context.l10n.profileCouldNotLoadPasskeys),
          ),
          const SizedBox(height: 24),

          // Sync status
          _SectionHeader(context.l10n.profileSync),
          _InfoTile(
            icon: Icons.sync,
            title: context.l10n.profileSyncStatus,
            subtitle: syncStatus.name,
          ),
          _InfoTile(
            icon: Icons.schedule,
            title: context.l10n.profileLastSynced,
            subtitle:
                lastSyncAsync.value?.toIso8601String() ??
                context.l10n.profileLastSyncedNever,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                syncStatus == SyncStatus.pushing ||
                    syncStatus == SyncStatus.pulling
                ? null
                : () => ref.read(syncTriggerProvider).fullSync(),
            icon: const Icon(Icons.sync, size: 18),
            label: Text(context.l10n.profileSyncNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
              foregroundColor: KumoriyaColors.textPrimary,
              disabledBackgroundColor: KumoriyaColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 32),

          // Delete account
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref),
              child: Text(
                context.l10n.profileDeleteAccount,
                style: const TextStyle(color: KumoriyaColors.statusDanger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: Text(
          context.l10n.profileLogOut,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
        ),
        content: Text(
          context.l10n.profileLogOutBody,
          style: const TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.profileCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              Navigator.of(context).pop();
            },
            child: Text(
              context.l10n.profileLogOut,
              style: const TextStyle(color: KumoriyaColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: Text(
          context.l10n.profileDeleteAccount,
          style: const TextStyle(color: KumoriyaColors.statusDanger),
        ),
        content: Text(
          context.l10n.profileDeleteAccountWarning,
          style: const TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.profileCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(authenticatedHttpClientProvider);
              await client.deleteRequest('/api/v1/account');
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(
              context.l10n.profileDelete,
              style: const TextStyle(color: KumoriyaColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerPasskey(BuildContext context, WidgetRef ref) async {
    if (!PasskeyAuthenticator.isSupported) {
      _showSnackbar(context, context.l10n.profilePasskeyRegisterFailed);
      return;
    }

    // 1) Ask for a friendly name.
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: Text(
          context.l10n.profilePasskeyNameTitle,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
          decoration: InputDecoration(
            hintText: context.l10n.profilePasskeyNameHint,
            hintStyle: const TextStyle(color: KumoriyaColors.textMuted),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.profileCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
              foregroundColor: KumoriyaColors.textPrimary,
            ),
            child: Text(context.l10n.profilePasskeyNameContinue),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty || !context.mounted) return;

    // 2) Begin registration on server — get CredentialCreation options.
    final client = ref.read(authenticatedHttpClientProvider);
    try {
      final beginResp = await client.postJson(
        '/auth/passkeys/register/begin',
        body: {'friendly_name': name},
      );
      if (beginResp.statusCode != 200) {
        _showSnackbar(context, context.l10n.profilePasskeyRegisterFailed);
        return;
      }

      // 3) Call platform authenticator with the server options.
      final attestationJson = await PasskeyAuthenticator.create(beginResp.body);

      // 4) Send attestation response to server to complete registration.
      final finishResp = await client.postJson(
        '/auth/passkeys/register/finish',
        body: jsonDecode(attestationJson),
      );

      if (!context.mounted) return;
      if (finishResp.statusCode == 200) {
        ref.invalidate(_profileDetailsProvider);
        _showSnackbar(context, context.l10n.profilePasskeyRegistered);
      } else {
        developer.log(
          'passkey register finish ${finishResp.statusCode}: ${finishResp.body}',
          name: 'kumoriya.profile',
        );
        _showSnackbar(context, context.l10n.profilePasskeyRegisterFailed);
      }
    } on PlatformException catch (e) {
      developer.log(
        'passkey platform error: ${e.code} - ${e.message}',
        name: 'kumoriya.profile',
      );
      if (context.mounted && e.code != 'CANCELLED') {
        _showSnackbar(context, context.l10n.profilePasskeyRegisterFailed);
      }
    } catch (e) {
      developer.log('passkey register error: $e', name: 'kumoriya.profile');
      if (context.mounted) {
        _showSnackbar(context, context.l10n.profilePasskeyRegisterFailed);
      }
    }
  }

  void _confirmDeletePasskey(
    BuildContext context,
    WidgetRef ref,
    String passkeyId,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: Text(
          context.l10n.profilePasskeyDeleteTitle,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
        ),
        content: Text(
          context.l10n.profilePasskeyDeleteBody,
          style: const TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.profileCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deletePasskey(context, ref, passkeyId);
            },
            child: Text(
              context.l10n.profileDelete,
              style: const TextStyle(color: KumoriyaColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePasskey(
    BuildContext context,
    WidgetRef ref,
    String passkeyId,
  ) async {
    final client = ref.read(authenticatedHttpClientProvider);
    try {
      final resp = await client.deleteRequest('/auth/passkeys/$passkeyId');
      if (!context.mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        ref.invalidate(_profileDetailsProvider);
        _showSnackbar(context, context.l10n.profilePasskeyDeleted);
      } else {
        _showSnackbar(context, context.l10n.profilePasskeyDeleteFailed);
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackbar(context, context.l10n.profilePasskeyDeleteFailed);
      }
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginRedirectPage extends StatelessWidget {
  const _LoginRedirectPage();

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: KumoriyaColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: KumoriyaColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasskeyTile extends StatelessWidget {
  const _PasskeyTile({
    required this.name,
    required this.subtitle,
    this.onDelete,
  });
  final String name;
  final String subtitle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.key, color: KumoriyaColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: KumoriyaColors.statusDanger,
                size: 20,
              ),
              onPressed: onDelete,
              tooltip: context.l10n.profileDelete,
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: KumoriyaColors.textMuted),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KumoriyaColors.primary,
          ),
        ),
      ),
    );
  }
}
