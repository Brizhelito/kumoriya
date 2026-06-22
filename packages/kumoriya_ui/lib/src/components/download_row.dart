import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_progress.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Active download row — cover + title + episode + status + progress.
class DownloadRow extends StatelessWidget {
  const DownloadRow({
    super.key,
    required this.animeTitle,
    required this.episodeLabel,
    required this.status,
    this.progress = 0.0,
    this.imageUrl,
    this.onTap,
  });

  final String animeTitle;
  final String episodeLabel;
  final DownloadStatus status;
  final double progress;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final statusIcon = _resolveIcon();
    final statusColor = _resolveColor(colors);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(CloudRadius.lg),
          border: Border.all(color: colors.surface2),
        ),
        padding: EdgeInsets.all(CloudSpacing.s3),
        child: Row(
          children: <Widget>[
            // Cover placeholder
            Container(
              width: 52,
              height: 70,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(CloudRadius.md),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: colors.textSoft,
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: CloudSpacing.s3),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    animeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    episodeLabel,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  SizedBox(height: CloudSpacing.s2),
                  Row(
                    children: <Widget>[
                      Icon(statusIcon, size: 14, color: statusColor),
                      SizedBox(width: CloudSpacing.s1),
                      Text(
                        _statusLabel(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (status == DownloadStatus.downloading ||
                      status == DownloadStatus.paused ||
                      status == DownloadStatus.remuxing ||
                      status == DownloadStatus.disconnected) ...[
                    SizedBox(height: CloudSpacing.s1),
                    CloudProgress(value: progress),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveIcon() {
    return switch (status) {
      DownloadStatus.pending => Icons.schedule_rounded,
      DownloadStatus.downloading => Icons.download_rounded,
      DownloadStatus.paused => Icons.pause_circle_outline_rounded,
      DownloadStatus.remuxing => Icons.sync_rounded,
      DownloadStatus.disconnected => Icons.wifi_off_rounded,
      DownloadStatus.completed => Icons.download_done_rounded,
      DownloadStatus.failed => Icons.error_outline_rounded,
      DownloadStatus.cancelled => Icons.cancel_outlined,
    };
  }

  Color _resolveColor(CloudColors colors) {
    return switch (status) {
      DownloadStatus.pending => colors.textSoft,
      DownloadStatus.downloading => colors.primary,
      DownloadStatus.paused => colors.warning,
      DownloadStatus.remuxing => colors.primary,
      DownloadStatus.disconnected => colors.warning,
      DownloadStatus.completed => colors.success,
      DownloadStatus.failed => colors.error,
      DownloadStatus.cancelled => colors.textSoft,
    };
  }

  String _statusLabel() {
    return switch (status) {
      DownloadStatus.pending => 'Pending',
      DownloadStatus.downloading => 'Downloading',
      DownloadStatus.paused => 'Paused',
      DownloadStatus.remuxing => 'Processing',
      DownloadStatus.disconnected => 'Disconnected',
      DownloadStatus.completed => 'Completed',
      DownloadStatus.failed => 'Failed',
      DownloadStatus.cancelled => 'Cancelled',
    };
  }
}
