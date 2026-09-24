import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Black cut used when going through a door: fades to black while the step
/// plays, holds a moment, then fades back in on the new place ([fadeIn] is
/// longer when walking into a building, to let the room emerge slowly).
final class ScreenFadeComponent extends PositionComponent {
  ScreenFadeComponent({
    required Vector2 size,
    this.fadeIn = defaultFadeIn,
    this.onBlack,
    this.onFinished,
  }) : super(size: size, priority: 1000);

  static const double fadeOut = 0.13;
  static const double hold = 0.12;
  static const double defaultFadeIn = 0.35;
  static const double slowFadeIn = 1.1;

  final double fadeIn;
  final void Function()? onBlack;
  final void Function()? onFinished;

  double _elapsed = 0;
  bool _wentBlack = false;
  bool _finished = false;
  final ui.Paint _paint = ui.Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (!_wentBlack && _elapsed >= fadeOut) {
      _wentBlack = true;
      onBlack?.call();
    }
    if (!_finished && _elapsed >= fadeOut + hold + fadeIn) {
      _finished = true;
      onFinished?.call();
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
