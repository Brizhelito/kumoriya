import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/sync/sync_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import 'login_page.dart';

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    return DateFormat.yMMMd().format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _formatRelativeTime(BuildContext context, DateTime dt, String locale) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) {
    return l10n.profileTimeJustNow;
  } else if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    final unit = m == 1
        ? l10n.profileTimeMinuteSingular
        : l10n.profileTimeMinutePlural;
    return l10n.profileTimeMinutesAgo(m, unit);
  } else if (diff.inHours < 24) {
    final h = diff.inHours;
    final unit = h == 1
        ? l10n.profileTimeHourSingular
        : l10n.profileTimeHourPlural;
    return l10n.profileTimeHoursAgo(h, unit);
  } else if (diff.inDays < 7) {
    final d = diff.inDays;
    final unit = d == 1
        ? l10n.profileTimeDaySingular
        : l10n.profileTimeDayPlural;
    return l10n.profileTimeDaysAgo(d, unit);
  } else {
    return DateFormat.yMMMd(locale).format(dt.toLocal());
  }
}

String _syncStatusLabel(BuildContext context, SyncStatus status) {
  return switch (status) {
    SyncStatus.idle => context.l10n.profileSyncIdle,
    SyncStatus.pushing => context.l10n.profileSyncPushing,
    SyncStatus.pulling => context.l10n.profileSyncPulling,
    SyncStatus.success => context.l10n.profileSyncSuccess,
    SyncStatus.failed => context.l10n.profileSyncFailed,
  };
}

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

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ProfileHeaderCard(user: user),
          const SizedBox(height: 16),

          // Sync card
          _SectionCard(
            title: context.l10n.profileSync,
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.sync,
                  title: context.l10n.profileSyncStatus,
                  subtitle: _syncStatusLabel(context, syncStatus),
                ),
                _InfoTile(
                  icon: Icons.schedule,
                  title: context.l10n.profileLastSynced,
                  subtitle: lastSyncAsync.value != null
                      ? _formatRelativeTime(
                          context,
                          lastSyncAsync.value!,
                          Localizations.localeOf(context).languageCode,
                        )
                      : context.l10n.profileLastSyncedNever,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed:
                        syncStatus == SyncStatus.pushing ||
                            syncStatus == SyncStatus.pulling
                        ? null
                        : () => ref.read(syncTriggerProvider).fullSync(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(context.l10n.profileSyncNow),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Linked accounts
          _SectionCard(
            title: context.l10n.profileLinkedAccounts,
            child: profileAsync.when(
              data: (profile) {
                final accounts =
                    (profile?['linked_accounts'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                if (accounts.isEmpty) {
                  return _EmptyInline(context.l10n.profileNoLinkedAccounts);
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
              loading: () => const _LoadingInline(),
              error: (_, _) =>
                  _EmptyInline(context.l10n.profileCouldNotLoadAccounts),
            ),
          ),
          const SizedBox(height: 16),

          // Active sessions
          _SectionCard(
            title: context.l10n.profileActiveSessions,
            child: profileAsync.when(
              data: (profile) {
                final sessions =
                    (profile?['active_sessions'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                if (sessions.isEmpty) {
                  return _EmptyInline(context.l10n.profileNoActiveSessions);
                }
                return Column(
                  children: sessions.map((s) {
                    return _InfoTile(
                      icon: Icons.devices,
                      title:
                          s['device_name'] as String? ??
                          context.l10n.profileUnknownDevice,
                      subtitle: [
                        s['ip_address'] as String?,
                        _formatDate(s['created_at'] as String?),
                      ].where((e) => e != null && e.isNotEmpty).join(' · '),
                    );
                  }).toList(),
                );
              },
              loading: () => const _LoadingInline(),
              error: (_, _) =>
                  _EmptyInline(context.l10n.profileCouldNotLoadSessions),
            ),
          ),
          const SizedBox(height: 16),

          // Account actions
          _SectionCard(
            title: context.l10n.profileTitle,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(context.l10n.profileLogOut),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KumoriyaColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: KumoriyaColors.borderSubtle.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: KumoriyaColors.borderSubtle),
                const SizedBox(height: 12),
                Text(
                  context.l10n.profileDeleteAccount,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: KumoriyaColors.statusDanger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.profileDeleteAccountWarning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KumoriyaColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _confirmDeleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: KumoriyaColors.statusDanger,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(context.l10n.profileDelete),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
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
              // Capture notifier before any navigation changes.
              final authNotifier = ref.read(authStateProvider.notifier);
              Navigator.pop(ctx); // close dialog
              Navigator.of(context).pop(); // pop profile page
              // Defer logout so the widget tree settles before
              // provider state changes trigger rebuilds.
              Future.microtask(() => authNotifier.logout());
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

  void _confirmDeleteAccount() {
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
              // Capture refs before closing anything.
              final client = ref.read(authenticatedHttpClientProvider);
              final authNotifier = ref.read(authStateProvider.notifier);
              Navigator.pop(ctx); // close dialog
              // Delete account first, then navigate, then logout.
              await client.deleteRequest('/api/v1/account');
              if (mounted) Navigator.of(context).pop();
              // Defer logout so the widget fully disposes first.
              Future.microtask(() => authNotifier.logout());
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
}

class _LoginRedirectPage extends StatelessWidget {
  const _LoginRedirectPage();

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KumoriyaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
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
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KumoriyaColors.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.id,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: KumoriyaColors.textDisabled,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: KumoriyaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(color: KumoriyaColors.textMuted),
      ),
    );
  }
}

class _LoadingInline extends StatelessWidget {
  const _LoadingInline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: KumoriyaColors.primary,
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

