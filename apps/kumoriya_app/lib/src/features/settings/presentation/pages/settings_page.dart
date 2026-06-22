import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../shared/utils/error_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/widgets/bug_report_button.dart';
import '../../../app_update/application/app_update_service.dart';
import '../../../app_update/presentation/app_update_providers.dart';
import '../../../app_update/presentation/widgets/update_available_dialog.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../application/app_language_preference.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../downloads/application/download_directory_service.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../downloads/application/auto_delete_watched_service.dart';
import '../../../downloads/application/wifi_only_mode_notifier.dart';
import '../../../player/application/models/subtitle_settings.dart';
import 'kumoriya_exoplayer_playground_page.dart';
import 'player_flow_playground_page.dart';
import 'plugin_base_url_overrides_page.dart';
import 'resolver_playground_page.dart';

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
    final colors = FormFactorProvider.colorsOf(context);
    final user = ref.watch(currentUserProvider);
    final isAuth = user != null;

    return _SettingsSectionCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colors.primary,
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
            color: colors.text,
            fontWeight: isAuth ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          isAuth
              ? 'Sync enabled — tap to manage'
              : 'Sync your progress across devices',
          style: TextStyle(color: colors.textSoft, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: colors.textSoft),
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
    final colors = FormFactorProvider.colorsOf(context);
    final locale = Localizations.localeOf(context);
    final directoryInfoState = ref.watch(downloadDirectoryInfoProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _buildAccountSection(context),
          const SizedBox(height: 16),
          if (!Platform.isWindows) ...<Widget>[
            _buildNotificationsCard(context),
            const SizedBox(height: 16),
          ],
          _buildDownloadsCard(context, directoryInfoState),
          const SizedBox(height: 16),
          _buildPlaybackCard(context),
          const SizedBox(height: 16),
          _SettingsSectionCard(child: _buildSubtitleSettingsSection(context)),
          const SizedBox(height: 16),
          _buildAppCard(context, locale),
          const SizedBox(height: 16),
          _buildAdvancedCard(context),
          const SizedBox(height: 16),
          _buildHelpCard(context),
          if (kDebugMode) ...<Widget>[
            const SizedBox(height: 16),
            _buildDeveloperCard(context),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context) {
    return _SettingsSectionCard(
      child: _SettingsSection(
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
                        _requestingNotifications || _loadingNotificationStatus
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
                        : const Icon(KumoriyaIcons.notificationsActive),
                    label: Text(context.l10n.settingsEnableNotifications),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    if (mounted) {
                      await _refreshNotificationStatus();
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.l10n.settingsOpenSystemSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsCard(
    BuildContext context,
    AsyncValue<DownloadDirectoryInfo> directoryInfoState,
  ) {
    return _SettingsSectionCard(
      child: Column(
        children: <Widget>[
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
          const _AutoDeleteWatchedSection(),
          if (!Platform.isWindows) ...<Widget>[
            const _SectionDivider(),
            const _WifiOnlyDownloadsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaybackCard(BuildContext context) {
    return _SettingsSectionCard(
      child: _SettingsSection(
        title: context.l10n.settingsPlaybackPreferencesTitle,
        description: context.l10n.settingsPlaybackPreferencesDescription,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _clearingPlaybackPreferences
                ? null
                : _clearPlaybackPreferences,
            icon: _clearingPlaybackPreferences
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_rounded),
            label: Text(context.l10n.settingsPlaybackPreferencesClear),
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(BuildContext context, Locale locale) {
    return _SettingsSectionCard(
      child: _SettingsSection(
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
            _LanguagePickerRow(deviceLocale: locale),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedCard(BuildContext context) {
    return _SettingsSectionCard(
      child: _SettingsSection(
        title: 'Avanzado',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link_rounded),
          title: Text(context.l10n.settingsPluginBaseUrlsAdvancedEntry),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const PluginBaseUrlOverridesPage(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    return _SettingsSectionCard(
      child: _SettingsSection(
        title: 'Ayuda y feedback',
        child: const Align(
          alignment: Alignment.centerLeft,
          child: BugReportButton(),
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context) {
    return _SettingsSectionCard(
      child: _SettingsSection(
        title: 'Desarrollador (debug)',
        description: 'Herramientas internas. Solo visibles en builds de debug.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (Platform.isAndroid || Platform.isWindows)
              FilledButton.tonalIcon(
                onPressed: _runningDebugUpdateProbe
                    ? null
                    : _runDebugUpdateProbe,
                icon: _runningDebugUpdateProbe
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_rounded),
                label: const Text('Test update E2E'),
              ),
            if (Platform.isAndroid || Platform.isWindows)
              FilledButton.tonalIcon(
                onPressed: _runningForcedDebugUpdateProbe
                    ? null
                    : _runForcedDebugUpdateProbe,
                icon: _runningForcedDebugUpdateProbe
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded),
                label: const Text('Forzar dialogo update'),
              ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ResolverPlaygroundPage(),
                  ),
                );
              },
              icon: const Icon(Icons.science_rounded),
              label: const Text('Resolver Playground'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayerFlowPlaygroundPage(),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Player Flow Playground'),
            ),
            if (Platform.isAndroid)
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const KumoriyaExoPlayerPlaygroundPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.smart_display_rounded),
                label: const Text('kumoriya_exoplayer Playground'),
              ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CloudGalleryPage(),
                  ),
                );
              },
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Cloud UI Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleSettingsSection(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
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
                      color: selected ? colors.primary : colors.surface2,
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
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgElev,
        borderRadius: BorderRadius.circular(CloudRadius.lg),
        border: Border.all(color: colors.surface2),
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
    final colors = FormFactorProvider.colorsOf(context);
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
        borderRadius: BorderRadius.circular(CloudRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF273142), Color(0xFF0B0E14)],
        ),
        border: Border.all(color: colors.surface2),
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
                      borderRadius: BorderRadius.circular(CloudRadius.md),
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
    final colors = FormFactorProvider.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.text,
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            description!,
            style: TextStyle(color: colors.textMuted, height: 1.4),
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
    final colors = FormFactorProvider.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(height: 1, color: colors.surface2),
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
    final colors = FormFactorProvider.colorsOf(context);
    final (foreground, background) = switch (tone) {
      _BadgeTone.primary => (
        colors.primary,
        colors.primary.withValues(alpha: 0.12),
      ),
      _BadgeTone.success => (
        colors.success,
        colors.success.withValues(alpha: 0.14),
      ),
      _BadgeTone.warning => (
        colors.warning,
        colors.warning.withValues(alpha: 0.14),
      ),
      _BadgeTone.neutral => (
        colors.textMuted,
        colors.bgElev.withValues(alpha: 0.9),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
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
    final colors = FormFactorProvider.colorsOf(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }
}

class _LanguagePickerRow extends ConsumerWidget {
  const _LanguagePickerRow({required this.deviceLocale});

  final Locale deviceLocale;

  String _label(BuildContext context, AppLanguagePreference pref) {
    return switch (pref) {
      AppLanguagePreference.system => context.l10n.settingsLanguageSystem,
      AppLanguagePreference.english => context.l10n.settingsLanguageEnglish,
      AppLanguagePreference.spanish => context.l10n.settingsLanguageSpanish,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final asyncPref = ref.watch(appLanguageProvider);
    final current = asyncPref.value ?? AppLanguagePreference.system;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        context.l10n.settingsLanguageLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
        ),
      ),
      subtitle: Text(
        context.l10n.settingsLanguageDescription,
        style: TextStyle(fontSize: 11, color: colors.textSoft, height: 1.3),
      ),
      trailing: DropdownButton<AppLanguagePreference>(
        value: current,
        underline: const SizedBox.shrink(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
        dropdownColor: colors.surface,
        items: AppLanguagePreference.values
            .map(
              (pref) => DropdownMenuItem<AppLanguagePreference>(
                value: pref,
                child: Text(_label(context, pref)),
              ),
            )
            .toList(),
        onChanged: asyncPref.isLoading
            ? null
            : (value) {
                if (value == null) return;
                ref.read(appLanguageProvider.notifier).setPreference(value);
              },
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
    final colors = FormFactorProvider.colorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(CloudRadius.md),
          ),
          child: Icon(leading, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
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

// ─── Auto-delete watched downloads section ──────────────────────────────────

class _AutoDeleteWatchedSection extends ConsumerWidget {
  const _AutoDeleteWatchedSection();

  String _delayLabel(BuildContext context, AutoDeleteDelay delay) {
    return switch (delay) {
      AutoDeleteDelay.never => context.l10n.settingsAutoDeleteNever,
      AutoDeleteDelay.immediately => context.l10n.settingsAutoDeleteImmediately,
      _ => context.l10n.settingsAutoDeleteAfterDays(delay.days!),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final asyncDelay = ref.watch(autoDeleteDelayProvider);
    final current = asyncDelay.value ?? AutoDeleteDelay.never;

    return _SettingsSection(
      title: context.l10n.settingsAutoDeleteWatched,
      child: Column(
        children: <Widget>[
          _SettingsActionRow(
            leading: Icons.auto_delete_rounded,
            title: context.l10n.settingsAutoDeleteWatched,
            subtitle: _delayLabel(context, current),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AutoDeleteDelay.values.map((delay) {
              final selected = current == delay;
              return ChoiceChip(
                label: Text(_delayLabel(context, delay)),
                selected: selected,
                onSelected: (_) {
                  ref.read(autoDeleteDelayProvider.notifier).set(delay);
                },
                selectedColor: colors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.textMuted,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── WiFi-only downloads section ────────────────────────────────────────────

class _WifiOnlyDownloadsSection extends ConsumerWidget {
  const _WifiOnlyDownloadsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEnabled = ref.watch(wifiOnlyModeNotifierProvider);
    final enabled = asyncEnabled.value ?? false;

    return _SettingsSection(
      title: context.l10n.settingsDownloadsTitle,
      child: Column(
        children: <Widget>[
          _SettingsActionRow(
            leading: Icons.wifi_rounded,
            title: context.l10n.settingsDownloadsWifiOnly,
            subtitle: context.l10n.settingsDownloadsWifiOnlyDescription,
            trailing: Switch(
              value: enabled,
              onChanged: asyncEnabled.isLoading
                  ? null
                  : (value) {
                      ref
                          .read(wifiOnlyModeNotifierProvider.notifier)
                          .setEnabled(value);
                    },
            ),
          ),
        ],
      ),
    );
  }
}
