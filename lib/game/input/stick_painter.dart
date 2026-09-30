import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/game/input/hud_icons.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';

/// A pool of blood where the finger landed and a drop of it under the
/// finger, smeared between the two, so the player sees which way the drag
/// points. Pixel art, on the same grid as the splats; [seed] picks where
/// the ring drips, so every touch drips differently. Aiming, the blood is
/// brighter and a pale ring of [cancelRadius] marks the middle: it lights
/// up, with the pistol greyed on the drop, while the finger rests inside
/// it, where lifting it fires nothing.
final class StickPainter extends CustomPainter {
  const StickPainter({
    required this.centre,
    required this.thumb,
    required this.seed,
    this.cancelRadius,
  });

  final Offset? centre;
  final Offset? thumb;
  final int seed;

  /// How far the drop goes from the pool: the reach of both sticks, the
  /// one that walks and the one that aims.
  static const double reach = 44;
  final double? cancelRadius;

  bool get aiming => cancelRadius != null;

  static const double _cell = BloodSplatPainter.cell;
  static const Color _pool = Color(0x662a0606);
  static const Color _gloss = Color(0xffeaa29a);
  static const Color _litAiming = Color(0xffe05050);
  static const Color _ring = Color(0x99d8cfbf);
  static const Color _ringLit = Color(0xfff2ebdd);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = this.centre;
    final thumb = this.thumb;
    if (centre == null || thumb == null) {
      return;
    }
    var delta = thumb - centre;
    if (delta.distance > reach) {
      delta = delta / delta.distance * reach;
    }
    final paint = Paint()..isAntiAlias = false;
    // Everything on the cell grid, from the cell the centre falls in.
    final originX = (centre.dx / _cell).floorToDouble() * _cell;
    final originY = (centre.dy / _cell).floorToDouble() * _cell;
    void cell(int x, int y, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(originX + x * _cell, originY + y * _cell, _cell, _cell),
        paint,
      );
    }

    final body = aiming ? BloodColors.bright : BloodColors.fresh;
    final rim = aiming ? BloodColors.fresh : BloodColors.dried;
    final lit = aiming ? _litAiming : BloodColors.bright;
    const radius = reach / _cell;
    final r = radius.ceil() + 2;

    // The pool: a dark stain, its rim wet and lit from the top left. The
    // edge wobbles, differently on every touch, like a real puddle.
    final rng = math.Random(seed);
    final phase1 = rng.nextDouble() * math.pi * 2;
    final phase2 = rng.nextDouble() * math.pi * 2;
    double edge(double angle) =>
        radius +
        math.sin(angle * 3 + phase1) * 0.7 +
        math.sin(angle * 5 + phase2) * 0.4;
    for (var y = -r; y <= r; y++) {
      for (var x = -r; x <= r; x++) {
        final d = math.sqrt(x * x + y * y.toDouble());
        final out = edge(math.atan2(y.toDouble(), x.toDouble()));
        if (d > out + 0.5) {
          continue;
        }
        if (d < out - 1.4) {
          cell(x, y, _pool);
        } else if (y < 0 && x < 0 && d > out - 0.7) {
          cell(x, y, body);
        } else {
          cell(x, y, rim);
        }
      }
    }

    // Drips running off the bottom of the rim, each ending in a bead.
    for (var i = 0; i < 2 + rng.nextInt(3); i++) {
      final angle = math.pi * (0.2 + rng.nextDouble() * 0.6);
      final x = (math.cos(angle) * edge(angle)).round();
      final top = (math.sin(angle) * edge(angle)).round();
      final length = 2 + rng.nextInt(5);
      for (var k = 0; k < length; k++) {
        cell(x, top + k, rim);
      }
      for (var bx = -1; bx <= 1; bx++) {
        cell(x + bx, top + length, rim);
        cell(x + bx, top + length + 1, rim);
      }
      cell(x - 1, top + length, lit);
    }

    // The ring in the middle, where lifting the finger fires nothing.
    final cancelRadius = this.cancelRadius;
    final cancelling = cancelRadius != null && delta.distance <= cancelRadius;
    if (cancelRadius != null) {
      final ring = cancelRadius / _cell;
      final reachOut = ring.ceil() + 1;
      for (var y = -reachOut; y <= reachOut; y++) {
        for (var x = -reachOut; x <= reachOut; x++) {
          final d = math.sqrt(x * x + y * y.toDouble());
          if ((d - ring).abs() <= 0.55) {
            cell(x, y, cancelling ? _ringLit : _ring);
          }
        }
      }
    }

    // The smear the drop leaves on its way out from the middle.
    final kx = (delta.dx / _cell).round();
    final ky = (delta.dy / _cell).round();
    final steps = math.max(kx.abs(), ky.abs());
    for (var i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      cell((kx * t).round(), (ky * t).round(), rim);
    }

    // The drop under the finger: round, dark underneath, glossy on top.
    const drop = 4;
    for (var y = -drop; y <= drop; y++) {
      for (var x = -drop; x <= drop; x++) {
        final d = math.sqrt(x * x + y * y.toDouble());
        if (d > drop + 0.3) {
          continue;
        }
        final Color color;
        if (d > drop - 0.9 && y > 0) {
          color = rim;
        } else if (d > drop - 0.9 && y < 0) {
          color = lit;
        } else {
          color = body;
        }
        cell(kx + x, ky + y, color);
      }
    }
    cell(kx - 2, ky - 2, _gloss);
    cell(kx - 1, ky - 2, _gloss);
    cell(kx - 2, ky - 1, _gloss);

    // Only in the middle ring, greyed: the pistol is about to be lowered.
    // Once a direction is chosen the drop is left bare.
    if (cancelling) {
      const icon = Size(20, 20);
      canvas
        ..save()
        ..translate(
          originX + (kx + 0.5) * _cell - icon.width / 2,
          originY + (ky + 0.5) * _cell - icon.height / 2,
        );
      const PistolIcon(color: Color(0x88f2ebdd)).paint(canvas, icon);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StickPainter oldDelegate) =>
      oldDelegate.centre != centre ||
      oldDelegate.thumb != thumb ||
      oldDelegate.seed != seed ||
      oldDelegate.cancelRadius != cancelRadius;
}
