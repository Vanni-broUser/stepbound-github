import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// The Duomo's wrought-iron gate. The baked harbour shows its leaves folded
/// open; this component covers the alley with bars until the story changes
/// the gate tiles to floor.
final class ChurchyardGateComponent extends PositionComponent {
  ChurchyardGateComponent({
    required this.gate,
    required this.map,
    double tileSize = 16,
  }) : super(
         position: Vector2(gate.left * tileSize, gate.top * tileSize - 1),
         size: Vector2((gate.right - gate.left + 1) * tileSize, tileSize + 1),
         priority: 19,
       );

  final GridRect gate;
  final TileMap map;
  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  bool get _closed => !map.tileAt(GridPoint(gate.left, gate.top)).isWalkable;

  void _rect(
    ui.Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    ui.Color color,
  ) {
    _paint.color = color;
    canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), _paint);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!_closed) {
      return;
    }
    const iron = ui.Color(0xff26262a);
    const shine = ui.Color(0xff5c5e64);
    const rust = ui.Color(0xff7a4a2c);
    for (var x = 3.0; x < size.x - 3; x += 4) {
      _rect(canvas, x, 1, 2, 14, iron);
      _rect(canvas, x, 1, 1, 14, shine);
      _rect(canvas, x, 0, 2, 1, iron);
    }
    _rect(canvas, 0, 3, size.x, 2, iron);
    _rect(canvas, 0, 3, size.x, 1, shine);
    _rect(canvas, 0, 10, size.x, 1, iron);
    final middle = size.x / 2;
    _rect(canvas, middle - 1, 3, 2, 12, iron);
    for (var y = 6.0; y < 13; y += 2) {
      _rect(canvas, middle - 4, y, 8, 1, rust);
    }
    _rect(canvas, middle - 2, 8, 4, 4, const ui.Color(0xffa0663a));
  }
}

/// The Bar Arcobaleno's service door. The background contains the open
/// doorway; the closed leaf disappears when the key turns its tile into
/// floor, and with it the glint every interactable object wears.
final class BarServiceDoorComponent extends PositionComponent {
  BarServiceDoorComponent({
    required this.door,
    required this.map,
    double tileSize = 16,
  }) : super(
         position: Vector2(door.x * tileSize, (door.y - 1) * tileSize),
         size: Vector2(tileSize, tileSize * 2),
         priority: 19,
       );

  final GridPoint door;
  final TileMap map;
  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  bool get _closed => !map.tileAt(door).isWalkable;

  void _rect(
    ui.Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    ui.Color color,
  ) {
    _paint.color = color;
    canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), _paint);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!_closed) {
      return;
    }
    _rect(canvas, 1, 0, 14, 32, const ui.Color(0xff181616));
    _rect(canvas, 3, 2, 10, 29, const ui.Color(0xff483022));
    _rect(canvas, 4, 3, 8, 2, const ui.Color(0xff6c4c32));
    _rect(canvas, 4, 18, 8, 1, const ui.Color(0xff2c1e18));
    _rect(canvas, 11, 23, 2, 2, const ui.Color(0xffbc9e52));
  }
}

/// Don Angelo, as the mass left him: face down across his own tile, the
/// cassock torn open, one hand still reaching down the nave and the blood
/// spread out under him. He is drawn under everyone who walks the nave
/// (the backpack beside him rides higher) and his tile is made an obstacle
/// by the game, so Mario steps around the body rather than over it.
final class PriestCorpseComponent extends PositionComponent {
  PriestCorpseComponent({required GridPoint tile, double tileSize = 16})
    : super(
        position: Vector2(tile.x * tileSize, tile.y * tileSize),
        size: Vector2.all(tileSize),
        priority: 14,
      );

  static const ui.Color cassock = ui.Color(0xff1b1a1f);
  static const ui.Color cassockFold = ui.Color(0xff2e2c34);
  static const ui.Color sash = ui.Color(0xff5c2f5e);
  static const ui.Color skin = ui.Color(0xff9a8a86);
  static const ui.Color bloodDark = ui.Color(0xff4a1113);
  static const ui.Color blood = ui.Color(0xff7c1a1c);

  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  void _rect(
    ui.Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    ui.Color color,
  ) {
    _paint.color = color;
    canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), _paint);
  }

  @override
  void render(ui.Canvas canvas) {
    // The pool first: it spreads wider than the body lying in it.
    _rect(canvas, 1, 9, 14, 6, bloodDark);
    _rect(canvas, 3, 11, 11, 3, blood);
    _rect(canvas, 0, 12, 2, 2, bloodDark);
    // The body, laid out west to east along the aisle.
    _rect(canvas, 3, 5, 10, 7, cassock);
    _rect(canvas, 4, 6, 8, 2, cassockFold);
    _rect(canvas, 5, 9, 7, 1, cassockFold);
    // The torn violet sash across the shoulders, and the head beyond it.
    _rect(canvas, 4, 8, 6, 1, sash);
    _rect(canvas, 11, 8, 2, 1, sash);
    _rect(canvas, 2, 4, 4, 3, skin);
    _rect(canvas, 2, 4, 4, 1, cassockFold);
    // The hand left reaching down the nave.
    _rect(canvas, 13, 10, 2, 2, skin);
  }
}
