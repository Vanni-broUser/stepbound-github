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
