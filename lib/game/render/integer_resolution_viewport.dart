import 'dart:math' as math;
import 'dart:ui';

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

  /// The narrowest and the widest shape the view takes: past them (a
  /// window squeezed into a strip) it keeps the nearest one's scale, and
  /// the screen just shows a little more along its long side.
  static const double minAspect = 4 / 3;
  static const double maxAspect = 2.4;

  /// How much of the world, in pixels, the game shows on a screen of
  /// [availableWidth] by [availableHeight]: the screen's own shape, with
  /// as much ground in it as the 16:9 view. A long phone sees a few
  /// columns more and a few rows less, a tablet the other way round, and a
  /// big screen does not see more of the map, only bigger.
  static Size worldViewFor(double availableWidth, double availableHeight) {
    if (availableWidth <= 0 || availableHeight <= 0) {
      return const Size(virtualWidth, virtualHeight);
    }
    final aspect = (availableWidth / availableHeight).clamp(
      minAspect,
      maxAspect,
    );
    final height = math.sqrt(virtualWidth * virtualHeight / aspect);
    return Size(height * aspect, height);
  }
}
