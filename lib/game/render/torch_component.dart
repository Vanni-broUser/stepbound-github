import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/fire_component.dart';

/// A torch burning on a wall or a column: an iron cup on a short bracket
/// and a small flame, no smoke, animated like every fire in the game. It is
/// drawn over the darkness of the room, which its light cuts into (see
/// `LightSpot.torch`).
final class TorchComponent extends PositionComponent {
  TorchComponent({required GridPoint tile, int seed = 0, double tileSize = 16})
    : super(
        // The middle of the cup's rim, a little above the middle of the
        // tile so the flame stands on the wall or the column top.
        position: Vector2(
          tile.x * tileSize + tileSize / 2,
          tile.y * tileSize + 7,
        ),
        priority: 30,
        children: <Component>[
          FireComponent(
            base: Vector2.zero(),
            halfWidth: 2,
            flameHeight: 7,
            seed: seed,
            smoke: false,
          ),
        ],
      );

  static const ui.Color _iron = ui.Color(0xff2a2522);
  static const ui.Color _ironLight = ui.Color(0xff5a4d42);
  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  @override
  void render(ui.Canvas canvas) {
    // The bracket, under the flame drawn by the child fire.
    _paint.color = _iron;
    canvas
      ..drawRect(const ui.Rect.fromLTWH(-3, 0, 7, 2), _paint)
      ..drawRect(const ui.Rect.fromLTWH(-2, 2, 5, 1), _paint)
      ..drawRect(const ui.Rect.fromLTWH(0, 3, 1, 4), _paint);
    _paint.color = _ironLight;
    canvas.drawRect(const ui.Rect.fromLTWH(-3, 0, 7, 1), _paint);
  }
}
