import 'package:flutter/widgets.dart';

/// Was paper texture overlay for the manga universe.
///
/// Renders a subtle sepia-tinted noise texture as a semi-transparent
/// overlay on manga reading surfaces.
class WashOverlay extends StatelessWidget {
  const WashOverlay({super.key, this.opacity = 0.06});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    // Placeholder: uses a solid warm color as a stand-in for the
    // actual noise texture that would be loaded from an SVG or image asset.
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: ColoredBox(
          color: const Color(0xFFD8C8A8),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
