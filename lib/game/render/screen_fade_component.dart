import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Black cut used when going through a door: fades to black while the step
/// plays, holds a moment, then fades back in on the new place.
final class ScreenFadeComponent extends PositionComponent {
  ScreenFadeComponent({required Vector2 size})
    : super(size: size, priority: 1000);

  static const double fadeOut = 0.13;
  static const double hold = 0.12;
  static const double fadeIn = 0.35;

  double _elapsed = 0;
  final ui.Paint _paint = ui.Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= fadeOut + hold + fadeIn) {
      removeFromParent();
    }
  }

  double get _alpha {
    if (_elapsed < fadeOut) {
      return _elapsed / fadeOut;
    }
    if (_elapsed < fadeOut + hold) {
      return 1;
    }
    return (1 - (_elapsed - fadeOut - hold) / fadeIn).clamp(0, 1);
  }

  @override
  void render(ui.Canvas canvas) {
    _paint.color = ui.Color.fromRGBO(0, 0, 0, _alpha);
    canvas.drawRect(size.toRect(), _paint);
  }
}
