import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';

/// A rocket on its way from the launcher and what it does where it
/// lands: it flies straight along the line the aim showed, its motor
/// burning behind it and a trail of smoke left hanging in the air, and
/// bursts where the line ends, against the wall, in a flash, sparks and
/// smoke. Drawn over the dark, since it lights itself; removes itself
/// once the smoke has gone.
final class RocketComponent extends Component {
  RocketComponent({
    required this.origin,
    required this.impact,
    required this.direction,
    this.tileSize = 16,
    this.onImpact,
  }) : _random = math.Random(Object.hash(impact.x, impact.y, origin.x)),
       super(priority: 29);

  /// The tile Mario fires from.
  final GridPoint origin;

  /// The tile the rocket bursts on: the wall it hits, or the last tile of
  /// the map along its way.
  final GridPoint impact;
  final Direction direction;
  final double tileSize;

  /// Called once, as the rocket bursts.
  final void Function()? onImpact;

  /// Pixels a second: a tile in a thirty-fifth of a second, so it is
  /// hardly ahead of the hits it deals, which are dealt as it is fired.
  static const double speed = 560;

  /// Seconds from the burst to the last of the smoke.
  static const double burstSeconds = 0.9;

  /// Pixels between two puffs of the trail.
  static const double puffSpacing = 6;

  final math.Random _random;
  final Paint _paint = Paint()..isAntiAlias = false;
  late final List<_Spark> _sparks = _makeSparks();
  late final List<_Puff> _puffs = _makePuffs();

  double _elapsed = 0;
  bool _landed = false;

  /// Where the rocket leaves the launcher: over Mario's shoulder.
  Offset get _from => Offset(
    origin.x * tileSize + tileSize / 2,
    origin.y * tileSize + tileSize / 2 - 2,
  );

  Offset get _to => Offset(
    impact.x * tileSize + tileSize / 2,
    impact.y * tileSize + tileSize / 2 - 2,
  );

  /// Seconds the flight takes, at [speed]; never so short that nothing of
  /// it is seen.
  late final double flightSeconds = flightSecondsFor(
    origin,
    impact,
    tileSize: tileSize,
  );

  /// Seconds a rocket takes from [from] to [to], straight along a row or
  /// a column: when it passes each one in its way, and when it bursts.
  static double flightSecondsFor(
    GridPoint from,
    GridPoint to, {
    double tileSize = 16,
  }) => math.max(0.08, from.manhattanDistanceTo(to) * tileSize / speed);

  static const Color _white = Color(0xfffff8e0);
  static const Color _yellow = Color(0xffffd23f);
  static const Color _orange = Color(0xffff8a1c);
  static const Color _red = Color(0xffd6341c);
  static const Color _olive = Color(0xff506432);
  static const Color _oliveLight = Color(0xff7c9252);
  static const Color _warhead = Color(0xffc43428);

  @override
  void update(double dt) {
    _elapsed += dt;
    if (!_landed && _elapsed >= flightSeconds) {
      _landed = true;
      onImpact?.call();
    }
    if (_elapsed >= flightSeconds + burstSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_elapsed < flightSeconds) {
      final t = _elapsed / flightSeconds;
      _renderTrail(canvas, t);
      _renderRocket(canvas, t);
      return;
    }
    final t = (_elapsed - flightSeconds) / burstSeconds;
    _renderTrail(canvas, 1, fading: t);
    _renderGlow(canvas, t);
    _renderPuffs(canvas, t);
    _renderFlash(canvas, t);
    _renderSparks(canvas, t);
  }

  void _rect(Canvas canvas, double x, double y, double w, double h, Color c) {
    _paint.color = c;
    canvas.drawRect(
      Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), w, h),
      _paint,
    );
  }

  // ------------------------------------------------------------- flight

  /// Where the rocket is at [t], from the launcher to the burst.
  Offset _at(double t) => Offset.lerp(_from, _to, t)!;

  /// The smoke left behind: a puff every [puffSpacing] pixels of the way
  /// flown so far, growing and thinning the longer it has hung there.
  void _renderTrail(Canvas canvas, double t, {double fading = 0}) {
    final length = (_to - _from).distance;
    final flown = length * t;
    for (var d = 4.0; d < flown; d += puffSpacing) {
      final age = (flown - d) / speed + fading * burstSeconds;
      final alpha = math.max(0, 0.5 - age * 0.7);
      if (alpha <= 0) {
        continue;
      }
      final size = (2 + age * 8).clamp(2, 6).roundToDouble();
      final at = _at(d / length);
      final grey = 90 + (d * 7).floor() % 40;
      _rect(
        canvas,
        at.dx - size / 2,
        at.dy - size / 2,
        size,
        size,
        Color.fromARGB((alpha * 255).round(), grey, grey, grey),
      );
    }
  }

  /// The rocket itself, its warhead first, the flame of its motor behind.
  void _renderRocket(Canvas canvas, double t) {
    final at = _at(t);
    final flicker = (_elapsed * 40).floor().isEven;
    switch (direction) {
      case Direction.east || Direction.west:
        final sign = direction == Direction.east ? 1 : -1;
        final head = at.dx + sign * 3;
        final tail = at.dx - sign * 3;
        _rect(canvas, math.min(head, tail) - 1, at.dy - 1, 8, 3, _olive);
        _rect(canvas, math.min(head, tail) - 1, at.dy - 1, 8, 1, _oliveLight);
        _rect(canvas, head, at.dy - 1, 1, 3, _warhead);
        _rect(
          canvas,
          tail - sign * (flicker ? 3 : 2),
          at.dy - 1,
          3,
          3,
          _orange,
        );
        _rect(canvas, tail - sign * 1, at.dy, 1, 1, _yellow);
      case Direction.north || Direction.south:
        final sign = direction == Direction.south ? 1 : -1;
        final head = at.dy + sign * 3;
        final tail = at.dy - sign * 3;
        _rect(canvas, at.dx - 1, math.min(head, tail) - 1, 3, 8, _olive);
        _rect(canvas, at.dx - 1, math.min(head, tail) - 1, 1, 8, _oliveLight);
        _rect(canvas, at.dx - 1, head, 3, 1, _warhead);
        _rect(
          canvas,
          at.dx - 1,
          tail - sign * (flicker ? 3 : 2),
          3,
          3,
          _orange,
        );
        _rect(canvas, at.dx, tail - sign * 1, 1, 1, _yellow);
    }
  }

  // -------------------------------------------------------------- burst

  /// A warm light where it burst, strongest at the first instant.
  void _renderGlow(Canvas canvas, double t) {
    final strength = t < 0.1 ? 1.0 : math.max(0, 1 - (t - 0.1) / 0.6);
    if (strength <= 0) {
      return;
    }
    final paint = Paint()
      ..shader = Gradient.radial(
        _to,
        tileSize * 2.2,
        <Color>[
          _orange.withValues(alpha: 0.6 * strength),
          _red.withValues(alpha: 0.25 * strength),
          const Color(0x00000000),
        ],
        const <double>[0, 0.55, 1],
      );
    canvas.drawCircle(_to, tileSize * 2.2, paint);
  }

  /// The first instant: a white ball swelling to a tile and a half across
  /// and gone.
  void _renderFlash(Canvas canvas, double t) {
    const span = 0.22;
    if (t > span) {
      return;
    }
    final k = t / span;
    final radius = 4 + k * (tileSize * 0.75 - 4);
    for (final (scale, color) in <(double, Color)>[
      (1, _red),
      (0.8, _orange),
      (0.6, _yellow),
      (0.35, _white),
    ]) {
      final r = radius * scale;
      _paint.color = color.withValues(alpha: 1 - k * 0.6);
      final step = math.max(1, (r / 6).floorToDouble());
      for (var y = -r; y <= r; y += step) {
        final half = math.sqrt(math.max(0, r * r - y * y));
        canvas.drawRect(
          Rect.fromLTWH(
            (_to.dx - half).floorToDouble(),
            (_to.dy + y).floorToDouble(),
            (half * 2).ceilToDouble(),
            step.toDouble(),
          ),
          _paint,
        );
      }
    }
  }

  List<_Spark> _makeSparks() => <_Spark>[
    for (var i = 0; i < 18; i++)
      _Spark(
        angle: _random.nextDouble() * math.pi * 2,
        speed: 40 + _random.nextDouble() * 60,
        lift: 30 + _random.nextDouble() * 40,
        life: 0.25 + _random.nextDouble() * 0.3,
      ),
  ];

  void _renderSparks(Canvas canvas, double t) {
    final seconds = t * burstSeconds;
    for (final spark in _sparks) {
      if (seconds > spark.life) {
        continue;
      }
      final k = seconds / spark.life;
      final x = _to.dx + math.cos(spark.angle) * spark.speed * seconds;
      final y =
          _to.dy +
          math.sin(spark.angle) * spark.speed * seconds * 0.6 -
          spark.lift * seconds +
          90 * seconds * seconds;
      _rect(canvas, x, y, 1, 1, k < 0.5 ? _yellow : _orange);
    }
  }

  List<_Puff> _makePuffs() => <_Puff>[
    for (var i = 0; i < 7; i++)
      _Puff(
        dx: (_random.nextDouble() - 0.5) * tileSize * 1.8,
        dy: (_random.nextDouble() - 0.5) * tileSize * 1.2,
        start: 0.15 + _random.nextDouble() * 0.3,
        size: 3 + _random.nextDouble() * 3,
        shade: 50 + _random.nextInt(40),
      ),
  ];

  void _renderPuffs(Canvas canvas, double t) {
    for (final puff in _puffs) {
      final local = (t - puff.start) / (1 - puff.start);
      if (local <= 0 || local >= 1) {
        continue;
      }
      final size = (puff.size * (1 + local * 1.5)).roundToDouble();
      final x = _to.dx + puff.dx;
      final y = _to.dy + puff.dy - local * tileSize * 1.4;
      final alpha = 0.55 * (1 - local);
      final grey = Color.fromARGB(
        (alpha * 255).round(),
        puff.shade,
        puff.shade,
        puff.shade,
      );
      // A blocky puff: a cross of two rectangles.
      _rect(canvas, x - size, y - size / 2, size * 2, size, grey);
      _rect(canvas, x - size / 2, y - size, size, size * 2, grey);
    }
  }
}

final class _Spark {
  const _Spark({
    required this.angle,
    required this.speed,
    required this.lift,
    required this.life,
  });

  final double angle;
  final double speed;
  final double lift;
  final double life;
}

final class _Puff {
  const _Puff({
    required this.dx,
    required this.dy,
    required this.start,
    required this.size,
    required this.shade,
  });

  final double dx;
  final double dy;
  final double start;
  final double size;
  final int shade;
}
