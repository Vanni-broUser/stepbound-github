import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/asset_image.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';

/// A backpack on the street. It drops in with a bounce when a script
/// reveals it, glints now and then to catch the eye, and lingers for a
/// moment after being collected so Mario's hand reaches it first.
final class PickupComponent extends PositionComponent {
  PickupComponent({required this.pickup, double tileSize = 16})
    : super(
        position: Vector2(
          pickup.position.x * tileSize,
          pickup.position.y * tileSize,
        ),
        size: Vector2.all(tileSize),
        priority: 15,
      );

  static const String backpackAssetPath = 'assets/sprites/backpack.png';
  static const double dropDuration = 0.45;
  static const double lingerDuration = 0.3;

  final Pickup pickup;
  ui.Image? _image;
  late bool _wasActive = pickup.active;
  double _dropElapsed = dropDuration;
  double _lingerLeft = 0;
  double _time = 0;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  bool get isDropping => _dropElapsed < dropDuration;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Whatever it holds, what lies on the ground is a backpack.
    _image = await loadAssetImage(backpackAssetPath);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (!_wasActive && pickup.active) {
      _dropElapsed = 0;
    } else if (_wasActive && !pickup.active && pickup.collected) {
      _lingerLeft = lingerDuration;
    }
    _wasActive = pickup.active;
    if (_dropElapsed < dropDuration) {
      _dropElapsed += dt;
    }
    if (_lingerLeft > 0) {
      _lingerLeft -= dt;
    }
  }

  /// Height above the ground while dropping: a fall and one small bounce.
  double _dropOffset() {
    if (!isDropping) {
      return 0;
    }
    final t = _dropElapsed / dropDuration;
    if (t < 0.6) {
      final fall = 1 - t / 0.6;
      return -18 * fall * fall;
    }
    final bounce = (t - 0.6) / 0.4;
    return -3 * math.sin(bounce * math.pi);
  }

  @override
  void render(ui.Canvas canvas) {
    final image = _image;
    if (image == null || (!pickup.active && _lingerLeft <= 0)) {
      return;
    }
    final y = _dropOffset().roundToDouble();
    canvas.drawImage(image, ui.Offset(0, y), _paint);
    // The glint of everything to interact with, on the buckle.
    if (!isDropping && Glint.litAt(_time)) {
      _paint.color = Glint.color;
      Glint.paint(canvas, 10, 10 + y, _paint);
    }
  }
}
