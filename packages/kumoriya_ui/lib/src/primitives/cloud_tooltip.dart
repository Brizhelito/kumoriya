import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled tooltip for desktop hover.
///
/// Renders a cloud-shadow tooltip with surface bg and 12px radius.
/// On mobile/tablet, this is a no-op wrapper (just renders [child]).
class CloudTooltip extends StatelessWidget {
  const CloudTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = FormFactorProvider.formFactorOf(context);
    if (factor.isTouch) return child;

    return Tooltip(
      message: message,
      preferBelow: false,
      decoration: _buildDecoration(context),
      textStyle: _buildTextStyle(context),
      child: child,
    );
  }

  BoxDecoration _buildDecoration(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(CloudRadius.sm),
      boxShadow: colors.shadowSm,
    );
  }

  TextStyle _buildTextStyle(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return TextStyle(
      color: colors.text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
  }
}
