import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// The steel shutter of Luigi's shop: a grid of bars standing on [bars],
/// taller than the tiles so it covers Luigi's legs. When the tiles turn to
/// floor (the panel was used) it rolls up and vanishes.
final class ShutterComponent extends PositionComponent {
  ShutterComponent({
    required this.bars,
    required this.map,
    double tileSize = 16,
  }) : super(
         position: Vector2(bars.left * tileSize, (bars.top + 1) * tileSize),
         size: Vector2((bars.right - bars.left + 1) * tileSize, shutterHeight),
         anchor: Anchor.bottomLeft,
         priority: 21,
       );

  static const double shutterHeight = 26;
  static const double liftSeconds = 1.1;

  final GridRect bars;
  final TileMap map;
  double _lift = 0;

  final ui.Paint _bar = ui.Paint()
    ..color = const ui.Color(0xff6c7078)
    ..isAntiAlias = false;
  final ui.Paint _shine = ui.Paint()
    ..color = const ui.Color(0xffa4a8b0)
    ..isAntiAlias = false;
  final ui.Paint _rust = ui.Paint()
    ..color = const ui.Color(0xff7a4a30)
    ..isAntiAlias = false;

  bool get _closed =>
      map.tileAt(GridPoint(bars.left, bars.top)).kind == TileKind.obstacle;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_closed && _lift < 1) {
      _lift = (_lift + dt / liftSeconds).clamp(0, 1);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_lift >= 1) {
      return;
    }
    final w = size.x;
    // Rolling up: the grid shortens from the bottom into its top box.
    final visible = shutterHeight * (1 - _lift);
    canvas
      ..save()
      ..clipRect(ui.Rect.fromLTWH(0, 0, w, visible));
    for (var x = 1.0; x < w; x += 4) {
      canvas
        ..drawRect(ui.Rect.fromLTWH(x, 3, 1, shutterHeight - 3), _bar)
        ..drawRect(ui.Rect.fromLTWH(x + 1, 3, 1, shutterHeight - 3), _shine);
    }
    for (var y = 6.0; y < shutterHeight; y += 5) {
      canvas.drawRect(ui.Rect.fromLTWH(0, y, w, 1), _bar);
    }
    canvas
      ..drawRect(const ui.Rect.fromLTWH(7, 14, 3, 2), _rust)
      ..drawRect(ui.Rect.fromLTWH(w - 12, 9, 2, 3), _rust)
      ..restore()
      // The box the shutter rolls into, always on top.
      ..drawRect(ui.Rect.fromLTWH(0, 0, w, 3), _bar)
      ..drawRect(ui.Rect.fromLTWH(0, 0, w, 1), _shine);
  }
}
