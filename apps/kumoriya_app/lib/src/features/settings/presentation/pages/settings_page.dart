import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/bug_report_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../app_update/application/app_update_service.dart';
import '../../../app_update/presentation/app_update_providers.dart';
import '../../../app_update/presentation/widgets/update_available_dialog.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/application/models/subtitle_settings.dart';
import '../../../../workers/check_new_episodes_worker.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const String _debugForcedAndroidUrl =
      'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/android/v0.1.0/kumoriya-0.1.0.apk';
  static const String _debugForcedWindowsUrl =
      'https://pub-8159019abe1741a097538b976c19722c.r2.dev/artifacts/windows/v0.1.0/Kumoriya-0.1.0-windows-x64-setup.exe';

  PermissionStatus? _notificationStatus;
  bool _loadingNotificationStatus = true;
  bool _requestingNotifications = false;
  bool _runningDebugNotificationProbe = false;
  bool _runningDebugUpdateProbe = false;
  bool _runningForcedDebugUpdateProbe = false;
  bool _clearingPlaybackPreferences = false;
  bool _loadingAppVersion = true;
  String _appVersionLabel = '-';

  bool get _supportsNotificationRequest => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = 'v${info.version}';
      if (!mounted) return;
      setState(() {
        _appVersionLabel = version;
        _loadingAppVersion = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAppVersion = false);
    }
  }

  Future<void> _refreshNotificationStatus() async {
    setState(() => _loadingNotificationStatus = true);

    PermissionStatus? nextStatus;
    try {
      nextStatus = await Permission.notification.status;
    } catch (_) {
      nextStatus = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationStatus = nextStatus;
      _loadingNotificationStatus = false;
    });
  }

  Future<void> _requestNotifications() async {
    setState(() => _requestingNotifications = true);
    try {
      await Permission.notification.request();
    } finally {
      if (mounted) {
        setState(() => _requestingNotifications = false);
      }
    }

    if (!mounted) {
      return;
    }

    await _refreshNotificationStatus();
  }

  Future<void> _runDebugNotificationProbe() async {
    if (_runningDebugNotificationProbe || !Platform.isAndroid) {
      return;
    }

    setState(() => _runningDebugNotificationProbe = true);
    try {
      await scheduleDebugBackgroundNotificationProbe();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prueba de notificacion en background programada (aprox. 5s).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo programar la prueba del worker en background.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _runningDebugNotificationProbe = false);
      }
    }
  }

  Future<void> _runDebugUpdateProbe() async {
    if (_runningDebugUpdateProbe) {
      return;
    }

    setState(() => _runningDebugUpdateProbe = true);
    final result = await ref.read(appUpdateServiceProvider).checkForUpdate();
    if (!mounted) {
      return;
    }

    setState(() => _runningDebugUpdateProbe = false);

    result.fold(
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check fallo (debug): ${error.code}')),
        );
      },
      onSuccess: (update) async {
        if (update == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay update disponible para esta version (debug).',
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update detectada: v${update.newVersion} (debug)'),
          ),
        );

        await UpdateAvailableDialog.show(context, update);
      },
    );
  }

  Future<void> _runForcedDebugUpdateProbe() async {
    if (_runningForcedDebugUpdateProbe) {
      return;
    }

    setState(() => _runningForcedDebugUpdateProbe = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final forced = AvailableUpdate(
        currentVersion: packageInfo.version,
        newVersion: '${packageInfo.version}-forced',
        downloadUrl: Platform.isWindows
            ? _debugForcedWindowsUrl
            : _debugForcedAndroidUrl,
        releaseNotes:
            'Modo debug forzado: abre el dialogo sin depender de version remota.',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dialogo de update forzado abierto (debug).'),
        ),
      );
      await UpdateAvailableDialog.show(context, forced);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir update forzado (debug): $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _runningForcedDebugUpdateProbe = false);
      }
    }
  }

  Future<void> _changeDownloadFolder() async {
    final result = await ref
        .read(downloadDirectoryServiceProvider)
        .selectDirectory();
    if (!mounted) {
      return;
    }

    result.fold(
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'download.directory_permission_denied'
                  ? context.l10n.downloadFolderPermissionDenied
                  : mapErrorMessage(context, error),
            ),
          ),
        );
      },
      onSuccess: (outcome) async {
        await ref.read(downloadManagerProvider).syncDownloadedLibrary();
        if (!mounted) {
          return;
        }
        ref.invalidate(allDownloadTasksProvider);
        ref.invalidate(completedDownloadTasksProvider);
        ref.invalidate(activeDownloadTasksProvider);
        ref.invalidate(queuedDownloadTasksProvider);
        ref.invalidate(downloadDirectoryInfoProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.changed
                  ? context.l10n.downloadFolderSaved
                  : context.l10n.downloadFolderSelectionCancelled,
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetDownloadFolder() async {
    final result = await ref
        .read(downloadDirectoryServiceProvider)
        .resetToDefault();
    if (!mounted) {
      return;
    }

    result.fold(
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorMessage(context, error))),
        );
      },
      onSuccess: (_) async {
        await ref.read(downloadManagerProvider).syncDownloadedLibrary();
        if (!mounted) {
          return;
        }
        ref.invalidate(allDownloadTasksProvider);
        ref.invalidate(completedDownloadTasksProvider);
        ref.invalidate(activeDownloadTasksProvider);
        ref.invalidate(queuedDownloadTasksProvider);
        ref.invalidate(downloadDirectoryInfoProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.downloadFolderResetDone)),
        );
      },
    );
  }

  Future<void> _clearPlaybackPreferences() async {
    setState(() => _clearingPlaybackPreferences = true);
    final result = await ref
        .read(animeProgressStoreProvider)
        .clearAllPlaybackPreferences();
    if (!mounted) {
      return;
    }

    setState(() => _clearingPlaybackPreferences = false);
    result.fold(
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorMessage(context, error))),
        );
      },
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settingsPlaybackPreferencesCleared),
          ),
        );
      },
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAuth = user != null;

    return _SettingsSectionCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: KumoriyaColors.primary,
          child: isAuth
              ? Text(
                  user.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                )
              : const Icon(Icons.person_outline, color: Colors.white),
        ),
        title: Text(
          isAuth ? user.displayName : 'Sign in',
          style: TextStyle(
            color: KumoriyaColors.textPrimary,
            fontWeight: isAuth ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          isAuth
              ? 'Sync enabled — tap to manage'
              : 'Sync your progress across devices',
          style: const TextStyle(
            color: KumoriyaColors.textTertiary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: KumoriyaColors.textTertiary,
        ),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => isAuth ? const ProfilePage() : const LoginPage(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final directoryInfoState = ref.watch(downloadDirectoryInfoProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Text(
            context.l10n.settingsTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            Platform.isWindows
                ? context.l10n.settingsDesktopOnlyVisibleNote
                : context.l10n.settingsNotificationsDescription,
            style: const TextStyle(
              color: KumoriyaColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildAccountSection(context),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            child: Column(
              children: <Widget>[
                if (!Platform.isWindows) ...<Widget>[
                  _SettingsSection(
                    title: context.l10n.settingsNotificationsTitle,
                    description: context.l10n.settingsNotificationsDescription,
                    child: Column(
                      children: <Widget>[
                        _SettingsActionRow(
                          leading: KumoriyaIcons.notificationsActive,
                          title: context.l10n.settingsNotificationsTitle,
                          subtitle: _notificationStatusLabel(context),
                          trailing: _StatusBadge(
                            label: _notificationStatusLabel(context),
                            tone: _notificationStatusTone,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (_supportsNotificationRequest &&
                                !(_notificationStatus?.isGranted ?? false))
                              FilledButton.icon(
                                onPressed:
                                    _requestingNotifications ||
                                        _loadingNotificationStatus
                                    ? null
                                    : _requestNotifications,
                                icon: _requestingNotifications
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        KumoriyaIcons.notificationsActive,
                                      ),
                                label: Text(
                                  context.l10n.settingsEnableNotifications,
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await openAppSettings();
                                if (mounted) {
                                  await _refreshNotificationStatus();
                                }
                              },
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(
                                context.l10n.settingsOpenSystemSettings,
                              ),
                            ),
                            if (kDebugMode && Platform.isAndroid)
                              FilledButton.tonalIcon(
                                onPressed: _runningDebugNotificationProbe
                                    ? null
                                    : _runDebugNotificationProbe,
                                icon: _runningDebugNotificationProbe
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(KumoriyaIcons.bugReport),
                                label: const Text('Test notificacion (debug)'),
                              ),
                            if (kDebugMode &&
                                (Platform.isAndroid || Platform.isWindows))
                              FilledButton.tonalIcon(
                                onPressed: _runningDebugUpdateProbe
                                    ? null
                                    : _runDebugUpdateProbe,
                                icon: _runningDebugUpdateProbe
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.system_update_rounded),
                                label: const Text('Test update E2E (debug)'),
                              ),
                            if (kDebugMode &&
                                (Platform.isAndroid || Platform.isWindows))
                              FilledButton.tonalIcon(
                                onPressed: _runningForcedDebugUpdateProbe
                                    ? null
                                    : _runForcedDebugUpdateProbe,
                                icon: _runningForcedDebugUpdateProbe
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.bolt_rounded),
                                label: const Text(
                                  'Forzar dialogo update (debug)',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const _SectionDivider(),
                ],
                _SettingsSection(
                  title: context.l10n.downloadFolderTitle,
                  description: context.l10n.downloadFolderDescription,
                  child: directoryInfoState.when(
                    loading: () => const SizedBox(
                      height: 64,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ref.invalidate(downloadDirectoryInfoProvider),
                        icon: const Icon(KumoriyaIcons.refresh),
                        label: Text(context.l10n.retry),
                      ),
                    ),
                    data: (info) => Column(
                      children: <Widget>[
                        _SettingsActionRow(
                          leading: Icons.folder_open_rounded,
                          title: context.l10n.downloadFolderTitle,
                          subtitle: info.path,
                          trailing: _StatusBadge(
                            label: info.isCustom
                                ? context.l10n.downloadFolderCustom
                                : context.l10n.downloadFolderDefault,
                            tone: _BadgeTone.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: _changeDownloadFolder,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: Text(context.l10n.downloadFolderChange),
                            ),
                            if (info.isCustom)
                              OutlinedButton.icon(
                                onPressed: _resetDownloadFolder,
                                icon: const Icon(Icons.restore_rounded),
                                label: Text(context.l10n.downloadFolderReset),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const _SectionDivider(),
                _SettingsSection(
                  title: context.l10n.settingsPlaybackPreferencesTitle,
                  description:
                      context.l10n.settingsPlaybackPreferencesDescription,
                  child: Column(
                    children: <Widget>[
                      _SettingsActionRow(
                        leading: Icons.tune_rounded,
                        title: context.l10n.settingsPlaybackPreferencesTitle,
                        subtitle:
                            context.l10n.settingsPlaybackPreferencesDescription,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _clearingPlaybackPreferences
                              ? null
                              : _clearPlaybackPreferences,
                          icon: _clearingPlaybackPreferences
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_sweep_rounded),
                          label: Text(
                            context.l10n.settingsPlaybackPreferencesClear,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionDivider(),
                _buildSubtitleSettingsSection(context),
                const _SectionDivider(),
                _SettingsSection(
                  title: context.l10n.settingsAppTitle,
                  child: Column(
                    children: <Widget>[
                      _ReadOnlySettingRow(
                        label: context.l10n.settingsVersionLabel,
                        value: _loadingAppVersion
                            ? context.l10n.loadingGeneric
                            : _appVersionLabel,
                      ),
                      const SizedBox(height: 4),
                      _ReadOnlySettingRow(
                        label: context.l10n.settingsThemeLabel,
                        value: context.l10n.settingsThemeDark,
                      ),
                      const SizedBox(height: 4),
                      _ReadOnlySettingRow(
                        label: context.l10n.settingsLanguageLabel,
                        value: locale.languageCode.startsWith('es')
                            ? context.l10n.settingsLanguageSpanish
                            : context.l10n.settingsLanguageEnglish,
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        height: 1,
                        color: KumoriyaColors.borderSubtle,
                      ),
                      const SizedBox(height: 12),
                      const BugReportButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleSettingsSection(BuildContext context) {
    final subtitleState = ref.watch(subtitleSettingsProvider);
    final settings = subtitleState.value ?? const SubtitleSettings();
    final notifier = ref.read(subtitleSettingsProvider.notifier);

    return _SettingsSection(
      title: context.l10n.settingsSubtitleTitle,
      description: context.l10n.settingsSubtitleDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Font size ──
          Text(
            context.l10n.settingsSubtitleFontSize,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SubtitleFontSize>(
            segments: <ButtonSegment<SubtitleFontSize>>[
              ButtonSegment(
                value: SubtitleFontSize.small,
                label: Text(context.l10n.settingsSubtitleSmall),
              ),
              ButtonSegment(
                value: SubtitleFontSize.medium,
                label: Text(context.l10n.settingsSubtitleMedium),
              ),
              ButtonSegment(
                value: SubtitleFontSize.large,
                label: Text(context.l10n.settingsSubtitleLarge),
              ),
              ButtonSegment(
                value: SubtitleFontSize.extraLarge,
                label: Text(context.l10n.settingsSubtitleExtraLarge),
              ),
            ],
            selected: {settings.fontSize},
            onSelectionChanged: (selection) {
              notifier.setFontSize(selection.first);
            },
          ),
          const SizedBox(height: 16),

          // ── Font color ──
          Text(
            context.l10n.settingsSubtitleFontColor,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: SubtitleFontColor.values.map((c) {
              final selected = settings.fontColor == c;
              return GestureDetector(
                onTap: () => notifier.save((s) => s.copyWith(fontColor: c)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? KumoriyaColors.primary
                          : KumoriyaColors.borderSubtle,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color:
                              c == SubtitleFontColor.white ||
                                  c == SubtitleFontColor.yellow
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Font opacity ──
          Text(
            context.l10n.settingsSubtitleFontOpacity,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: settings.fontOpacity,
            min: 0.25,
            max: 1.0,
            divisions: 3,
            label: '${(settings.fontOpacity * 100).round()}%',
            onChanged: (v) => notifier.save((s) => s.copyWith(fontOpacity: v)),
          ),
          const SizedBox(height: 8),

          // ── Background color ──
          Text(
            context.l10n.settingsSubtitleBgColor,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SubtitleBackgroundColor>(
            segments: <ButtonSegment<SubtitleBackgroundColor>>[
              ButtonSegment(
                value: SubtitleBackgroundColor.black,
                label: Text(context.l10n.settingsSubtitleBgBlack),
              ),
              ButtonSegment(
                value: SubtitleBackgroundColor.darkGray,
                label: Text(context.l10n.settingsSubtitleBgDarkGray),
              ),
              ButtonSegment(
                value: SubtitleBackgroundColor.transparent,
                label: Text(context.l10n.settingsSubtitleBgNone),
              ),
            ],
            selected: {settings.backgroundColor},
            onSelectionChanged: (selection) {
              notifier.save(
                (s) => s.copyWith(backgroundColor: selection.first),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Background opacity ──
          if (settings.backgroundColor !=
              SubtitleBackgroundColor.transparent) ...<Widget>[
            Text(
              context.l10n.settingsSubtitleBgOpacity,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: settings.backgroundOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 4,
              label: '${(settings.backgroundOpacity * 100).round()}%',
              onChanged: (v) =>
                  notifier.save((s) => s.copyWith(backgroundOpacity: v)),
            ),
            const SizedBox(height: 8),
          ],

          // ── Edge / outline style ──
          Text(
            context.l10n.settingsSubtitleEdgeStyle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SubtitleEdgeStyle.values.map((style) {
              final selected = settings.edgeStyle == style;
              final label = switch (style) {
                SubtitleEdgeStyle.none => context.l10n.settingsSubtitleEdgeNone,
                SubtitleEdgeStyle.outline =>
                  context.l10n.settingsSubtitleEdgeOutline,
                SubtitleEdgeStyle.dropShadow =>
                  context.l10n.settingsSubtitleEdgeDropShadow,
                SubtitleEdgeStyle.raised =>
                  context.l10n.settingsSubtitleEdgeRaised,
                SubtitleEdgeStyle.depressed =>
                  context.l10n.settingsSubtitleEdgeDepressed,
              };
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) =>
                    notifier.save((s) => s.copyWith(edgeStyle: style)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _SubtitlePreviewCard(settings: settings),
        ],
      ),
    );
  }

  String _notificationStatusLabel(BuildContext context) {
    final status = _notificationStatus;
    if (_loadingNotificationStatus || status == null) {
      return context.l10n.settingsStatusUnknown;
    }
    if (status.isGranted) {
      return context.l10n.settingsStatusAllowed;
    }
    if (status.isDenied ||
        status.isPermanentlyDenied ||
        status.isRestricted ||
        status.isLimited) {
      return context.l10n.settingsStatusBlocked;
    }
    return context.l10n.settingsStatusUnknown;
  }

  _BadgeTone get _notificationStatusTone {
    final status = _notificationStatus;
    if (!_loadingNotificationStatus && status != null && status.isGranted) {
      return _BadgeTone.success;
    }
    if (!_loadingNotificationStatus &&
        status != null &&
        (status.isDenied ||
            status.isPermanentlyDenied ||
            status.isRestricted ||
            status.isLimited)) {
      return _BadgeTone.warning;
    }
    return _BadgeTone.neutral;
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.child});

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
      child: child,
    );
  }
}

class _SubtitlePreviewCard extends StatelessWidget {
  const _SubtitlePreviewCard({required this.settings});

  final SubtitleSettings settings;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final sampleText = locale.languageCode.startsWith('es')
        ? 'Asi se veran los subtitulos durante la reproduccion.'
        : 'This is how subtitles will look during playback.';
    final previewFontSize = settings.fontSize.pixels * 0.42;

    final effectiveFontColor = settings.fontColor.color.withValues(
      alpha: settings.fontOpacity,
    );
    final effectiveBgColor =
        settings.backgroundColor == SubtitleBackgroundColor.transparent
        ? Colors.transparent
        : settings.backgroundColor.color.withValues(
            alpha: settings.backgroundOpacity,
          );
    final hasBg =
        settings.backgroundColor != SubtitleBackgroundColor.transparent &&
        settings.backgroundOpacity > 0;

    // Scale edge shadows for preview size
    final config = settings.toViewConfiguration();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF273142), Color(0xFF0B0E14)],
        ),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.playerSubtitles,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: hasBg
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                  : EdgeInsets.zero,
              decoration: hasBg
                  ? BoxDecoration(
                      color: effectiveBgColor,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                    )
                  : null,
              child: Text(
                sampleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: previewFontSize,
                  fontWeight: FontWeight.w700,
                  color: effectiveFontColor,
                  height: 1.2,
                  shadows: config.style.shadows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final Widget child;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: KumoriyaColors.textPrimary,
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            description!,
            style: const TextStyle(
              color: KumoriyaColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(height: 1, color: KumoriyaColors.borderSubtle),
    );
  }
}

enum _BadgeTone { primary, success, warning, neutral }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      _BadgeTone.primary => (
        KumoriyaColors.primary,
        KumoriyaColors.primary.withValues(alpha: 0.12),
      ),
      _BadgeTone.success => (
        KumoriyaColors.statusSuccess,
        KumoriyaColors.statusSuccess.withValues(alpha: 0.14),
      ),
      _BadgeTone.warning => (
        KumoriyaColors.statusWarning,
        KumoriyaColors.statusWarning.withValues(alpha: 0.14),
      ),
      _BadgeTone.neutral => (
        KumoriyaColors.textMuted,
        KumoriyaColors.surfaceBright.withValues(alpha: 0.9),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _ReadOnlySettingRow extends StatelessWidget {
  const _ReadOnlySettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: KumoriyaColors.textSecondary,
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: KumoriyaColors.textPrimary,
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: KumoriyaColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          ),
          child: Icon(leading, color: KumoriyaColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: KumoriyaColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
