import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// The interact symbol, floating over a tile worth pressing the button at:
/// the same hand the interact button wears, on a dark plate with a little
/// point under it, bobbing so it reads as a prompt rather than as part of
/// the street. It shows only while [active] says so.
final class InteractMarkerComponent extends PositionComponent {
  InteractMarkerComponent({
    required GridPoint tile,
    required this.active,
    double tileSize = 16,
  }) : super(
         position: Vector2(tile.x * tileSize, tile.y * tileSize),
         size: Vector2.all(tileSize),
         // Above the darkness indoors, like the panel glint, so it is seen
         // wherever it stands.
         priority: 30,
       );

  /// The hand of the interact button, 7x8: `#` the cuff and fingers, `.`
  /// nothing.
  static const List<String> _hand = <String>[
    '..##...',
    '..##...',
    '..##.##',
    '..##.##',
    '..#####',
    '.######',
    '.######',
    '..####.',
  ];

  static const double _plateWidth = 11;
  static const double _plateHeight = 12;

  /// How high the plate floats over the tile, and how far it bobs.
  static const double _lift = 13;
  static const double _bob = 1.5;

  final bool Function() active;
  double _time = 0;

  final ui.Paint _plate = ui.Paint()
    ..color = const ui.Color(0xe6111718)
    ..isAntiAlias = false;
  final ui.Paint _edge = ui.Paint()
    ..color = const ui.Color(0xff6c7078)
    ..isAntiAlias = false;
  final ui.Paint _ink = ui.Paint()
    ..color = const ui.Color(0xffded6c6)
    ..isAntiAlias = false;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!active()) {
      return;
    }
    final bob = (math.sin(_time * 2.4) * _bob).roundToDouble();
    final left = ((size.x - _plateWidth) / 2).roundToDouble();
    final top = -_lift + bob;
    canvas
      ..drawRect(
        ui.Rect.fromLTWH(left - 1, top - 1, _plateWidth + 2, _plateHeight + 2),
        _edge,
      )
      ..drawRect(ui.Rect.fromLTWH(left, top, _plateWidth, _plateHeight), _plate)
      // The point under the plate, aimed at the tile.
      ..drawRect(
        ui.Rect.fromLTWH(left + 4, top + _plateHeight + 1, 3, 1),
        _edge,
      )
      ..drawRect(
        ui.Rect.fromLTWH(left + 5, top + _plateHeight + 2, 1, 1),
        _edge,
      );
    for (var y = 0; y < _hand.length; y++) {
      for (var x = 0; x < _hand[y].length; x++) {
        if (_hand[y][x] == '#') {
          canvas.drawRect(
            ui.Rect.fromLTWH(left + 2 + x, top + 2 + y, 1, 1),
            _ink,
          );
        }
      }
    }
  }
}
