import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';

/// Cloud-styled gradient fade divider.
///
/// A horizontal gradient line that fades from transparent through
/// text-soft and back to transparent.
class CloudDivider extends StatelessWidget {
  const CloudDivider({super.key, this.height = 1.0});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.textSoft.withValues(alpha: 0),
            colors.textSoft.withValues(alpha: 0.3),
            colors.textSoft.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
