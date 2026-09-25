import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stepbound/ui/blood_decor.dart';

/// What left the splat on the screen: a quick tap, a finger held down, or a
/// swipe that smears it along the way it went.
enum SplatKind { tap, hold, swipe }

/// One square of a splat, in pixel-art cells from where the finger was.
final class SplatPixel {
  const SplatPixel(this.x, this.y, this.color, this.appearAt);

  final int x;
  final int y;
  final Color color;

  /// Seconds after the touch before it shows: the splat spreads out from
  /// the finger and its drips crawl down after it.
  final double appearAt;
}

/// A pixel-art blood splat, never the same twice: the seed shapes it, the
/// kind sizes it and, for a swipe, the direction stretches it. The blobs are
/// metaballs, so close ones run into each other like something thick.
final class BloodSplatShape {
  BloodSplatShape._(this.pixels);

  factory BloodSplatShape.generate({
    required int seed,
    required SplatKind kind,
    Offset direction = Offset.zero,
  }) {
    final rng = math.Random(seed);
    double between(double low, double high) =>
        low + rng.nextDouble() * (high - low);
    final blobs = <_Blob>[];
    final drops = <_Blob>[];
    var drips = 0;
    var dripLength = (3, 6);

    // Rays thrown out from the middle: a chain of shrinking blobs that the
    // field pulls into one tapering spike, and a drop flung off its end.
    void rays(double r, int count, {double? towards, double fan = math.pi}) {
      for (var i = 0; i < count; i++) {
        final angle = towards == null
            ? rng.nextDouble() * math.pi * 2
            : towards + between(-fan, fan);
        final along = Offset(math.cos(angle), math.sin(angle));
        var size = r * between(0.38, 0.5);
        var distance = r * between(0.8, 1);
        while (size > 0.55) {
          final at = along * distance;
          blobs.add(_Blob(at.dx, at.dy, size));
          distance += size * between(1, 1.4);
          size *= between(0.72, 0.84);
        }
        if (rng.nextDouble() < 0.7) {
          final drop = along * (distance + between(1.5, 3));
          drops.add(_Blob(drop.dx, drop.dy, between(0.5, 1)));
        }
      }
    }

    void scatter(double r, int count, double from, double to) {
      for (var i = 0; i < count; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final distance = r * between(from, to);
        drops.add(
          _Blob(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
            between(0.5, 1.2),
          ),
        );
      }
    }

    double gloss;
    switch (kind) {
      case SplatKind.tap:
        final r = between(2.6, 3.6);
        gloss = r;
        blobs.add(_Blob(0, 0, r));
        _around(rng, blobs, r, count: 2 + rng.nextInt(2), spread: (0.6, 1));
        rays(r, 2 + rng.nextInt(3));
        scatter(r, 2 + rng.nextInt(3), 1.8, 2.8);
        drips = rng.nextInt(2);
        dripLength = (2, 5);
      case SplatKind.hold:
        final r = between(4.4, 5.8);
        gloss = r;
        blobs.add(_Blob(0, 0, r));
        _around(rng, blobs, r, count: 4 + rng.nextInt(3), spread: (0.55, 1));
        rays(r, 4 + rng.nextInt(4));
        scatter(r, 5 + rng.nextInt(5), 1.7, 2.8);
        drips = 2 + rng.nextInt(2);
        dripLength = (5, 12);
      case SplatKind.swipe:
        final along = direction.distance == 0
            ? const Offset(1, 0)
            : direction / direction.distance;
        final across = Offset(-along.dy, along.dx);
        var r = between(3.2, 4.2);
        gloss = r;
        var at = Offset.zero;
        blobs.add(_Blob(0, 0, r));
        final steps = 5 + rng.nextInt(4);
        for (var i = 0; i < steps; i++) {
          at += along * r * between(0.6, 0.9) + across * between(-0.5, 0.5);
          r *= between(0.8, 0.92);
          blobs.add(_Blob(at.dx, at.dy, r));
        }
        final heading = math.atan2(along.dy, along.dx);
        rays(gloss, 2 + rng.nextInt(3), towards: heading, fan: 0.5);
        // Flung on ahead of the smear, fanning out a little.
        for (var i = 0; i < 4 + rng.nextInt(4); i++) {
          final spot = at + along * between(2, 6) + across * between(-3, 3);
          drops.add(_Blob(spot.dx, spot.dy, between(0.5, 1.1)));
        }
        drips = 1 + rng.nextInt(2);
        dripLength = (3, 8);
    }

    // Fill every cell where the blobs' fields add up. Each blob only
    // reaches a little past its edge, so near ones join in a thick neck
    // while the whole does not swell into a ball.
    final cells = <(int, int)>{};
    final reach = <(int, int), double>{};
    var farthest = 1.0;
    void fill(int x, int y) {
      cells.add((x, y));
      final distance = math.sqrt(x * x + y * y.toDouble());
      reach[(x, y)] = distance;
      farthest = math.max(farthest, distance);
    }

    for (final blob in blobs) {
      final pad = (blob.r * _falloff).ceil() + 1;
      for (var y = (blob.y - pad).floor(); y <= (blob.y + pad).ceil(); y++) {
        for (var x = (blob.x - pad).floor(); x <= (blob.x + pad).ceil(); x++) {
          if (cells.contains((x, y))) {
            continue;
          }
          var field = 0.0;
          for (final other in blobs) {
            final dx = x - other.x;
            final dy = y - other.y;
            final extent = other.r * _falloff;
            final t = 1 - (dx * dx + dy * dy) / (extent * extent);
            if (t > 0) {
              field += t * t;
            }
          }
          if (field >= _threshold) {
            fill(x, y);
          }
        }
      }
    }
    // Loose drops, round and apart.
    final dropCells = <(int, int)>{};
    for (final drop in drops) {
      final pad = drop.r.ceil();
      for (var y = (drop.y - pad).floor(); y <= (drop.y + pad).ceil(); y++) {
        for (var x = (drop.x - pad).floor(); x <= (drop.x + pad).ceil(); x++) {
          final dx = x - drop.x;
          final dy = y - drop.y;
          if (dx * dx + dy * dy <= drop.r * drop.r + 0.3 &&
              !cells.contains((x, y))) {
            fill(x, y);
            dropCells.add((x, y));
          }
        }
      }
    }

    const spreadTime = 0.14;
    final appear = <(int, int), double>{
      for (final cell in cells)
        cell:
            reach[cell]! / farthest * spreadTime +
            (dropCells.contains(cell) ? 0.05 : 0),
    };

    // Drips hang from the lowest cell of a column and crawl down, slower
    // and slower, ending in a bead.
    final dripCells = <(int, int)>{};
    final columns = <int, int>{};
    for (final (x, y) in cells) {
      columns[x] = math.max(columns[x] ?? y, y);
    }
    final candidates = columns.keys.toList()..sort();
    for (var i = 0; i < drips && candidates.isNotEmpty; i++) {
      final column =
          candidates[candidates.length ~/ 4 +
              rng.nextInt(math.max(1, candidates.length ~/ 2))];
      final top = columns[column]!;
      final length = dripLength.$1 + rng.nextInt(dripLength.$2 - dripLength.$1);
      final width = kind == SplatKind.tap ? 1 : 1 + rng.nextInt(2);
      final crawl = between(0.9, 1.8);
      for (var k = 1; k <= length; k++) {
        final at = spreadTime + crawl * math.pow(k / length, 1.7);
        for (var w = 0; w < width; w++) {
          final cell = (column + w, top + k);
          if (!cells.contains(cell)) {
            dripCells.add(cell);
            appear[cell] = at;
          }
        }
      }
      // The bead at the tip, a cell wider on each side.
      final beadAt = spreadTime + crawl;
      for (var w = -1; w <= width; w++) {
        for (var k = length; k <= length + 1; k++) {
          if ((w == -1 || w == width) && k == length + 1) {
            continue;
          }
          final cell = (column + w, top + k);
          if (!cells.contains(cell) && !dripCells.contains(cell)) {
            dripCells.add(cell);
            appear[cell] = beadAt;
          }
        }
      }
    }

    final filled = <(int, int)>{...cells, ...dripCells};
    // One wet highlight, curved along the top left of the main blob.
    final gx = (-gloss * 0.45).round();
    final gy = (-gloss * 0.5).round();
    final shine = <(int, int)>{
      (gx, gy),
      (gx + 1, gy),
      if (gloss >= 4) ...<(int, int)>{(gx + 2, gy), (gx - 1, gy + 1)},
    };
    bool interior((int, int) cell) {
      final (x, y) = cell;
      return filled.contains((x - 1, y)) &&
          filled.contains((x + 1, y)) &&
          filled.contains((x, y - 1)) &&
          filled.contains((x, y + 1));
    }

    final pixels = <SplatPixel>[];
    for (final cell in filled) {
      final (x, y) = cell;
      final Color color;
      if (shine.contains(cell) && interior(cell)) {
        color = _gloss;
      } else if (!filled.contains((x, y + 1))) {
        color = BloodColors.dried;
      } else if (!filled.contains((x, y - 1))) {
        color = BloodColors.bright;
      } else if (!filled.contains((x + 1, y))) {
        color = _shadow;
      } else {
        color = BloodColors.fresh;
      }
      pixels.add(SplatPixel(x, y, color, appear[cell]!));
    }
    return BloodSplatShape._(pixels);
  }

  final List<SplatPixel> pixels;

  static const Color _gloss = Color(0xffeaa29a);
  static const Color _shadow = Color(0xff6a0e0e);

  /// How far past its radius a blob's field reaches, and how much field
  /// fills a cell: together they put a lone blob's edge at its radius.
  static const double _falloff = 1.8;
  static final double _threshold = math
      .pow(1 - 1 / (_falloff * _falloff), 2)
      .toDouble();

  static void _around(
    math.Random rng,
    List<_Blob> into,
    double r, {
    required int count,
    required (double, double) spread,
    (double, double) size = (0.3, 0.6),
    bool absolute = false,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance =
          r * (spread.$1 + rng.nextDouble() * (spread.$2 - spread.$1));
      final radius =
          (size.$1 + rng.nextDouble() * (size.$2 - size.$1)) *
          (absolute ? 1 : r);
      into.add(
        _Blob(math.cos(angle) * distance, math.sin(angle) * distance, radius),
      );
    }
  }
}

final class _Blob {
  const _Blob(this.x, this.y, this.r);

  final double x;
  final double y;
  final double r;
}

/// A splat left on the screen at [at] (logical pixels) at [born].
final class LiveSplat {
  const LiveSplat(this.shape, this.at, this.born);

  final BloodSplatShape shape;
  final Offset at;
  final Duration born;
}

/// Draws the splats of a [clock] reading: they spread, drip, darken as
/// they dry and fade away after [lifetime].
final class BloodSplatPainter extends CustomPainter {
  BloodSplatPainter({required this.splats, required this.clock})
    : super(repaint: clock);

  final List<LiveSplat> splats;
  final ValueListenable<Duration> clock;

  /// How big one pixel-art cell is on screen, in logical pixels.
  static const double cell = 3;
  static const double fadeFrom = 2;
  static const double lifetime = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.value;
    final paint = Paint()..isAntiAlias = false;
    for (final splat in splats) {
      final age = (now - splat.born).inMicroseconds / 1e6;
      if (age < 0 || age >= lifetime) {
        continue;
      }
      final alpha = age < fadeFrom
          ? 1.0
          : 1 - (age - fadeFrom) / (lifetime - fadeFrom);
      final drying = (age / lifetime).clamp(0.0, 1.0) * 0.45;
      // Snapped to the cell grid, so every splat shares crisp edges.
      final left = (splat.at.dx / cell).floorToDouble() * cell;
      final top = (splat.at.dy / cell).floorToDouble() * cell;
      for (final pixel in splat.shape.pixels) {
        if (pixel.appearAt > age) {
          continue;
        }
        paint.color = Color.lerp(
          pixel.color,
          _driedDark,
          drying,
        )!.withValues(alpha: alpha * pixel.color.a);
        canvas.drawRect(
          Rect.fromLTWH(
            left + pixel.x * cell,
            top + pixel.y * cell,
            cell,
            cell,
          ),
          paint,
        );
      }
    }
  }

  static const Color _driedDark = Color(0xff2a0404);

  @override
  bool shouldRepaint(BloodSplatPainter oldDelegate) =>
      oldDelegate.splats != splats;
}

/// Blood on the glass over everything under it: whoever wants a splat asks
/// the nearest layer with [BloodSplatLayer.maybeOf]. It sits at the root
/// of the app, so a splat outlives the screen that was tapped, a story
/// line that is over or the controls a text box has just hidden.
final class BloodSplatLayer extends StatefulWidget {
  const BloodSplatLayer({required this.child, super.key});

  final Widget child;

  static BloodSplatLayerState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<BloodSplatLayerState>();

  @override
  State<BloodSplatLayer> createState() => BloodSplatLayerState();
}

final class BloodSplatLayerState extends State<BloodSplatLayer>
    with SingleTickerProviderStateMixin {
  /// Splats still on the screen, and the clock they age by: it only ticks
  /// while there is one.
  List<LiveSplat> _splats = const <LiveSplat>[];
  final Stopwatch _time = Stopwatch()..start();
  final ValueNotifier<Duration> _clock = ValueNotifier<Duration>(Duration.zero);
  Ticker? _ticker;

  List<LiveSplat> get splats => _splats;

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// Leaves a splat where a finger touched the screen, at [global].
  void splat(Offset global, SplatKind kind, {Offset direction = Offset.zero}) {
    final box = context.findRenderObject();
    if (!mounted || box is! RenderBox || !box.hasSize) {
      return;
    }
    final at = box.globalToLocal(global);
    final now = _time.elapsed;
    // Where, how and when the finger came down: never the same splat.
    final seed = Object.hash(
      at.dx.round(),
      at.dy.round(),
      kind,
      direction.dx.round(),
      direction.dy.round(),
      now.inMicroseconds,
    );
    final shape = BloodSplatShape.generate(
      seed: seed,
      kind: kind,
      direction: direction,
    );
    setState(() {
      _splats = <LiveSplat>[
        ..._splats.where((splat) => _alive(splat, now)),
        LiveSplat(shape, at, now),
      ];
    });
    _clock.value = now;
    final ticker = _ticker ??= createTicker(_tick);
    if (!ticker.isActive) {
      unawaited(ticker.start());
    }
  }

  static bool _alive(LiveSplat splat, Duration now) =>
      (now - splat.born).inMicroseconds < BloodSplatPainter.lifetime * 1e6;

  void _tick(Duration _) {
    final now = _time.elapsed;
    _clock.value = now;
    if (_splats.every((splat) => !_alive(splat, now))) {
      _ticker?.stop();
      setState(() => _splats = const <LiveSplat>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey<String>('blood-splats'),
            painter: BloodSplatPainter(splats: _splats, clock: _clock),
          ),
        ),
      ],
    );
  }
}
