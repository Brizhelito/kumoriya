import 'package:flutter/widgets.dart';

import '../tokens/cloud_colors.dart';
import '../tokens/cloud_gradients.dart';
import '../textures/cloud_painter.dart';
import '../textures/starfield_painter.dart';
import '../textures/washi_overlay.dart';

/// Animated background that changes based on the active universe.
///
/// Anime: sky gradient + drifting clouds (or starfield in Noche mode).
/// Manga: washi paper gradient + subtle noise overlay.
class UniverseBackground extends StatefulWidget {
  const UniverseBackground({
    super.key,
    required this.universe,
    required this.colors,
    required this.child,
  });

  final String universe;
  final CloudColors colors;
  final Widget child;

  @override
  State<UniverseBackground> createState() => _UniverseBackgroundState();
}

class _UniverseBackgroundState extends State<UniverseBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = widget.universe == 'anime';
    final isManga = widget.universe == 'manga';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final time = _controller.value * 2 * 3.14159;
        return Stack(
          children: <Widget>[
            // Background gradient
            Positioned.fill(
              child: ColoredBox(
                color: widget.colors.bg,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isAnime
                        ? CloudGradients.sky(widget.colors)
                        : isManga
                        ? CloudGradients.washi()
                        : null,
                  ),
                ),
              ),
            ),
            // Ambient textures
            if (isAnime && !widget.colors.isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: CloudPainter(colors: widget.colors, time: time),
                ),
              ),
            if (isAnime && widget.colors.isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: StarfieldPainter(colors: widget.colors, time: time),
                ),
              ),
            if (isManga) const Positioned.fill(child: WashOverlay()),
            // Content
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
