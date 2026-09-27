import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';

/// A small screen split in two halves, like the real one, where a finger
/// plays [demo] over and over: the same blood stick and splats the game
/// leaves, so what the player sees here is what the thumb will do.
final class ControlDemoView extends StatefulWidget {
  const ControlDemoView({required this.demo, super.key});

  final ControlDemo demo;

  /// The screen drawn in the panel, in logical pixels before it is scaled
  /// down to fit: big enough for the sticks at their real size.
  static const Size screen = Size(360, 203);

  /// Whether the panel of [demo] stands on the right of the view, over the
  /// half its taps are about, rather than on the left.
  static bool standsRight(ControlDemo demo) => demo != ControlDemo.move;

  @override
  State<ControlDemoView> createState() => _ControlDemoViewState();
}

final class _ControlDemoViewState extends State<ControlDemoView>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _clock = ValueNotifier<Duration>(Duration.zero);
  late final Ticker _ticker = createTicker((elapsed) => _clock.value = elapsed);
  final _SplatShapes _shapes = _SplatShapes();

  @override
  void initState() {
    super.initState();
    unawaited(_ticker.start());
  }

  @override
  void didUpdateWidget(ControlDemoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demo != widget.demo) {
      _shapes.clear();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: ValueKey<String>('control-demo-${widget.demo.name}'),
          decoration: BoxDecoration(
            color: const Color(0xe0140c0c),
            border: Border.all(color: BloodColors.fresh, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x88400000), blurRadius: 8),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AspectRatio(
              aspectRatio:
                  ControlDemoView.screen.width / ControlDemoView.screen.height,
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: ControlDemoView.screen,
                  child: CustomPaint(
                    painter: _DemoPainter(
                      script: _Script.of(widget.demo),
                      clock: _clock,
                      shapes: _shapes,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the finger is and what it has brought up, at one moment of a
/// round.
final class _Pose {
  const _Pose({
    this.finger,
    this.fingerAlpha = 1,
    this.pressed = false,
    this.centre,
    this.thumb,
    this.aiming = false,
    this.shot,
  });

  static const _Pose none = _Pose();

  final Offset? finger;
  final double fingerAlpha;
  final bool pressed;

  /// The stick, when it is up.
  final Offset? centre;
  final Offset? thumb;
  final bool aiming;

  /// A bullet on its way: where it left from, which way and how far along
  /// it is, 0 to 1.
  final (Offset, Offset, double)? shot;
}

/// A splat the finger leaves [at] seconds into a round.
final class _Beat {
  const _Beat(this.at, this.kind, this.where, [this.direction = Offset.zero]);

  final double at;
  final SplatKind kind;
  final Offset where;
  final Offset direction;
}

/// One demo: a round [cycle] seconds long, played again and again, each
/// round free to differ from the one before (another direction, another
/// spot).
abstract base class _Script {
  const _Script();

  static _Script of(ControlDemo demo) => switch (demo) {
    ControlDemo.shoot => const _ShootScript(),
    ControlDemo.cancelShot => const _CancelShotScript(),
    ControlDemo.move => const _MoveScript(),
    ControlDemo.interact => const _InteractScript(),
  };

  double get cycle;

  /// Whether the finger works on the right half of the screen.
  bool get rightHalf;

  _Pose poseAt(int round, double t);

  List<_Beat> beatsOf(int round);

  /// Up, right, down, left, then again.
  static const List<Offset> directions = <Offset>[
    Offset(0, -1),
    Offset(1, 0),
    Offset(0, 1),
    Offset(-1, 0),
  ];

  static double ease(double from, double to, double t) =>
      Curves.easeInOut.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  /// The middle of the half the finger works on, nudged a little every
  /// round so the splats do not pile up in one spot.
  Offset home(int round) {
    final half = ControlDemoView.screen.width / 2;
    return Offset(
      (rightHalf ? half : 0) + half / 2 + ((round * 37) % 21 - 10),
      ControlDemoView.screen.height / 2 + ((round * 53) % 15 - 7),
    );
  }
}

/// Press, hold until the pistol comes up with its splash, drag one way,
/// lift: the shot flies off and the smear is left behind.
final class _ShootScript extends _Script {
  const _ShootScript();

  static const double _approach = 0.25;
  static final double _raised =
      _approach + ActionZone.holdToAim.inMicroseconds / 1e6;
  static const double _dragFrom = 0.75;
  static const double _dragTo = 1.25;
  static const double _fire = 1.75;
  static const double _lift = 2.05;

  @override
  double get cycle => 2.9;

  @override
  bool get rightHalf => true;

  Offset _pull(int round) =>
      _Script.directions[round % _Script.directions.length] * ActionZone.reach;

  @override
  _Pose poseAt(int round, double t) {
    final centre = home(round);
    final pull = _pull(round);
    if (t < _approach) {
      return _Pose(finger: centre, fingerAlpha: t / _approach);
    }
    if (t < _raised) {
      return _Pose(finger: centre, pressed: true);
    }
    if (t < _fire) {
      final thumb = centre + pull * _Script.ease(_dragFrom, _dragTo, t);
      return _Pose(
        finger: thumb,
        pressed: true,
        centre: centre,
        thumb: thumb,
        aiming: true,
      );
    }
    if (t < _lift) {
      final gone = (t - _fire) / (_lift - _fire);
      return _Pose(
        finger: centre + pull,
        fingerAlpha: 1 - gone,
        shot: (centre + pull, pull / pull.distance, gone),
      );
    }
    return _Pose.none;
  }

  @override
  List<_Beat> beatsOf(int round) => <_Beat>[
    _Beat(_raised, SplatKind.hold, home(round)),
    _Beat(_fire, SplatKind.swipe, home(round), _pull(round)),
  ];
}

/// Press, hold until the pistol comes up with its splash, and stay in the
/// ring in the middle, lit up with the pistol greyed on the drop, before
/// lifting: the stick goes and only the tap's splat is left.
final class _CancelShotScript extends _Script {
  const _CancelShotScript();

  static const double _lift = 1.95;
  static const double _gone = 2.2;

  @override
  double get cycle => 3;

  @override
  bool get rightHalf => true;

  @override
  _Pose poseAt(int round, double t) {
    final centre = home(round);
    if (t < _ShootScript._approach) {
      return _Pose(finger: centre, fingerAlpha: t / _ShootScript._approach);
    }
    if (t < _ShootScript._raised) {
      return _Pose(finger: centre, pressed: true);
    }
    if (t < _lift) {
      return _Pose(
        finger: centre,
        pressed: true,
        centre: centre,
        thumb: centre,
        aiming: true,
      );
    }
    if (t < _gone) {
      return _Pose(
        finger: centre,
        fingerAlpha: 1 - (t - _lift) / (_gone - _lift),
      );
    }
    return _Pose.none;
  }

  @override
  List<_Beat> beatsOf(int round) => <_Beat>[
    _Beat(_ShootScript._raised, SplatKind.hold, home(round)),
    _Beat(_lift, SplatKind.tap, home(round)),
  ];
}

/// A thumb comes down on the left half, drags the stick one way, holds it
/// there while Mario walks, and lifts: the next round, the next way.
final class _MoveScript extends _Script {
  const _MoveScript();

  static const double _approach = 0.2;
  static const double _dragFrom = 0.35;
  static const double _dragTo = 0.75;
  static const double _lift = 1.75;
  static const double _gone = 2;

  @override
  double get cycle => 2.3;

  @override
  bool get rightHalf => false;

  @override
  _Pose poseAt(int round, double t) {
    final centre = home(round);
    final pull =
        _Script.directions[round % _Script.directions.length] * MoveZone.reach;
    if (t < _approach) {
      return _Pose(finger: centre, fingerAlpha: t / _approach);
    }
    if (t < _lift) {
      final thumb = centre + pull * _Script.ease(_dragFrom, _dragTo, t);
      return _Pose(finger: thumb, pressed: true, centre: centre, thumb: thumb);
    }
    if (t < _gone) {
      return _Pose(
        finger: centre + pull,
        fingerAlpha: 1 - (t - _lift) / (_gone - _lift),
      );
    }
    return _Pose.none;
  }

  /// Walking leaves no blood on the glass.
  @override
  List<_Beat> beatsOf(int round) => const <_Beat>[];
}

/// A tap somewhere on the right half every round, each in another spot,
/// each leaving its splat.
final class _InteractScript extends _Script {
  const _InteractScript();

  static const double _approach = 0.15;
  static const double _lift = 0.3;
  static const double _gone = 0.5;

  /// Where the taps land, as shares of the right half.
  static const List<Offset> _spots = <Offset>[
    Offset(0.35, 0.3),
    Offset(0.7, 0.62),
    Offset(0.28, 0.72),
    Offset(0.62, 0.25),
    Offset(0.5, 0.5),
    Offset(0.78, 0.4),
  ];

  @override
  double get cycle => 0.75;

  @override
  bool get rightHalf => true;

  Offset _spot(int round) {
    final spot = _spots[round % _spots.length];
    final half = ControlDemoView.screen.width / 2;
    return Offset(
      half + spot.dx * half,
      spot.dy * ControlDemoView.screen.height,
    );
  }

  @override
  _Pose poseAt(int round, double t) {
    final at = _spot(round);
    if (t < _approach) {
      return _Pose(finger: at, fingerAlpha: t / _approach);
    }
    if (t < _lift) {
      return _Pose(finger: at, pressed: true);
    }
    if (t < _gone) {
      return _Pose(finger: at, fingerAlpha: 1 - (t - _lift) / (_gone - _lift));
    }
    return _Pose.none;
  }

  @override
  List<_Beat> beatsOf(int round) => <_Beat>[
    _Beat(_lift, SplatKind.tap, _spot(round)),
  ];
}

/// The splats of the rounds still on screen, made once each.
final class _SplatShapes {
  final Map<(int, int), BloodSplatShape> _made =
      <(int, int), BloodSplatShape>{};

  BloodSplatShape of(int round, int index, _Beat beat) =>
      _made[(round, index)] ??= BloodSplatShape.generate(
        seed: Object.hash(round, index, beat.kind),
        kind: beat.kind,
        direction: beat.direction,
      );

  /// Forgets the rounds whose splats have long dried off.
  void forgetBefore(int round) => _made.removeWhere((key, _) => key.$1 < round);

  void clear() => _made.clear();
}

final class _DemoPainter extends CustomPainter {
  _DemoPainter({
    required this.script,
    required this.clock,
    required this.shapes,
  }) : super(repaint: clock);

  final _Script script;
  final ValueListenable<Duration> clock;
  final _SplatShapes shapes;

  static const double _cell = BloodSplatPainter.cell;
  static const Color _bone = Color(0xfff2ebdd);
  static const Color _tracer = Color(0xfff6e7a8);

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value.inMicroseconds / 1e6;
    final cycle = script.cycle;
    final round = (seconds / cycle).floor();
    final t = seconds - round * cycle;

    _paintScreen(canvas, size);

    final pose = script.poseAt(round, t);
    final centre = pose.centre;
    if (centre != null) {
      StickPainter(
        centre: centre,
        thumb: pose.thumb,
        seed: round,
        cancelRadius: pose.aiming ? ActionZone.cancelRadius : null,
      ).paint(canvas, size);
    }

    // Splats last longer than a round: the ones of the rounds before are
    // still drying.
    final back = (BloodSplatPainter.lifetime / cycle).ceil();
    shapes.forgetBefore(round - back);
    final splats = <LiveSplat>[
      for (var r = math.max(0, round - back); r <= round; r++)
        for (final (index, beat) in script.beatsOf(r).indexed)
          if (r * cycle + beat.at <= seconds)
            LiveSplat(
              shapes.of(r, index, beat),
              beat.where,
              Duration(microseconds: ((r * cycle + beat.at) * 1e6).round()),
            ),
    ];
    BloodSplatPainter(splats: splats, clock: clock).paint(canvas, size);

    final shot = pose.shot;
    if (shot != null) {
      _paintShot(canvas, shot);
    }
    final finger = pose.finger;
    if (finger != null) {
      _paintFinger(canvas, finger, pose);
    }
  }

  /// The two halves of the screen, the one the finger works on lit.
  void _paintScreen(Canvas canvas, Size size) {
    final half = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(script.rightHalf ? half : 0, 0, half, size.height),
      Paint()..color = const Color(0x14f2ebdd),
    );
    final dash = Paint()..color = const Color(0x40f2ebdd);
    for (var y = 0.0; y < size.height; y += _cell * 4) {
      canvas.drawRect(
        Rect.fromLTWH(half - _cell / 2, y, _cell, _cell * 2),
        dash,
      );
    }
  }

  /// A fingertip seen through the glass: it fades in coming down, and
  /// presses into a smaller, brighter disc.
  void _paintFinger(Canvas canvas, Offset at, _Pose pose) {
    final radius = pose.pressed ? 5 : 6;
    final alpha = pose.fingerAlpha.clamp(0.0, 1.0);
    final fill = Paint()
      ..isAntiAlias = false
      ..color = _bone.withValues(alpha: (pose.pressed ? 0.3 : 0.18) * alpha);
    final rim = Paint()
      ..isAntiAlias = false
      ..color = _bone.withValues(alpha: (pose.pressed ? 0.85 : 0.5) * alpha);
    final originX = (at.dx / _cell).floorToDouble() * _cell;
    final originY = (at.dy / _cell).floorToDouble() * _cell;
    for (var y = -radius; y <= radius; y++) {
      for (var x = -radius; x <= radius; x++) {
        final d = math.sqrt(x * x + y * y.toDouble());
        if (d > radius + 0.3) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(originX + x * _cell, originY + y * _cell, _cell, _cell),
          d > radius - 0.9 ? rim : fill,
        );
      }
    }
  }

  /// The bullet streaking off the way the stick pointed.
  void _paintShot(Canvas canvas, (Offset, Offset, double) shot) {
    final (from, along, progress) = shot;
    final head = from + along * (12 + progress * 70);
    final paint = Paint()..isAntiAlias = false;
    for (var k = 0; k < 7; k++) {
      final at = head - along * (k * _cell);
      paint.color = _tracer.withValues(
        alpha: (1 - k / 7) * (1 - progress * 0.6),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (at.dx / _cell).floorToDouble() * _cell,
          (at.dy / _cell).floorToDouble() * _cell,
          _cell,
          _cell,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) =>
      oldDelegate.script != script || oldDelegate.shapes != shapes;
}
