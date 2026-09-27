import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stepbound/ui/blood_decor.dart';

/// The dark crust round everything written in blood, as round the titles.
const Color _crust = Color(0xff1c0404);

/// A stroke of a finger dipped in blood, from [from] to [to], bowed by
/// [bend] (a fraction of its length, to the left of the way it goes): thick
/// where the finger came down, thinning as it runs dry. Only the first
/// [drawn] of it is there, so it can be seen being made.
Path _bloodStroke(
  Offset from,
  Offset to, {
  required double width,
  double bend = 0,
  double drawn = 1,
  int wobbleSeed = 0,
}) {
  final along = to - from;
  final length = along.distance;
  if (length == 0 || drawn <= 0) {
    return Path();
  }
  final unit = along / length;
  final normal = Offset(-unit.dy, unit.dx);
  final control = from + along / 2 + normal * (bend * length);
  Offset at(double t) {
    final u = 1 - t;
    return from * (u * u) + control * (2 * u * t) + to * (t * t);
  }

  double half(double t) {
    // Loaded at the start, dry at the end, and never quite even: a hand
    // does not press the same all the way.
    final load = math.pow(1 - t * 0.85, 0.7).toDouble();
    final wobble = 1 + 0.18 * math.sin(t * 9 + wobbleSeed * 1.7);
    return width / 2 * load * wobble;
  }

  const steps = 14;
  final end = drawn.clamp(0.0, 1.0);
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final t = end * i / steps;
    final point = at(t);
    final next = at(math.min(1, t + 0.01));
    final previous = at(math.max(0, t - 0.01));
    var tangent = next - previous;
    tangent = tangent.distance == 0 ? unit : tangent / tangent.distance;
    final side = Offset(-tangent.dy, tangent.dx) * half(t);
    left.add(point + side);
    right.add(point - side);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  for (final point in left.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  // A rounded tip where the stroke has got to.
  final tip = at(end);
  path.arcToPoint(
    right.last,
    radius: Radius.circular(math.max(0.1, half(end))),
  );
  for (final point in right.reversed.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  path.close();
  if (end < 1) {
    path.addOval(Rect.fromCircle(center: tip, radius: half(end)));
  }
  return path;
}

/// Paints [stroke] as blood: a crust round it, the blood over it.
void _paintBlood(Canvas canvas, Path stroke, {required double crust}) {
  canvas
    ..drawPath(
      stroke,
      Paint()
        ..color = _crust
        ..style = PaintingStyle.stroke
        ..strokeWidth = crust * 2
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawPath(stroke, Paint()..color = BloodColors.fresh);
}

/// The hand-drawn line under a city's name in the corner: a smear of blood
/// going slightly uphill, thick where the finger came down on the left.
final class BloodSlashPainter extends CustomPainter {
  const BloodSlashPainter({this.thickness = 3});

  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _bloodStroke(
      Offset(thickness / 2, size.height - thickness / 2),
      Offset(size.width - thickness / 2, thickness / 2),
      width: thickness,
      bend: 0.03,
      wobbleSeed: 3,
    );
    _paintBlood(canvas, stroke, crust: thickness * 0.22);
    // A drop run down from where the finger pressed hardest.
    final drip = Offset(size.width * 0.16, size.height * 0.8);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            drip.dx - thickness * 0.2,
            drip.dy,
            thickness * 0.4,
            thickness * 1.6,
          ),
          Radius.circular(thickness * 0.2),
        ),
        Paint()..color = BloodColors.fresh,
      )
      ..drawCircle(
        drip + Offset(0, thickness * 1.7),
        thickness * 0.34,
        Paint()..color = BloodColors.fresh,
      );
  }

  @override
  bool shouldRepaint(BloodSlashPainter oldDelegate) =>
      oldDelegate.thickness != thickness;
}

/// A mission's box: a square drawn by hand in white, four strokes that
/// are never quite straight and cross at the corners, each box a little
/// different from the next ([seed]). It is crossed out in blood as
/// [crossed] goes from 0 to 1, one stroke after the other, running past
/// its sides as a hurried hand would.
final class MissionBoxPainter extends CustomPainter {
  const MissionBoxPainter({this.crossed = 0, this.border = 1.2, this.seed = 0});

  final double crossed;
  final double border;
  final int seed;

  /// A steady number in -1..1 for the [index]th wobble of this box.
  double _jitter(int index) {
    final x = math.sin((seed * 31 + index) * 12.9898) * 43758.5453;
    return (x - x.floorToDouble()) * 2 - 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final inset = border / 2;
    final wobble = size.width * 0.07;
    // The corners, each a little off true.
    final corners = <Offset>[
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(size.width - inset, size.height - inset),
      Offset(inset, size.height - inset),
    ];
    for (final (i, corner) in corners.indexed) {
      corners[i] = corner + Offset(_jitter(i * 2), _jitter(i * 2 + 1)) * wobble;
    }
    final pen = Paint()
      ..color = const Color(0xfff2ece2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var side = 0; side < 4; side++) {
      final from = corners[side];
      final to = corners[(side + 1) % 4];
      final along = to - from;
      final unit = along / along.distance;
      final normal = Offset(-unit.dy, unit.dx);
      // Started a touch early and carried a touch past the corner, bowed
      // a little, pressed a little harder or lighter than the last.
      final start = from - unit * (wobble * (0.6 + 0.5 * _jitter(10 + side)));
      final end = to + unit * (wobble * (0.8 + 0.6 * _jitter(20 + side)));
      final bow = normal * (wobble * 0.9 * _jitter(30 + side));
      final middle = (start + end) / 2 + bow;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(middle.dx, middle.dy, end.dx, end.dy),
        pen..strokeWidth = border * (1 + 0.2 * _jitter(40 + side)),
      );
    }
    if (crossed <= 0) {
      return;
    }
    final over = size.width * 0.2;
    final width = size.width * 0.46;
    final first = (crossed * 2).clamp(0.0, 1.0);
    final second = (crossed * 2 - 1).clamp(0.0, 1.0);
    _paintBlood(
      canvas,
      _bloodStroke(
        Offset(-over, -over * 0.8),
        Offset(size.width + over * 0.6, size.height + over),
        width: width,
        bend: -0.05,
        drawn: first,
      ),
      crust: width * 0.14,
    );
    if (second > 0) {
      _paintBlood(
        canvas,
        _bloodStroke(
          Offset(size.width + over * 0.8, -over),
          Offset(-over * 0.5, size.height + over * 0.7),
          width: width * 0.9,
          bend: 0.06,
          drawn: second,
          wobbleSeed: 5,
        ),
        crust: width * 0.14,
      );
    }
  }

  @override
  bool shouldRepaint(MissionBoxPainter oldDelegate) =>
      oldDelegate.crossed != crossed ||
      oldDelegate.border != border ||
      oldDelegate.seed != seed;
}

/// A mission's text beside its box: white, with a dark shadow so it reads
/// over any street.
TextStyle missionTextStyle(double fontSize) => TextStyle(
  color: const Color(0xfff2ece2),
  fontFamily: 'monospace',
  fontSize: fontSize,
  fontWeight: FontWeight.bold,
  height: 1.2,
  decoration: TextDecoration.none,
  shadows: const <Shadow>[
    Shadow(color: Color(0xe6000000), offset: Offset(1, 1)),
    Shadow(color: Color(0x99000000), blurRadius: 3),
  ],
);
