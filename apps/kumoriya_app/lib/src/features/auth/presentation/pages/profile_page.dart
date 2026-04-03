import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/sync/sync_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

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
          title: const Text('Profile'),
          backgroundColor: KumoriyaColors.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 64, color: KumoriyaColors.textMuted),
              const SizedBox(height: 16),
              Text('Not signed in', style: TextStyle(color: KumoriyaColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const _LoginRedirectPage(),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KumoriyaColors.primary,
                  foregroundColor: KumoriyaColors.textPrimary,
                ),
                child: const Text('Sign In'),
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
        title: const Text('Profile'),
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
          _SectionHeader('Linked Accounts'),
          profileAsync.when(
            data: (profile) {
              final accounts =
                  (profile?['linked_accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (accounts.isEmpty) {
                return const _EmptyCard('No linked accounts');
              }
              return Column(
                children: accounts.map((a) {
                  return _InfoTile(
                    icon: a['provider'] == 'discord' ? Icons.discord : Icons.account_circle,
                    title: (a['provider'] as String?)?.toUpperCase() ?? 'Unknown',
                    subtitle: a['email'] as String? ?? 'No email',
                  );
                }).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, __) => const _EmptyCard('Could not load accounts'),
          ),
          const SizedBox(height: 24),

          // Active sessions
          _SectionHeader('Active Sessions'),
          profileAsync.when(
            data: (profile) {
              final sessions =
                  (profile?['active_sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (sessions.isEmpty) {
                return const _EmptyCard('No active sessions');
              }
              return Column(
                children: sessions.map((s) {
                  return _InfoTile(
                    icon: Icons.devices,
                    title: s['device_name'] as String? ?? 'Unknown device',
                    subtitle: s['ip_address'] as String? ?? '',
                  );
                }).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, __) => const _EmptyCard('Could not load sessions'),
          ),
          const SizedBox(height: 24),

          // Registered passkeys
          _SectionHeader('Passkeys'),
          profileAsync.when(
            data: (profile) {
              final passkeys =
                  (profile?['registered_passkeys'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (passkeys.isEmpty) {
                return const _EmptyCard('No passkeys registered');
              }
              return Column(
                children: passkeys.map((p) {
                  return _InfoTile(
                    icon: Icons.key,
                    title: p['friendly_name'] as String? ?? 'Unnamed passkey',
                    subtitle: p['created_at'] as String? ?? '',
                  );
                }).toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (_, __) => const _EmptyCard('Could not load passkeys'),
          ),
          const SizedBox(height: 24),

          // Sync status
          _SectionHeader('Sync'),
          _InfoTile(
            icon: Icons.sync,
            title: 'Status',
            subtitle: syncStatus.name,
          ),
          _InfoTile(
            icon: Icons.schedule,
            title: 'Last synced',
            subtitle: lastSyncAsync.value?.toIso8601String() ?? 'Never',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: syncStatus == SyncStatus.pushing || syncStatus == SyncStatus.pulling
                ? null
                : () => ref.read(syncTriggerProvider).fullSync(),
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Sync now'),
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
              child: const Text(
                'Delete Account',
                style: TextStyle(color: KumoriyaColors.statusDanger),
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
        title: const Text('Log out', style: TextStyle(color: KumoriyaColors.textPrimary)),
        content: const Text(
          'Your local data will be kept.',
          style: TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              Navigator.of(context).pop();
            },
            child: const Text('Log out', style: TextStyle(color: KumoriyaColors.statusDanger)),
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
        title: const Text('Delete Account', style: TextStyle(color: KumoriyaColors.statusDanger)),
        content: const Text(
          'This will permanently delete your account and all synced data. This cannot be undone.',
          style: TextStyle(color: KumoriyaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(authenticatedHttpClientProvider);
              await client.deleteRequest('/api/v1/account');
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: KumoriyaColors.statusDanger)),
          ),
        ],
      ),
    );
  }
}

class _LoginRedirectPage extends StatelessWidget {
  const _LoginRedirectPage();

  @override
  Widget build(BuildContext context) {
    // Lazy import to avoid circular.
    return const Placeholder(); // Will be replaced with actual LoginPage push.
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
                Text(title, style: const TextStyle(color: KumoriyaColors.textPrimary, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: KumoriyaColors.textMuted, fontSize: 12)),
                ],
              ],
            ),
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
        child: Text(message, style: const TextStyle(color: KumoriyaColors.textMuted)),
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
          child: CircularProgressIndicator(strokeWidth: 2, color: KumoriyaColors.primary),
        ),
      ),
    );
  }
}
