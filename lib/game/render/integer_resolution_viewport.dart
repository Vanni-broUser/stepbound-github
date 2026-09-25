import 'dart:math' as math;

abstract final class IntegerResolutionViewport {
  static const double virtualWidth = 384;
  static const double virtualHeight = 216;

  /// Whole-number scale when the screen fits at least 2x, so pixels stay
  /// crisp on large displays. Below that (phones in landscape) the view
  /// fills the screen with a fractional scale instead of leaving half of
  /// it empty.
  static double scaleFor(double availableWidth, double availableHeight) {
    final availableScale = math.min(
      availableWidth / virtualWidth,
      availableHeight / virtualHeight,
    );
    return availableScale >= 2
        ? availableScale.floorToDouble()
        : availableScale;
  }
}
