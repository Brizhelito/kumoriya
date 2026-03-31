import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../application/app_update_service.dart';
import '../../application/update_installer.dart';
import '../app_update_providers.dart';

/// Shows a modal dialog when a new version is available.
///
/// The dialog drives through three phases:
/// 1. **Available** – shows release notes with Update / Later buttons.
/// 2. **Downloading** – shows a progress bar.
/// 3. **Ready to install** – triggers the platform installer automatically.
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key, required this.update});

  final AvailableUpdate update;

  static Future<void> show(BuildContext context, AvailableUpdate update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateAvailableDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);

    // Auto-trigger install when download finishes.
    ref.listen<AppUpdateState>(appUpdateProvider, (prev, next) {
      if (next is AppUpdateReadyToInstall) {
        UpdateInstaller.install(next.filePath).catchError((error) {
          ref
              .read(appUpdateProvider.notifier)
              .setErrorMessage('No se pudo abrir el instalador: $error');
        });
      }
    });

    return AlertDialog(
      backgroundColor: KumoriyaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
      ),
      title: Row(
        children: [
          Icon(Icons.system_update, color: KumoriyaColors.primary, size: 28),
          const SizedBox(width: KumoriyaSpacing.sm),
          const Expanded(child: Text('Nueva actualización')),
        ],
      ),
      content: _buildContent(context, state),
      actions: _buildActions(context, ref, state),
    );
  }

  Widget _buildContent(BuildContext context, AppUpdateState state) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KumoriyaSpacing.sm,
            vertical: KumoriyaSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: KumoriyaColors.primaryContainer,
            borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
          ),
          child: Text(
            'v${update.currentVersion}  →  v${update.newVersion}',
            style: textTheme.labelMedium?.copyWith(
              color: KumoriyaColors.primaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: KumoriyaSpacing.md),

        // Release notes
        if (update.releaseNotes.isNotEmpty) ...[
          Text(
            'Novedades:',
            style: textTheme.labelSmall?.copyWith(
              color: KumoriyaColors.textMuted,
            ),
          ),
          const SizedBox(height: KumoriyaSpacing.xs),
          Text(
            update.releaseNotes,
            style: textTheme.bodyMedium?.copyWith(
              color: KumoriyaColors.textSecondary,
            ),
          ),
        ],

        // Download progress
        if (state is AppUpdateDownloading) ...[
          const SizedBox(height: KumoriyaSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descargando actualización…',
                style: textTheme.bodySmall?.copyWith(
                  color: KumoriyaColors.textMuted,
                ),
              ),
              const SizedBox(height: KumoriyaSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
                child: LinearProgressIndicator(
                  value: state.total > 0 ? state.progress : null,
                  backgroundColor: KumoriyaColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    KumoriyaColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              if (state.total > 0) ...[
                const SizedBox(height: KumoriyaSpacing.xs),
                Text(
                  '${_formatBytes(state.received)} / ${_formatBytes(state.total)}',
                  style: textTheme.labelSmall?.copyWith(
                    color: KumoriyaColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],

        // Ready to install
        if (state is AppUpdateReadyToInstall) ...[
          const SizedBox(height: KumoriyaSpacing.lg),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: KumoriyaColors.statusSuccess,
                size: 20,
              ),
              const SizedBox(width: KumoriyaSpacing.sm),
              Expanded(
                child: Text(
                  Platform.isWindows
                      ? 'Instalando… la aplicación se cerrará.'
                      : 'Abriendo instalador…',
                  style: textTheme.bodySmall?.copyWith(
                    color: KumoriyaColors.statusSuccess,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Error
        if (state case AppUpdateError(:final message)) ...[
          const SizedBox(height: KumoriyaSpacing.lg),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: KumoriyaColors.statusDanger,
                size: 20,
              ),
              const SizedBox(width: KumoriyaSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    color: KumoriyaColors.statusDanger,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    AppUpdateState state,
  ) {
    // While downloading or installing, no actions.
    if (state is AppUpdateDownloading || state is AppUpdateReadyToInstall) {
      return const [];
    }

    if (state is AppUpdateError) {
      return [
        TextButton(
          onPressed: () {
            ref.read(appUpdateProvider.notifier).dismiss();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cerrar',
            style: TextStyle(color: KumoriyaColors.textMuted),
          ),
        ),
        FilledButton(
          onPressed: () {
            ref.read(appUpdateProvider.notifier).downloadAndInstall(update);
          },
          child: const Text('Reintentar'),
        ),
      ];
    }

    // Default: available state
    return [
      TextButton(
        onPressed: () {
          ref.read(appUpdateProvider.notifier).dismiss();
          Navigator.of(context).pop();
        },
        child: Text(
          'Más tarde',
          style: TextStyle(color: KumoriyaColors.textMuted),
        ),
      ),
      FilledButton(
        onPressed: () {
          ref.read(appUpdateProvider.notifier).downloadAndInstall(update);
        },
        child: const Text('Actualizar'),
      ),
    ];
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
