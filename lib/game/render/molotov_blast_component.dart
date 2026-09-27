import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/throw_preview_component.dart';

/// A molotov on its way and what it does on landing: the bottle turns
/// over and over along the same arc the aim showed, its rag alight, then
/// bursts in a flash over the 3x3 square, flames licking every tile of it,
/// sparks flying and smoke rising after. Drawn over the dark, since it
/// lights itself; removes itself once the smoke has gone.
final class MolotovBlastComponent extends Component {
  MolotovBlastComponent({
    required this.origin,
    required this.target,
    this.tileSize = 16,
    this.onLanded,
  }) : _random = math.Random(Object.hash(target.x, target.y, origin.x)),
       super(priority: 29);

  final GridPoint origin;
  final GridPoint target;
  final double tileSize;

  /// Called once, as the bottle breaks.
  final void Function()? onLanded;

  /// Seconds from the throw to the bottle breaking.
  static const double flightSeconds = 0.45;

  /// Seconds from the bottle breaking to the last of the smoke.
  static const double burstSeconds = 1.4;

  final math.Random _random;
  final Paint _paint = Paint()..isAntiAlias = false;
  late final List<_Flame> _flames = _makeFlames();
  late final List<_Spark> _sparks = _makeSparks();
  late final List<_Puff> _puffs = _makePuffs();

  double _elapsed = 0;
  bool _landed = false;

  Offset get _from => ThrowPreviewComponent.handOf(origin, tileSize);

  Offset get _to => Offset(
    target.x * tileSize + tileSize / 2,
    target.y * tileSize + tileSize / 2,
  );

  static const Color _white = Color(0xfffff8e0);
  static const Color _yellow = Color(0xffffd23f);
  static const Color _orange = Color(0xffff8a1c);
  static const Color _red = Color(0xffd6341c);
  static const Color _ember = Color(0xff7a1a0c);
  static const Color _glass = Color(0xff4f8a3c);
  static const Color _glassLit = Color(0xff9fd07a);
  static const Color _rag = Color(0xffd9c9a3);

  @override
  void update(double dt) {
    _elapsed += dt;
    if (!_landed && _elapsed >= flightSeconds) {
      _landed = true;
      onLanded?.call();
    }
    if (_elapsed >= flightSeconds + burstSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_elapsed < flightSeconds) {
      _renderBottle(canvas, _elapsed / flightSeconds);
      return;
    }
    final t = (_elapsed - flightSeconds) / burstSeconds;
    _renderGlow(canvas, t);
    _renderPuffs(canvas, t);
    _renderFlames(canvas, t);
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

  void _renderBottle(Canvas canvas, double t) {
    final rise = ThrowPreviewComponent.riseOf(_from, _to, tileSize);
    final at = ThrowPreviewComponent.arcPoint(_from, _to, rise, t);
    // Its shadow on the ground, straight under it, growing as it falls.
    final ground = Offset.lerp(_from + Offset(0, tileSize - 3), _to, t)!;
    _paint.color = const Color(0x55000000);
    canvas
      ..drawOval(
        Rect.fromCenter(center: ground, width: 3 + 3 * t, height: 2),
        _paint,
      )
      ..save()
      ..translate(at.dx.roundToDouble(), at.dy.roundToDouble())
      ..rotate(t * math.pi * 3);
    // The bottle: glass body, neck, rag, and the rag burning.
    _rect(canvas, -1.5, -1, 3, 5, _glass);
    _rect(canvas, -1.5, -1, 1, 5, _glassLit);
    _rect(canvas, -0.5, -3, 1, 2, _glass);
    _rect(canvas, -1, -4, 2, 1, _rag);
    final flicker = (_elapsed * 30).floor().isEven;
    _rect(canvas, -1, flicker ? -6 : -7, 2, flicker ? 2 : 3, _orange);
    _rect(canvas, -0.5, -6, 1, 1, _yellow);
    canvas.restore();
  }

  // -------------------------------------------------------------- burst

  /// A warm light over the square, strongest as the bottle breaks.
  void _renderGlow(Canvas canvas, double t) {
    final strength = t < 0.08 ? 1.0 : math.max(0, 1 - (t - 0.08) / 0.8);
    if (strength <= 0) {
      return;
    }
    final paint = Paint()
      ..shader = Gradient.radial(
        _to,
        tileSize * 2.6,
        <Color>[
          _orange.withValues(alpha: 0.55 * strength),
          _red.withValues(alpha: 0.25 * strength),
          const Color(0x00000000),
        ],
        const <double>[0, 0.55, 1],
      );
    canvas.drawCircle(_to, tileSize * 2.6, paint);
  }

  /// The first instant: a white ball that swells past the square and is
  /// gone.
  void _renderFlash(Canvas canvas, double t) {
    const span = 0.2;
    if (t > span) {
      return;
    }
    final k = t / span;
    final radius = 6 + k * tileSize * 1.9;
    // Drawn in pixel rings, from the outside in.
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

  List<_Flame> _makeFlames() {
    final flames = <_Flame>[];
    const radius = ThrowMolotovAction.blastRadius;
    for (var ty = -radius; ty <= radius; ty++) {
      for (var tx = -radius; tx <= radius; tx++) {
        final count = tx == 0 && ty == 0 ? 5 : 3;
        for (var i = 0; i < count; i++) {
          flames.add(
            _Flame(
              x: (target.x + tx) * tileSize + 2 + _random.nextDouble() * 12,
              y: (target.y + ty) * tileSize + 10 + _random.nextDouble() * 5,
              height: 6 + _random.nextDouble() * (tx == 0 && ty == 0 ? 10 : 7),
              phase: _random.nextDouble() * math.pi * 2,
              speed: 14 + _random.nextDouble() * 10,
              // The outer tiles catch a moment after the middle one.
              delay: (tx.abs() + ty.abs()) * 0.03,
            ),
          );
        }
      }
    }
    // Back to front, so nearer flames cover the ones behind.
    return flames..sort((a, b) => a.y.compareTo(b.y));
  }

  void _renderFlames(Canvas canvas, double t) {
    for (final flame in _flames) {
      final local = t - flame.delay;
      if (local <= 0) {
        continue;
      }
      // Up fast, burning, then sinking to embers.
      final grow = math.min(1, local / 0.08);
      final fade = local < 0.55 ? 1.0 : math.max(0, 1 - (local - 0.55) / 0.35);
      if (fade <= 0) {
        continue;
      }
      final wobble = math.sin(_elapsed * flame.speed + flame.phase);
      final height = flame.height * grow * fade * (0.8 + 0.2 * wobble);
      final sway = (wobble * 1.5).roundToDouble();
      // Three tongues inside each other: red, orange, yellow core.
      _tongue(canvas, flame.x + sway * 0.5, flame.y, 5, height, _red);
      _tongue(canvas, flame.x + sway * 0.7, flame.y, 3, height * 0.75, _orange);
      _tongue(canvas, flame.x + sway, flame.y, 1, height * 0.45, _yellow);
      if (fade < 1) {
        _rect(canvas, flame.x - 1, flame.y - 1, 3, 1, _ember);
      }
    }
  }

  /// A flame drawn in pixel rows, [width] at its foot narrowing to a
  /// point [height] above.
  void _tongue(
    Canvas canvas,
    double x,
    double foot,
    double width,
    double height,
    Color color,
  ) {
    if (height < 1) {
      return;
    }
    for (var row = 0; row < height; row++) {
      final left = 1 - row / height;
      final w = math.max(1, (width * left).roundToDouble());
      _rect(canvas, x - w / 2, foot - row - 1, w.toDouble(), 1, color);
    }
  }

  List<_Spark> _makeSparks() => <_Spark>[
    for (var i = 0; i < 26; i++)
      _Spark(
        angle: _random.nextDouble() * math.pi * 2,
        speed: 30 + _random.nextDouble() * 70,
        lift: 30 + _random.nextDouble() * 50,
        life: 0.35 + _random.nextDouble() * 0.35,
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
    for (var i = 0; i < 9; i++)
      _Puff(
        dx: (_random.nextDouble() - 0.5) * tileSize * 2.6,
        dy: (_random.nextDouble() - 0.5) * tileSize * 1.6,
        start: 0.2 + _random.nextDouble() * 0.3,
        size: 3 + _random.nextDouble() * 4,
        shade: 40 + _random.nextInt(40),
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
      final y = _to.dy + puff.dy - local * tileSize * 1.8;
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

final class _Flame {
  const _Flame({
    required this.x,
    required this.y,
    required this.height,
    required this.phase,
    required this.speed,
    required this.delay,
  });

  final double x;
  final double y;
  final double height;
  final double phase;
  final double speed;
  final double delay;
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
