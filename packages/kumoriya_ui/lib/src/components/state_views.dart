import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../primitives/cloud_button.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled loading state — centered spinner with optional label.
class CloudLoadingView extends StatelessWidget {
  const CloudLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primary,
                backgroundColor: colors.surface2,
              ),
            ),
            SizedBox(height: CloudSpacing.s3),
            Text(
              label ?? 'Loading…',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cloud-styled empty state — icon + title + message + optional CTA.
class CloudEmptyView extends StatelessWidget {
  const CloudEmptyView({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: EdgeInsets.all(CloudSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 48, color: colors.textSoft),
                SizedBox(height: CloudSpacing.s4),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: CloudSpacing.s2),
              ],
              Text(
                message,
                style: TextStyle(color: colors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionLabel != null) ...[
                SizedBox(height: CloudSpacing.s5),
                CloudButton.primary(onPressed: onAction, label: actionLabel!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cloud-styled error state — error icon + message + retry button.
class CloudErrorView extends StatelessWidget {
  const CloudErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: EdgeInsets.all(CloudSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
              SizedBox(height: CloudSpacing.s4),
              Text(
                message,
                style: TextStyle(color: colors.textMuted, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: CloudSpacing.s5),
                CloudButton.ghost(
                  onPressed: onRetry,
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
