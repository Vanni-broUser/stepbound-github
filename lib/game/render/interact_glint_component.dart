import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// The small white four-pointed star that says "press interact here". The
/// backpacks give it off, and so does everything else Mario can use: the
/// panels, the map in the train, the gap between the roofs, the books, the
/// cot, the locked doors, the robe in the Duomo, the campfires. One look
/// for every object, so the player learns it once; the people Mario can
/// talk to wear none.
abstract final class Glint {
  static const ui.Color color = ui.Color(0xfffff6d8);

  /// On for a flash every couple of seconds, [time] seconds in.
  static bool litAt(double time) => (time * 0.6) % 1 < 0.12;

  /// The star with its middle pixel at [x], [y].
  static void paint(ui.Canvas canvas, double x, double y, ui.Paint paint) {
    canvas
      ..drawRect(ui.Rect.fromLTWH(x, y - 1, 1, 3), paint)
      ..drawRect(ui.Rect.fromLTWH(x - 1, y, 3, 1), paint);
  }
}

/// The [Glint] on a tile Mario can interact with, at [spot] within it
/// (pixels from the tile's top left; it may lie outside the tile, over a
/// head or between two tiles). It shows while [active] says so.
final class InteractGlintComponent extends PositionComponent {
  InteractGlintComponent({
    required GridPoint tile,
    required this.active,
    this.spot = const ui.Offset(8, 6),
    double tileSize = 16,
  }) : super(
         position: Vector2(tile.x * tileSize, tile.y * tileSize),
         size: Vector2.all(tileSize),
         // Above the darkness indoors and the characters, so it catches the
         // eye like a lamp wherever it is.
         priority: 30,
       );

  final bool Function() active;
  final ui.Offset spot;
  double _time = 0;
  final ui.Paint _paint = ui.Paint()
    ..color = Glint.color
    ..isAntiAlias = false;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(ui.Canvas canvas) {
    if (active() && Glint.litAt(_time)) {
      Glint.paint(canvas, spot.dx, spot.dy, _paint);
    }
  }
}
