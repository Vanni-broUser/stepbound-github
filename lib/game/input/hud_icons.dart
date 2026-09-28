/// The icons drawn on the touch controls: the pistol on the aiming stick,
/// and what Mario carries on the badges in the corner. Each one is drawn
/// on a small grid of its own and scaled to whatever size it is given.
library;

import 'package:flutter/material.dart';

/// The pistol in one flat colour, for the aiming stick's cancel ring.
final class PistolIcon extends CustomPainter {
  const PistolIcon({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawRect(const Rect.fromLTWH(2, 8, 19, 4.5), paint)
      ..drawRect(const Rect.fromLTWH(16, 5.5, 3, 2.5), paint)
      ..drawRect(const Rect.fromLTWH(10, 12.5, 2.5, 3.5), paint)
      ..drawPath(
        Path()
          ..moveTo(14, 12.5)
          ..lineTo(18.5, 12.5)
          ..lineTo(16.5, 21.5)
          ..lineTo(12, 21.5)
          ..close(),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(PistolIcon oldDelegate) => oldDelegate.color != color;
}

/// A thurible swinging on its chain, smoking: the ring at the top, the
/// three chains down to the pierced lid, the bowl under it.
final class CenserIcon extends CustomPainter {
  const CenserIcon();

  static const Color _brass = Color(0xffd6b25c);
  static const Color _brassDark = Color(0xff8a6a2e);
  static const Color _chain = Color(0xffd8cfbf);
  static const Color _hole = Color(0xff3a2a14);
  static const Color _smoke = Color(0x55e6ded0);

  @override
  void paint(Canvas canvas, Size size) {
    final brass = Paint()..color = _brass;
    final dark = Paint()..color = _brassDark;
    final chain = Paint()..color = _chain;
    final hole = Paint()..color = _hole;
    final smoke = Paint()..color = _smoke;
    final ring = Paint()
      ..color = _chain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..save()
      // Drawn in a 24-wide square, then scaled to whatever it is given.
      ..scale(size.width / 24)
      ..drawCircle(const Offset(12, 2.5), 2.2, ring)
      // the three chains, the outer two splayed to the rim of the lid
      ..drawRect(const Rect.fromLTWH(11.25, 4.5, 1.5, 7.5), chain)
      ..drawRect(const Rect.fromLTWH(5.5, 8, 1.5, 4), chain)
      ..drawRect(const Rect.fromLTWH(17, 8, 1.5, 4), chain)
      ..drawRect(const Rect.fromLTWH(5.5, 8, 13, 1.5), chain)
      // the pierced lid, smoke coming through it
      ..drawPath(
        Path()
          ..moveTo(12, 9.5)
          ..lineTo(18.5, 15)
          ..lineTo(5.5, 15)
          ..close(),
        brass,
      )
      ..drawRect(const Rect.fromLTWH(9, 13, 1.5, 1.5), hole)
      ..drawRect(const Rect.fromLTWH(13.5, 13, 1.5, 1.5), hole)
      ..drawRect(const Rect.fromLTWH(4.5, 15, 15, 1.5), dark)
      // the bowl
      ..drawPath(
        Path()
          ..moveTo(5, 16.5)
          ..lineTo(19, 16.5)
          ..lineTo(16, 23.5)
          ..lineTo(8, 23.5)
          ..close(),
        brass,
      )
      ..drawRect(const Rect.fromLTWH(7, 20, 10, 1.5), dark)
      // the smoke, curling away from the lid
      ..drawRect(const Rect.fromLTWH(2.5, 11.5, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(1, 8.5, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(20, 11, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(21.5, 7.5, 2, 1.5), smoke)
      ..restore();
  }

  @override
  bool shouldRepaint(CenserIcon oldDelegate) => false;
}

/// The Duomo's own key: old iron, its bow a cross, so that it is not the
/// bar's brass key at a glance.
final class ChurchKeyIcon extends CustomPainter {
  const ChurchKeyIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final iron = Paint()..color = const Color(0xff8e949c);
    final dark = Paint()..color = const Color(0xff4e545c);
    canvas
      ..save()
      ..scale(size.width / 24)
      // the cross lies on its side: its long arm is the shaft itself
      ..drawRect(const Rect.fromLTWH(1, 9, 21, 3), iron)
      ..drawRect(const Rect.fromLTWH(1, 11, 21, 1), dark)
      ..drawRect(const Rect.fromLTWH(5, 3, 3, 15), iron)
      ..drawRect(const Rect.fromLTWH(7, 3, 1, 15), dark)
      // the bit
      ..drawRect(const Rect.fromLTWH(16, 12, 3, 5), iron)
      ..drawRect(const Rect.fromLTWH(19, 12, 3, 3), iron)
      ..restore();
  }

  @override
  bool shouldRepaint(ChurchKeyIcon oldDelegate) => false;
}

/// The bar's brass key: a round bow with a hole, a plain shaft and bit.
final class KeyIcon extends CustomPainter {
  const KeyIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xffd6b25c);
    final dark = Paint()..color = const Color(0xff8a6a2e);
    final hole = Paint()..color = const Color(0xff3a2618);
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawCircle(const Offset(7, 8), 6, dark)
      ..drawCircle(const Offset(7, 8), 4.5, gold)
      ..drawCircle(const Offset(7, 8), 2.2, hole)
      ..drawRect(const Rect.fromLTWH(10, 7, 12, 3), gold)
      ..drawRect(const Rect.fromLTWH(17, 10, 3, 4), gold)
      ..drawRect(const Rect.fromLTWH(20, 10, 2, 3), gold)
      ..drawRect(const Rect.fromLTWH(11, 9, 11, 1), dark)
      ..restore();
  }

  @override
  bool shouldRepaint(KeyIcon oldDelegate) => false;
}

/// A bottle of spirits with a rag stuffed in its neck, the rag alight.
/// Pixel art on a 12x16 grid.
final class MolotovIcon extends CustomPainter {
  const MolotovIcon();

  static const List<String> _pixels = <String>[
    '.....yo.....',
    '....oyyo....',
    '....oyro....',
    '.....rr.....',
    '.....cc.....',
    '.....cC.....',
    '.....gG.....',
    '.....gG.....',
    '....gggG....',
    '...ggLggG...',
    '...gLlggG...',
    '...gLgggG...',
    '...gLlggG...',
    '...gggggG...',
    '...gggggG...',
    '....dddd....',
  ];

  static const Map<String, Color> _colors = <String, Color>{
    'y': Color(0xffffd23f),
    'o': Color(0xffff8a1c),
    'r': Color(0xffd6341c),
    'c': Color(0xffd9c9a3),
    'C': Color(0xffa8987a),
    'g': Color(0xff4f8a3c),
    'G': Color(0xff2f5a26),
    'L': Color(0xff9fd07a),
    'l': Color(0xffe0a03a),
    'd': Color(0xff1f3a1a),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _pixels.first.length;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < _pixels.length; y++) {
      final row = _pixels[y];
      for (var x = 0; x < row.length; x++) {
        final color = _colors[row[x]];
        if (color == null) {
          continue;
        }
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.1, cell + 0.1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MolotovIcon oldDelegate) => false;
}

/// A semi-automatic pistol in profile, muzzle to the right, like the ones
/// the carabinieri carry: the blued steel slide with its serrations and the
/// barrel showing at the front, the hammer cocked at the back, the trigger
/// in its guard, and the grip in dark walnut.
final class ColourPistolIcon extends CustomPainter {
  const ColourPistolIcon({this.golden = false});

  /// Luigi's golden pistol: the same gun, its metal all gold.
  final bool golden;

  static const Color _outline = Color(0xff121417);
  Color get _steel =>
      golden ? const Color(0xffd4a22c) : const Color(0xff66707c);
  Color get _steelDark =>
      golden ? const Color(0xff8c6414) : const Color(0xff3c434c);
  Color get _steelLight =>
      golden ? const Color(0xfffbe38a) : const Color(0xffb4bec9);
  static const Color _wood = Color(0xff8e5a32);
  static const Color _woodDark = Color(0xff5c361c);
  static const Color _woodLight = Color(0xffb47c4a);
  static const Color _sight = Color(0xffeee6d2);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p(Color color) => Paint()..color = color;
    // The grip, raked back under the rear of the slide.
    final grip = Path()
      ..moveTo(4, 8.5)
      ..lineTo(13, 8.5)
      ..lineTo(11.2, 21)
      ..lineTo(2.2, 21)
      ..quadraticBezierTo(1, 21, 1.3, 19.6)
      ..close();
    final gripFace = Path()
      ..moveTo(5, 10.5)
      ..lineTo(11.6, 10.5)
      ..lineTo(10.2, 19.8)
      ..lineTo(3.2, 19.8)
      ..close();
    // The trigger guard: a ring hanging under the frame.
    final guard = Path()
      ..moveTo(12.5, 10)
      ..lineTo(20.5, 10)
      ..lineTo(20.5, 13)
      ..quadraticBezierTo(20.5, 16.5, 16.5, 16.5)
      ..lineTo(12, 16.5)
      ..lineTo(12.3, 14.8)
      ..lineTo(16.5, 14.8)
      ..quadraticBezierTo(18.8, 14.8, 18.8, 12.6)
      ..lineTo(18.8, 11.7)
      ..lineTo(12.5, 11.7)
      ..close();
    canvas
      ..save()
      // Drawn on a 32 by 22 grid, then scaled to whatever it is given.
      ..scale(size.width / 32)
      // Outlines first, one unit round everything.
      ..drawRect(const Rect.fromLTWH(1, 0.5, 30, 8), p(_outline))
      ..drawRect(const Rect.fromLTWH(5, 7.5, 20, 4), p(_outline))
      ..drawPath(grip.shift(const Offset(-0.8, 0)), p(_outline))
      ..drawPath(grip.shift(const Offset(0.8, 0.8)), p(_outline))
      ..drawPath(guard, p(_steelDark))
      // The barrel, its muzzle showing past the slide.
      ..drawRect(const Rect.fromLTWH(27, 3.5, 3, 3.5), p(_steelDark))
      ..drawRect(const Rect.fromLTWH(29, 4.3, 1, 1.8), p(_outline))
      // The slide, lit along the top, with its sights.
      ..drawRect(const Rect.fromLTWH(3, 1.5, 24.5, 6), p(_steel))
      ..drawRect(const Rect.fromLTWH(3, 1.5, 24.5, 1.2), p(_steelLight))
      ..drawRect(const Rect.fromLTWH(3, 6.3, 24.5, 1.2), p(_steelDark))
      ..drawRect(const Rect.fromLTWH(25.5, 0, 1.5, 1.5), p(_sight))
      ..drawRect(const Rect.fromLTWH(4, 0.3, 2.5, 1.2), p(_steelDark))
      // The ejection port.
      ..drawRect(const Rect.fromLTWH(16, 2.8, 5, 2.2), p(_outline))
      // The hammer, cocked.
      ..drawRect(const Rect.fromLTWH(1.2, 1.2, 2.2, 3.5), p(_steelDark))
      // The frame under the slide, and the trigger.
      ..drawRect(const Rect.fromLTWH(6, 7.5, 18.5, 2.8), p(_steelDark))
      ..drawRect(const Rect.fromLTWH(6, 7.5, 18.5, 0.8), p(_steel))
      ..drawRect(const Rect.fromLTWH(15, 10, 1.4, 3.2), p(_steelLight))
      // The grip in walnut, its face lit on the front edge.
      ..drawPath(grip, p(_woodDark))
      ..drawPath(gripFace, p(_wood))
      ..drawRect(const Rect.fromLTWH(10.2, 10.5, 1.2, 8.5), p(_woodLight));
    // The slide's serrations at the back.
    for (var x = 5.0; x < 11; x += 1.6) {
      canvas.drawRect(Rect.fromLTWH(x, 3.5, 0.7, 2.6), p(_steelDark));
    }
    // The chequering on the grip.
    for (var y = 12.0; y < 19; y += 2) {
      final shift = (y - 10.5) * 0.15;
      for (var x = 5.2 - shift; x < 9.5 - shift; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p(_woodDark));
      }
    }
    canvas
      // The grip screw, and the magazine's base plate under the grip.
      ..drawCircle(const Offset(7.4, 15.2), 0.9, p(_steelLight))
      ..drawRect(const Rect.fromLTWH(1.8, 20.3, 9.8, 1.7), p(_steelDark))
      ..restore();
  }

  @override
  bool shouldRepaint(ColourPistolIcon oldDelegate) =>
      oldDelegate.golden != golden;
}
