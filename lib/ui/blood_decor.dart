import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Blood tones shared by the HUD and the story dialogue boxes.
abstract final class BloodColors {
  static const Color dried = Color(0xff4a0808);
  static const Color fresh = Color(0xff8e1414);
  static const Color bright = Color(0xffc42a2a);
  static const Color shine = Color(0x70ffd6d0);
}

/// A drip hanging from the top edge. [x] is a fraction of the width, or,
/// when [fromRight] is set, ignored in favour of a pixel offset from the
/// right edge. [length] and [width] are logical pixels. [falling] lists the
/// radii of drops detaching from the tip, each one further down.
final class BloodDrip {
  const BloodDrip(
    this.x,
    this.length,
    this.width, {
    this.fromRight,
    this.falling = const <double>[],
  });

  final double x;
  final double length;
  final double width;
  final double? fromRight;
  final List<double> falling;
}

/// A loose teardrop. [x] and [y] are fractions of the painted area (they can
/// fall outside 0..1 to spill past the edges), [radius] is in logical pixels.
final class BloodDrop {
  const BloodDrop(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;
}

/// Paints a wavy blood band along the top edge with drips running down from
/// it, plus optional loose drops. Band and drips are clipped to the rounded
/// shape given by [cornerRadius]; drops are not, so they can spill outside.
final class BloodPainter extends CustomPainter {
  const BloodPainter({
    this.band = 0,
    this.drips = const <BloodDrip>[],
    this.drops = const <BloodDrop>[],
    this.cornerRadius = 0,
    this.color = BloodColors.fresh,
  });

  final double band;
  final List<BloodDrip> drips;
  final List<BloodDrop> drops;
  final double cornerRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final shine = Paint()..color = BloodColors.shine;

    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(cornerRadius),
        ),
      );
    if (band > 0) {
      canvas.drawPath(_band(size), fill);
    }
    for (final drip in drips) {
      final fromRight = drip.fromRight;
      final x = fromRight == null
          ? drip.x * size.width
          : size.width - fromRight;
      final half = drip.width / 2;
      final bulbY = drip.length - half;
      canvas
        ..drawPath(
          Path()
            ..moveTo(x - half * 1.4, 0)
            ..quadraticBezierTo(
              x - half * 0.7,
              band + 1,
              x - half * 0.75,
              bulbY,
            )
            ..lineTo(x + half * 0.75, bulbY)
            ..quadraticBezierTo(x + half * 0.7, band + 1, x + half * 1.4, 0)
            ..close(),
          fill,
        )
        ..drawCircle(Offset(x, bulbY), half, fill)
        ..drawCircle(
          Offset(x - half * 0.35, bulbY - half * 0.2),
          half * 0.3,
          shine,
        );
      var fallY = drip.length;
      for (final radius in drip.falling) {
        fallY += radius * 2.6;
        _drawTeardrop(canvas, Offset(x, fallY), radius, fill, shine);
        fallY += radius;
      }
    }
    canvas.restore();

    for (final drop in drops) {
      _drawTeardrop(
        canvas,
        Offset(drop.x * size.width, drop.y * size.height),
        drop.radius,
        fill,
        shine,
      );
    }
  }

  /// Top band whose lower edge wobbles like a poured, uneven stain.
  Path _band(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, band * 0.8);
    const bumps = 7;
    final step = size.width / bumps;
    for (var i = bumps; i > 0; i--) {
      final depth = band * (i.isEven ? 1.25 : 0.7);
      path.quadraticBezierTo(
        step * (i - 0.5),
        depth,
        step * (i - 1),
        band * 0.85,
      );
    }
    return path..close();
  }

  static void _drawTeardrop(
    Canvas canvas,
    Offset center,
    double r,
    Paint fill,
    Paint shine,
  ) {
    final cx = center.dx;
    final cy = center.dy;
    final tip = Offset(cx, cy - r * 1.9);
    canvas
      ..drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..cubicTo(
            cx + r * 0.15,
            cy - r * 1.3,
            cx + r,
            cy - r * 0.7,
            cx + r,
            cy,
          )
          ..arcToPoint(Offset(cx - r, cy), radius: Radius.circular(r))
          ..cubicTo(
            cx - r,
            cy - r * 0.7,
            cx - r * 0.15,
            cy - r * 1.3,
            tip.dx,
            tip.dy,
          )
          ..close(),
        fill,
      )
      ..drawCircle(Offset(cx - r * 0.38, cy - r * 0.25), r * 0.28, shine);
  }

  @override
  bool shouldRepaint(BloodPainter oldDelegate) =>
      oldDelegate.band != band ||
      oldDelegate.drips != drips ||
      oldDelegate.drops != drops ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.color != color;
}

/// Overlays [painter] on [child] without intercepting taps.
final class BloodOverlay extends StatelessWidget {
  const BloodOverlay({required this.painter, required this.child, super.key});

  final BloodPainter painter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(foregroundPainter: painter, child: child);
  }
}

/// A title written in blood, letters and drips as one piece: the drips run
/// straight down from the bottom of the letters' strokes, share their red,
/// and a single dark crust outlines both. [fontSize] is in logical pixels.
///
/// The font behind 'monospace' differs per platform, so the drips are placed
/// by rasterising the row they start from and finding where the letters'
/// strokes actually are; until that is done the letters show without drips.
final class BloodyTitle extends StatefulWidget {
  const BloodyTitle(this.text, {required this.fontSize, super.key});

  final String text;
  final double fontSize;

  TextStyle get _style => TextStyle(
    fontFamily: 'monospace',
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: fontSize * 0.18,
    height: 1,
    decoration: TextDecoration.none,
  );

  @override
  State<BloodyTitle> createState() => _BloodyTitleState();
}

final class _BloodyTitleState extends State<BloodyTitle> {
  List<_TitleDrip> _drips = const <_TitleDrip>[];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  @override
  void didUpdateWidget(BloodyTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.fontSize != widget.fontSize) {
      _drips = const <_TitleDrip>[];
      unawaited(_measure());
    }
  }

  Future<void> _measure() async {
    final generation = ++_generation;
    final drips = await _measureDrips(widget.text, widget._style);
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _drips = drips);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget._style;
    final layout = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = Size(layout.width, layout.height + widget.fontSize * 1.4);
    layout.dispose();
    return CustomPaint(
      size: size,
      painter: _BloodyTitlePainter(
        text: widget.text,
        style: style,
        drips: _drips,
      ),
    );
  }
}

/// One drip under a letter: `x` in pixels, `length` from the drip's top,
/// `width` of the stream, and whether `drops` fall from its tip.
typedef _TitleDrip = ({double x, double length, double width, bool drops});

/// Drips start this far (in font sizes) above the baseline, inside the
/// bottom of the strokes, so they grow out of them.
const double _dripInset = 0.08;

/// Which strokes of each letter drip: the index of the ink run met along the
/// drip row (negative counts from the right), where along that run the drip
/// sits (0 left edge, 1 right edge), and how long it runs (in font sizes).
const Map<String, List<(int, double, double)>> _feet =
    <String, List<(int, double, double)>>{
      'G': <(int, double, double)>[(0, 0.6, 0.42)],
      'A': <(int, double, double)>[(-1, 0.5, 0.62)],
      'M': <(int, double, double)>[(0, 0.5, 0.3)],
      'E': <(int, double, double)>[(0, 0.2, 0.8)],
      'O': <(int, double, double)>[(0, 0.5, 0.45)],
      'V': <(int, double, double)>[(0, 0.5, 0.95)],
      'R': <(int, double, double)>[(0, 0.5, 0.35), (-1, 0.5, 0.6)],
    };

/// Rasterises the drip row of [text] and places each drip on the stroke
/// [_feet] names for its letter. Returns no drips if the row can't be read.
Future<List<_TitleDrip>> _measureDrips(String text, TextStyle style) async {
  const scale = 4.0;
  final fontSize = style.fontSize!;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(color: const Color(0xffffffff)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  try {
    final row =
        painter.computeLineMetrics().first.baseline - fontSize * _dripInset;
    final width = (painter.width * scale).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate(0, -row);
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, 1);
    picture.dispose();
    final bytes = await image.toByteData();
    image.dispose();
    if (bytes == null) {
      return const <_TitleDrip>[];
    }
    bool inked(int x) => bytes.getUint8(x * 4 + 3) > 128;

    final drips = <_TitleDrip>[];
    var seenE = 0;
    for (var i = 0; i < text.length; i++) {
      final letter = text[i];
      final feet = _feet[letter];
      if (feet == null) {
        continue;
      }
      // Only the first E drips: two identical runs look stamped.
      if (letter == 'E' && seenE++ > 0) {
        continue;
      }
      final box = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .first;
      // The ink runs of this letter along the drip row, in pixels.
      final runs = <(double, double)>[];
      int? start;
      final from = (box.left * scale).floor().clamp(0, width);
      final to = (box.right * scale).ceil().clamp(0, width);
      for (var x = from; x <= to; x++) {
        final ink = x < to && inked(x);
        if (ink && start == null) {
          start = x;
        } else if (!ink && start != null) {
          runs.add((start / scale, x / scale));
          start = null;
        }
      }
      if (runs.isEmpty) {
        continue;
      }
      for (final (foot, along, length) in feet) {
        final index = (foot < 0 ? runs.length + foot : foot).clamp(
          0,
          runs.length - 1,
        );
        final (left, right) = runs[index];
        drips.add((
          x: left + (right - left) * along,
          length: length * fontSize,
          width: fontSize * (length > 0.7 ? 0.16 : 0.12),
          drops: length > 0.75,
        ));
      }
    }
    return drips;
  } on Object {
    return const <_TitleDrip>[];
  } finally {
    painter.dispose();
  }
}

final class _BloodyTitlePainter extends CustomPainter {
  _BloodyTitlePainter({
    required this.text,
    required this.style,
    required this.drips,
  });

  final String text;
  final TextStyle style;
  final List<_TitleDrip> drips;

  static const Color _crust = Color(0xff1c0404);

  double get _fontSize => style.fontSize!;

  /// A straight run with a rounded bulb at the end and, for the longest
  /// ones, two drops falling below. [grow] thickens everything for the crust.
  void _paintDrip(Canvas canvas, _TitleDrip drip, Paint paint, double grow) {
    final half = drip.width / 2 + grow;
    final bulb = drip.width * 0.6 + grow;
    canvas
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          drip.x - half,
          0,
          drip.x + half,
          drip.length,
          bottomLeft: Radius.circular(half),
          bottomRight: Radius.circular(half),
        ),
        paint,
      )
      ..drawCircle(Offset(drip.x, drip.length), bulb, paint);
    if (drip.drops) {
      final small = drip.width * 0.45;
      canvas
        ..drawCircle(
          Offset(drip.x, drip.length + bulb + small * 2.2),
          small + grow,
          paint,
        )
        ..drawCircle(
          Offset(drip.x, drip.length + bulb + small * 4.6),
          small * 0.7 + grow,
          paint,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xffe03a32), BloodColors.bright, BloodColors.fresh],
      stops: <double>[0, 0.45, 1],
    ).createShader(Rect.fromLTWH(0, 0, size.width, _fontSize));
    TextPainter layoutWith(Paint foreground) => TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(foreground: foreground),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final crust = _fontSize * 0.06;
    final outline = layoutWith(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = crust * 2
        ..strokeJoin = StrokeJoin.round
        ..color = _crust,
    );
    final fill = layoutWith(Paint()..shader = gradient);
    final dripTop =
        fill.computeLineMetrics().first.baseline - _fontSize * _dripInset;
    final crustPaint = Paint()..color = _crust;
    final bloodPaint = Paint()..color = BloodColors.fresh;
    final shinePaint = Paint()..color = BloodColors.shine;

    // Crust around letters and drips together, then the blood on top.
    canvas
      ..save()
      ..translate(0, dripTop);
    for (final drip in drips) {
      _paintDrip(canvas, drip, crustPaint, crust);
    }
    canvas.restore();
    outline.paint(canvas, Offset.zero);
    canvas
      ..save()
      ..translate(0, dripTop);
    for (final drip in drips) {
      _paintDrip(canvas, drip, bloodPaint, 0);
      canvas.drawCircle(
        Offset(drip.x - drip.width * 0.2, drip.length - drip.width * 0.15),
        drip.width * 0.18,
        shinePaint,
      );
    }
    canvas.restore();
    fill.paint(canvas, Offset.zero);
    outline.dispose();
    fill.dispose();
  }

  @override
  bool shouldRepaint(_BloodyTitlePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.drips != drips;
}
