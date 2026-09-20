import 'dart:math' as math;

abstract final class IntegerResolutionViewport {
  static const double virtualWidth = 384;
  static const double virtualHeight = 216;

  static int scaleFor(double availableWidth, double availableHeight) {
    final availableScale = math.min(
      availableWidth / virtualWidth,
      availableHeight / virtualHeight,
    );
    return math.max(1, availableScale.floor());
  }
}
