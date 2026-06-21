import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';

/// Cloud-styled progress bar — 3px pill, accent fill, surface-2 track.
class CloudProgress extends StatelessWidget {
  const CloudProgress({
    super.key,
    required this.value,
    this.height = 3.0,
    this.trackColor,
    this.fillColor,
  });

  /// Progress value from 0.0 to 1.0.
  final double value;

  /// Bar height in pixels.
  final double height;

  /// Track color override. Defaults to surface-2.
  final Color? trackColor;

  /// Fill color override. Defaults to accent.
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final clamped = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(CloudRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            // Track
            Positioned.fill(
              child: ColoredBox(color: trackColor ?? colors.surface2),
            ),
            // Fill
            FractionallySizedBox(
              widthFactor: clamped,
              child: ColoredBox(color: fillColor ?? colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
