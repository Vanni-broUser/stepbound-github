import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// Animated pixel-art fire: flickering tongues of flame, a pulsing glow,
/// rising embers and a column of smoke drifting with the wind. The
/// component's position is the centre of the flame's base.
final class FireComponent extends PositionComponent {
  FireComponent({
    required Vector2 base,
    required this.halfWidth,
    required this.flameHeight,
    this.seed = 0,
    this.smoke = true,
  }) : super(position: base, priority: 25);

  /// The fire of a level's [spot], sized and placed for what burns there.
  factory FireComponent.at(FireSpot spot, {int seed = 0, double tile = 16}) {
    final left = spot.tile.x * tile;
    final top = spot.tile.y * tile;
    return switch (spot.kind) {
      // A car parked north-south burns on its roof, mid-way down.
      FireKind.car when spot.vertical => FireComponent(
        base: Vector2(left + tile / 2, top + 12),
        halfWidth: 4,
        flameHeight: 13,
        seed: seed,
      ),
      // Burning car: wide fire centred on the two-tile wreck's roof.
      FireKind.car => FireComponent(
        base: Vector2(left + tile, top + 4),
        halfWidth: 6,
        flameHeight: 14,
        seed: seed,
      ),
      FireKind.bin => FireComponent(
        base: Vector2(left + tile / 2, top + 6),
        halfWidth: 3,
        flameHeight: 9,
        seed: seed,
      ),
      FireKind.window => FireComponent(
        base: Vector2(left + tile / 2, top + 13),
        halfWidth: 4,
        flameHeight: 12,
        seed: seed,
      ),
      FireKind.campfire => FireComponent(
        base: Vector2(left + tile / 2, top + 11),
        halfWidth: 3,
        flameHeight: 9,
        seed: seed,
      ),
    };
  }

  final int halfWidth;
  final double flameHeight;
  final int seed;
  final bool smoke;

  static const Color _ember = Color(0xffffd65a);
  static const List<Color> _layers = <Color>[
    Color(0xff78180f),
    Color(0xffc83c14),
    Color(0xfff0821e),
    Color(0xffffd65a),
    Color(0xfffff2c0),
  ];

  final Paint _paint = Paint()..isAntiAlias = false;
  double _time = 0;

  static const double flareDuration = 1.4;
  double _flareLeft = 0;

  /// Makes the fire roar up for a moment, throwing sparks.
  void flare() {
    _flareLeft = flareDuration;
  }

  /// 1 at rest, up to 2 at the peak of a flare.
  double get _boost {
    if (_flareLeft <= 0) {
      return 1;
    }
    final t = 1 - _flareLeft / flareDuration;
    return 1 + math.sin(t * math.pi);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_flareLeft > 0) {
      _flareLeft -= dt;
    }
  }

  /// Smooth pseudo-noise in 0..1 for a flame column at time [t].
  double _flicker(int column, double t) {
    final phase = seed * 1.37 + column * 1.9;
    final a = math.sin(t * 9.1 + phase);
    final b = math.sin(t * 5.3 + phase * 0.7);
    final c = math.sin(t * 13.7 + phase * 1.3);
    return (0.5 + 0.25 * a + 0.15 * b + 0.1 * c).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final t = _time;
    _renderGlow(canvas, t);
    if (smoke) {
      _renderSmoke(canvas, t);
    }
    _renderFlames(canvas, t);
    _renderEmbers(canvas, t);
  }

  void _renderGlow(Canvas canvas, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 6.3 + seed);
    final radius = halfWidth * 3.0 + pulse * 2;
    _paint.color = Color.fromRGBO(255, 110, 30, 0.07 + 0.05 * pulse);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -flameHeight * 0.4),
        width: radius * 2,
        height: radius * 1.4,
      ),
      _paint,
    );
    _paint.color = Color.fromRGBO(255, 150, 50, 0.08 + 0.06 * pulse);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -flameHeight * 0.3),
        width: radius,
        height: radius * 0.8,
      ),
      _paint,
    );
  }

  void _renderFlames(Canvas canvas, double t) {
    for (var column = -halfWidth; column <= halfWidth; column++) {
      final edge = column.abs() / (halfWidth + 1);
      final shape = 1 - edge * edge * 0.85;
      final height =
          flameHeight * _boost * shape * (0.45 + 0.55 * _flicker(column, t));
      for (var layer = 0; layer < _layers.length; layer++) {
        // Inner layers are shorter and only burn near the centre.
        final layerShare = 1 - layer * 0.2;
        if (edge > layerShare + 0.05) {
          continue;
        }
        final layerHeight = (height * layerShare).roundToDouble();
        if (layerHeight < 1) {
          continue;
        }
        _paint.color = _layers[layer];
        canvas.drawRect(
          Rect.fromLTWH(column.toDouble(), -layerHeight, 1, layerHeight),
          _paint,
        );
      }
      // Detached licks of flame that flicker above the body.
      final lick = _flicker(column + 31, t * 1.4);
      if (lick > 0.78 && edge < 0.7) {
        _paint.color = _layers[2];
        final y = -(height + 2 + (lick - 0.78) * 20).roundToDouble();
        canvas.drawRect(Rect.fromLTWH(column.toDouble(), y, 1, 2), _paint);
      }
    }
  }

  void _renderEmbers(Canvas canvas, double t) {
    final count = _flareLeft > 0 ? 14 : 4;
    for (var i = 0; i < count; i++) {
      final progress = (t * 0.8 + i / count + seed * 0.13) % 1;
      final x = math.sin(progress * 7 + i * 2.1 + seed) * halfWidth;
      final y = -flameHeight - progress * flameHeight * 2.2;
      _paint.color = _ember.withValues(alpha: 1 - progress);
      canvas.drawRect(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), 1, 1),
        _paint,
      );
    }
  }

  void _renderSmoke(Canvas canvas, double t) {
    const puffs = 7;
    for (var i = 0; i < puffs; i++) {
      final progress = (t * 0.22 + i / puffs + seed * 0.07) % 1;
      final rise = flameHeight * 0.8 + progress * (38 + halfWidth * 4);
      final drift = progress * 10 + math.sin(progress * 5 + i + seed) * 3;
      final size = (2 + halfWidth * 0.5 + progress * 5).roundToDouble();
      final shade = 70 + (i % 3) * 12;
      _paint.color = Color.fromRGBO(
        shade,
        shade - 4,
        shade,
        (1 - progress) * 0.7,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(drift.roundToDouble(), -rise.roundToDouble()),
          width: size * 2,
          height: size * 1.4,
        ),
        _paint,
      );
    }
  }
}
