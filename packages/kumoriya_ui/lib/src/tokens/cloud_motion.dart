import 'package:flutter/animation.dart';

/// Cloudy Cozy motion tokens.
///
/// The design system favors slow, gentle motion — "the app breathes
/// with you, it doesn't rush you."
abstract final class CloudMotion {
  /// easeOutQuint — primary curve for most transitions.
  /// `cubic-bezier(0.22, 1, 0.36, 1)`
  static const Curve easeCloud = Cubic(0.22, 1, 0.36, 1);

  /// easeInOutCubic — for symmetric in/out transitions.
  /// `cubic-bezier(0.65, 0, 0.35, 1)`
  static const Curve easeRain = Cubic(0.65, 0, 0.35, 1);

  /// 200ms — fast feedback (hover, press, small state changes).
  static const Duration fast = Duration(milliseconds: 200);

  /// 400ms — base transitions (card lift, screen fade, color change).
  static const Duration base = Duration(milliseconds: 400);

  /// 600ms — slow transitions (page enter, large transforms).
  static const Duration slow = Duration(milliseconds: 600);

  /// 30s — ambient cloud drift loop (minimum).
  static const Duration ambientMin = Duration(seconds: 30);

  /// 60s — ambient cloud drift loop (maximum).
  static const Duration ambientMax = Duration(seconds: 60);
}
