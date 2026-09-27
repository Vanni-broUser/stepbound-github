import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A rim of fire burning round [child]: flames rise from every edge of it,
/// tallest along the top, flickering for as long as it is on screen. Pixel
/// art in the game's palette of fire. Only something to see: it makes no
/// sound. It is drawn over [child], so whatever is laid over this widget
/// afterwards (a count written on a badge) stays in front of the flames.
final class FireFrame extends StatefulWidget {
  const FireFrame({required this.child, this.cornerRadius = 8, super.key});

  final Widget child;
  final double cornerRadius;

  @override
  State<FireFrame> createState() => _FireFrameState();
}

final class _FireFrameState extends State<FireFrame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
    );
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: FireFramePainter(
        seconds: _seconds,
        cornerRadius: widget.cornerRadius,
      ),
      child: widget.child,
    );
  }
}

/// The flames of a [FireFrame] at [seconds]: a glowing rim, then tongues of
/// fire standing up from points spaced round it.
final class FireFramePainter extends CustomPainter {
  FireFramePainter({required this.seconds, this.cornerRadius = 8})
    : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final double cornerRadius;

  /// Logical pixels per pixel of fire.
  static const double cell = 2;

  /// Pixels of fire between the feet of two flames.
  static const double spacing = 5;

  static const Color white = Color(0xfffff4c8);
  static const Color yellow = Color(0xffffd23f);
  static const Color orange = Color(0xffff8a1c);
  static const Color red = Color(0xffd6341c);
  static const Color ember = Color(0xff7a1a0c);

  @override
  void paint(Canvas canvas, Size size) {
    final t = seconds.value;
    final paint = Paint()..isAntiAlias = false;
    final rect = Offset.zero & size;

    // The rim itself, glowing and pulsing like embers.
    final pulse = 0.5 + 0.5 * math.sin(t * 7);
    final rim = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(cornerRadius),
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Color.lerp(red, orange, pulse)!;
    canvas.drawRRect(rim, paint);
    paint
      ..strokeWidth = 1
      ..color = Color.lerp(orange, yellow, pulse)!;
    canvas.drawRRect(rim.deflate(1), paint);
    paint.style = PaintingStyle.fill;

    // The flames, from points walked round the rim clockwise from the top
    // left corner. Each has its own rhythm, so they never beat together.
    final feet = _feet(size);
    for (var i = 0; i < feet.length; i++) {
      final (foot, edge) = feet[i];
      final seed = i * 12.9898;
      final phase = (math.sin(seed) * 43758.5453) % (math.pi * 2);
      final speed = 9 + (i * 7 % 5);
      final flicker =
          0.55 +
          0.3 * math.sin(t * speed + phase) +
          0.15 * math.sin(t * speed * 2.3 + phase * 1.7);
      final tallest = switch (edge) {
        _Edge.top => 11.0,
        _Edge.left || _Edge.right => 7.0,
        _Edge.bottom => 4.0,
      };
      final height = (tallest * flicker).clamp(2.0, tallest);
      // A flame leans with the draught, one way then the other.
      final sway = math.sin(t * 3 + phase) * 1.5;
      _flame(canvas, paint, foot, height, sway);
    }
  }

  /// A tongue of fire [height] pixels tall standing on [foot]: three wide
  /// at the bottom, narrowing to a point, white-yellow at its heart and red
  /// at its tip.
  void _flame(
    Canvas canvas,
    Paint paint,
    Offset foot,
    double height,
    double sway,
  ) {
    final rows = height.round();
    for (var row = 0; row < rows; row++) {
      final up = row / rows;
      final width = up < 0.35
          ? 3
          : up < 0.7
          ? 2
          : 1;
      paint.color = up < 0.2
          ? yellow
          : up < 0.5
          ? orange
          : up < 0.85
          ? red
          : ember;
      final x = (foot.dx / cell).floor() + (sway * up).round() - width ~/ 2;
      final y = (foot.dy / cell).floor() - row;
      canvas.drawRect(
        Rect.fromLTWH(x * cell, y * cell, width * cell, cell),
        paint,
      );
      if (up < 0.2 && width == 3) {
        paint.color = white;
        canvas.drawRect(
          Rect.fromLTWH((x + 1) * cell, y * cell, cell, cell),
          paint,
        );
      }
    }
  }

  /// Where the flames stand: every [spacing] pixels of fire along each
  /// edge, and which edge that is.
  List<(Offset, _Edge)> _feet(Size size) {
    const step = spacing * cell;
    final feet = <(Offset, _Edge)>[];
    for (var x = step / 2; x < size.width; x += step) {
      feet
        ..add((Offset(x, 1), _Edge.top))
        ..add((Offset(x, size.height), _Edge.bottom));
    }
    for (var y = step; y < size.height - step / 2; y += step) {
      feet
        ..add((Offset(1, y), _Edge.left))
        ..add((Offset(size.width - 1, y), _Edge.right));
    }
    return feet;
  }

  @override
  bool shouldRepaint(FireFramePainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.seconds != seconds;
}

enum _Edge { top, right, bottom, left }
