import 'package:flutter/foundation.dart';

/// Device form factor for adaptive layouts.
enum FormFactor {
  /// width < 600px on mobile OS.
  mobile,

  /// 600 ≤ width < 960 on mobile OS.
  tablet,

  /// width ≥ 960 on mobile OS, OR any desktop OS.
  desktop;

  /// Whether this is a desktop-class experience.
  bool get isDesktop => this == FormFactor.desktop;

  /// Whether this is a touch-first experience.
  bool get isTouch => this == FormFactor.mobile || this == FormFactor.tablet;

  /// Detects the form factor from platform + width.
  ///
  /// Desktop OS (Windows/Linux/macOS) always returns [FormFactor.desktop].
  /// Mobile OS uses width breakpoints:
  /// - < 600px → [FormFactor.mobile]
  /// - 600–960px → [FormFactor.tablet]
  /// - ≥ 960px → [FormFactor.desktop]
  static FormFactor fromPlatform({required double width}) {
    if (_isDesktopOs) return FormFactor.desktop;
    if (width >= 960) return FormFactor.desktop;
    if (width >= 600) return FormFactor.tablet;
    return FormFactor.mobile;
  }

  static bool get _isDesktopOs {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
  }
}
