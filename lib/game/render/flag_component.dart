import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// The tricolour on its pole in front of the barracks, torn to rags and
/// flapping in the wind: each column of cloth rides a wave that grows
/// towards the fly end, gusts come and go, and the loose tatters snap in
/// and out. The component's position is the foot of the pole.
final class FlagComponent extends PositionComponent {
  FlagComponent({required Vector2 foot}) : super(position: foot, priority: 18);

  /// Height of the pole above its foot, in pixels.
  static const int poleHeight = 40;

  /// The cloth, 21x13: G green, W white, R red, g/w/r their scorched
  /// shades, `.` a hole or a missing rag.
  static const List<String> cloth = <String>[
    'GGGGGGGWWWWWWWRRRRRRr',
    'GGGGGGGWWWWWWWRRRRr..',
    'GGGGGGGWWWWwWWRRRRRRr',
    'GGGGGGGWWW.WWWRRRr...',
    'GGGGGGgWWWWWwWRRRRr..',
    'GGGGGGGWWWWWW.Rr.....',
    'GGGGGGGWW..WWWRRRRRr.',
    'GGGgGGGWWWWWWWRRRR...',
    'GGGGGGGWWWWWWwRr.....',
    'GGGGGGWWWWWWW.RRr....',
    'GGGGgG.WWW.WWW.R.....',
    'GGG.G..WW...W........',
    'G.G....W.............',
  ];

  /// Loose threads under the cloth: (column, first row, length, colour).
  static const List<(int, int, int, String)> _threads =
      <(int, int, int, String)>[
        (1, 13, 2, 'G'),
        (8, 13, 2, 'W'),
        (12, 12, 3, 'W'),
        (16, 11, 2, 'r'),
      ];

  static const Map<String, Color> _colours = <String, Color>{
    'G': Color(0xff267a3a),
    'g': Color(0xff183c22),
    'W': Color(0xffe2dccc),
    'w': Color(0xff787064),
    'R': Color(0xffb82624),
    'r': Color(0xff5a1816),
  };

  final Paint _paint = Paint()..isAntiAlias = false;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  /// Vertical offset of a cloth column: nothing at the pole, a travelling
  /// wave towards the fly end, stronger during a gust.
  int _wave(int column) {
    final gust = 0.75 + 0.45 * math.sin(_time * 0.8);
    final reach = column / (cloth.first.length - 1);
    return (math.sin(_time * 6 - column * 0.55) * 2.4 * reach * gust).round();
  }

  /// Rags near the fly end snap in and out of view.
  bool _flaps(int column, int row) =>
      column >= 14 && math.sin(_time * 13 + row * 1.7 + column * 2.3) > 0.82;

  void _pixel(Canvas canvas, double x, double y, Color colour) {
    _paint.color = colour;
    canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), _paint);
  }

  void _rect(Canvas canvas, double x, double y, double w, double h, Color c) {
    _paint.color = c;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  @override
  void render(Canvas canvas) {
    const top = -poleHeight * 1.0;
    // foot, shadow, pole and gilded finial
    _rect(canvas, -2, -2, 5, 2, const Color(0xff46423f));
    _rect(canvas, 0, 0, 9, 1, const Color(0xff282628));
    _rect(canvas, 0, top, 1, poleHeight - 2, const Color(0xff96968f));
    _rect(canvas, 1, top + 1, 1, poleHeight - 3, const Color(0xff4e4e4c));
    _rect(canvas, -1, top - 2, 3, 2, const Color(0xffc8aa46));

    for (var row = 0; row < cloth.length; row++) {
      final line = cloth[row];
      for (var column = 0; column < line.length; column++) {
        final glyph = line[column];
        if (glyph == '.' || _flaps(column, row)) {
          continue;
        }
        _pixel(
          canvas,
          2.0 + column,
          top + 1 + row + _wave(column),
          _colours[glyph]!,
        );
      }
    }
    for (final (column, row, length, glyph) in _threads) {
      _rect(
        canvas,
        2.0 + column,
        top + 1 + row + _wave(column),
        1,
        length.toDouble(),
        _colours[glyph]!,
      );
    }
  }
}
