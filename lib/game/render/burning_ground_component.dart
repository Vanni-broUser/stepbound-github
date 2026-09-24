import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/fire_component.dart';

/// The charred ground under a tile that is burning for good
/// (`TileKind.fire`): drawn under the characters, while the flames over it
/// ([burningGround]) are drawn over them, like every other fire.
final class ScorchComponent extends PositionComponent {
  ScorchComponent(GridPoint tile, {double tileSize = 16})
    : _seed = tile.x * 7 + tile.y * 13,
      super(
        position: Vector2(tile.x * tileSize, tile.y * tileSize),
        size: Vector2.all(tileSize),
        priority: 5,
      );

  final int _seed;
  final Paint _paint = Paint()..isAntiAlias = false;

  static const Color _char = Color(0xff1b1311);
  static const Color _ash = Color(0xff3a302b);
  static const Color _ember = Color(0xffc83c14);

  @override
  void render(Canvas canvas) {
    _paint.color = _char;
    canvas.drawRect(Rect.fromLTWH(1, 1, size.x - 2, size.y - 2), _paint);
    _paint.color = _ash;
    for (var i = 0; i < 4; i++) {
      final x = (_seed * (i + 3) * 5) % 13 + 1;
      final y = (_seed * (i + 2) * 3) % 13 + 1;
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 1), _paint);
    }
    _paint.color = _ember;
    canvas.drawRect(
      Rect.fromLTWH(((_seed * 11) % 12 + 2).toDouble(), 12, 1, 1),
      _paint,
    );
  }
}

/// The two components of a tile of burning ground: the charred tile and
/// its flames. Only every other tile smokes, or a long trail of fire would
/// hide the roofs under one cloud.
List<Component> burningGround(GridPoint tile, {double tileSize = 16}) {
  final left = tile.x * tileSize;
  final top = tile.y * tileSize;
  return <Component>[
    ScorchComponent(tile, tileSize: tileSize),
    FireComponent(
      base: Vector2(left + tileSize / 2, top + 14),
      halfWidth: 5,
      flameHeight: 11,
      seed: tile.x * 31 + tile.y * 17,
      smoke: (tile.x + tile.y).isEven,
    ),
  ];
}
