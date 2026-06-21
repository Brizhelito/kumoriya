import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../tokens/cloud_colors.dart';

/// CustomPainter that renders drifting cloud shapes.
///
/// Used as an ambient background animation on Home and detail screens.
class CloudPainter extends CustomPainter {
  CloudPainter({required this.colors, required this.time});

  final CloudColors colors;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.surface2.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Draw 3 drifting cloud ellipses.
    for (var i = 0; i < 3; i++) {
      final phase = time + (i * math.pi * 0.7);
      final x = (math.sin(phase * 0.3) * 0.5 + 0.5) * size.width;
      final y = size.height * (0.2 + i * 0.25);
      final rx = 100.0 + i * 50;
      final ry = 40.0 + i * 20;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CloudPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
