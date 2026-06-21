import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../tokens/cloud_colors.dart';

/// CustomPainter that renders twinkling star points.
///
/// Used as an ambient background for the Noche palette in anime universe.
class StarfieldPainter extends CustomPainter {
  StarfieldPainter({
    required this.colors,
    required this.time,
    this.starCount = 40,
  });

  final CloudColors colors;
  final double time;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // deterministic placement
    final paint = Paint()..color = colors.star;

    for (var i = 0; i < starCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final phase = time + (i * 0.5);
      final opacity = (math.sin(phase * 2) * 0.5 + 0.5);
      final radius = 1.0 + rng.nextDouble() * 1.5;

      paint.color = colors.star.withValues(alpha: opacity * 0.8);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
