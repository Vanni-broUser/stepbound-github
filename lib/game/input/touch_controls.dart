import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';

final class TouchControls extends StatelessWidget {
  const TouchControls({required this.game, super.key});

  final StepboundGame game;

  static const double actionButtonSize = 54;

  /// The way out, in the far corner from the thumbs: smaller than the
  /// action buttons, so it is never the one hit by mistake.
  static const double menuButtonSize = 38;

  /// The badge of the thing Mario carries for [element], or null for the
  /// elements that are buttons and not things: interacting and shooting.
  static Widget? _carriedBadge(
    HudElement element, {
    required StepboundGame game,
  }) => switch (element) {
    HudElement.ammo => _AmmoBadge(game: game),
    HudElement.incense => _IncenseBadge(game: game),
    HudElement.barKey => _BarKeyBadge(game: game),
    HudElement.episcopalRing => _EpiscopalRingBadge(game: game),
    HudElement.duomoKey => _DuomoKeyBadge(game: game),
    HudElement.interact || HudElement.shoot => null,
  };

  @override
  Widget build(BuildContext context) {
    // No buttons to play: the left half of the screen walks, the right
    // half interacts and shoots, two fingers zoom. What is drawn on top
    // only shows state, plus the menu and the items carried, which take
    // their own taps.
    return ValueListenableBuilder<Set<HudElement>>(
      valueListenable: game.hud,
      builder: (context, unlocked, _) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: PinchZone(
                game: game,
                child: Row(
                  children: <Widget>[
                    Expanded(child: MoveZone(game: game)),
                    Expanded(child: ActionZone(game: game)),
                  ],
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(10),
              child: Stack(
                children: <Widget>[
                  // Always there, unlocked or not: it is the way out, not
                  // something the tutorial hands over.
                  Positioned(right: 0, top: 0, child: _PauseButton(game: game)),
                  // What Mario carries, in the order he picked it up: the
                  // bullets counted, then whatever the story has him hold
                  // for someone. One row in the far top corner from the
                  // menu, out of both thumbs' way.
                  if (unlocked.contains(HudElement.ammo) ||
                      unlocked.contains(HudElement.incense) ||
                      unlocked.contains(HudElement.barKey) ||
                      unlocked.contains(HudElement.episcopalRing) ||
                      unlocked.contains(HudElement.duomoKey))
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final element in unlocked)
                            ?_carriedBadge(element, game: game),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Opens the menu over the game. The gameplay buttons go with it: the
/// menu replaces whatever covers the game, and these are what is drawn
/// when nothing does.
final class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      key: const ValueKey<String>('touch-menu'),
      semanticLabel: 'Menù',
      size: TouchControls.menuButtonSize,
      drips: const <BloodDrip>[BloodDrip(0.35, 9, 3)],
      icon: const Icon(Icons.menu, color: Color(0xffd8cfbf), size: 20),
      onPressed: () {
        AudioScope.of(context).play(Sfx.uiClick);
        game.openMenu();
      },
    );
  }
}

/// The direction a drag of [delta] points to: the axis it leans on most.
/// [current] is kept until the other axis clearly wins, so a thumb
/// drifting along a diagonal does not flicker between two directions.
Direction directionOf(Offset delta, {Direction? current}) {
  final horizontal = delta.dx.abs();
  final vertical = delta.dy.abs();
  final horizontalWins = switch (current) {
    Direction.east || Direction.west => horizontal * _axisBias >= vertical,
    Direction.north || Direction.south => horizontal > vertical * _axisBias,
    null => horizontal > vertical,
  };
  if (horizontalWins) {
    return delta.dx > 0 ? Direction.east : Direction.west;
  }
  return delta.dy > 0 ? Direction.south : Direction.north;
}

const double _axisBias = 1.25;

/// Two fingers spread or pinched over the game zoom the view in or out,
/// toward the point between them (see [StepboundGame.zoom]). Two thumbs, one
/// walking and one acting, must not zoom, so a pinch is two fingers that
/// land together, or both on the same half of the screen; whatever the
/// first of them had started is dropped. Not while aiming.
final class PinchZone extends StatefulWidget {
  const PinchZone({required this.game, required this.child, super.key});

  final StepboundGame game;
  final Widget child;

  /// Two fingers landing within this of each other are a pinch wherever
  /// they are.
  static const Duration together = Duration(milliseconds: 250);

  @override
  State<PinchZone> createState() => _PinchZoneState();
}

final class _PinchZoneState extends State<PinchZone> {
  /// Every finger down: where it is, locally and on the screen, and when
  /// it landed.
  final Map<int, ({Offset local, Offset global, Duration at})> _touches =
      <int, ({Offset local, Offset global, Duration at})>{};

  /// The two fingers of the pinch, while there is one.
  (int, int)? _pair;
  double _startDistance = 1;

  StepboundGame get _game => widget.game;

  @override
  void dispose() {
    if (_game.pinching.value) {
      _game.endPinch();
    }
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    _touches[event.pointer] = (
      local: event.localPosition,
      global: event.position,
      at: event.timeStamp,
    );
    if (_game.pinching.value || _touches.length != 2 || _game.aiming.value) {
      return;
    }
    final first = _touches.entries.firstWhere(
      (touch) => touch.key != event.pointer,
    );
    final half = (context.size?.width ?? 0) / 2;
    final sameHalf =
        (first.value.local.dx < half) == (event.localPosition.dx < half);
    if (!sameHalf && event.timeStamp - first.value.at > PinchZone.together) {
      return;
    }
    _pair = (first.key, event.pointer);
    _startDistance = _distance(first.value.global, event.position);
    _game.beginPinch(_middle(first.value.global, event.position));
  }

  void _move(PointerMoveEvent event) {
    final touch = _touches[event.pointer];
    if (touch == null) {
      return;
    }
    _touches[event.pointer] = (
      local: event.localPosition,
      global: event.position,
      at: touch.at,
    );
    final pair = _pair;
    if (pair == null ||
        (event.pointer != pair.$1 && event.pointer != pair.$2)) {
      return;
    }
    final a = _touches[pair.$1]!.global;
    final b = _touches[pair.$2]!.global;
    _game.pinch(_distance(a, b) / _startDistance, _middle(a, b));
  }

  void _up(PointerEvent event) {
    _touches.remove(event.pointer);
    final pair = _pair;
    if (pair != null &&
        (event.pointer == pair.$1 || event.pointer == pair.$2)) {
      _pair = null;
    }
    // Only once every finger is up can a new touch walk or act again.
    if (_touches.isEmpty && _game.pinching.value) {
      _game.endPinch();
    }
  }

  static double _distance(Offset a, Offset b) => math.max((a - b).distance, 1);

  static Offset _middle(Offset a, Offset b) => (a + b) / 2;

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey<String>('touch-pinch'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}

/// The left half of the screen: wherever the thumb lands is the centre,
/// dragging away from it walks that way for as long as the thumb stays
/// down, and dragging elsewhere without lifting it turns.
final class MoveZone extends StatefulWidget {
  const MoveZone({required this.game, super.key});

  final StepboundGame game;

  /// How far the thumb goes before Mario starts walking.
  static const double deadZone = 16;

  /// The centre follows a thumb that goes further than this, so turning
  /// back never needs a long drag across the old centre.
  static const double reach = 44;

  @override
  State<MoveZone> createState() => _MoveZoneState();
}

final class _MoveZoneState extends State<MoveZone> {
  int? _pointer;
  int _seed = 0;
  Offset? _centre;
  Offset? _thumb;
  Direction? _walking;

  @override
  void initState() {
    super.initState();
    widget.game.pinching.addListener(_onPinch);
  }

  @override
  void dispose() {
    widget.game.pinching.removeListener(_onPinch);
    _stop();
    super.dispose();
  }

  /// Two fingers are zooming: this thumb was one of them, not a step.
  void _onPinch() {
    if (!widget.game.pinching.value || _pointer == null) {
      return;
    }
    _stop();
    setState(() {
      _pointer = null;
      _centre = null;
      _thumb = null;
    });
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || widget.game.pinching.value) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _seed = Object.hash(event.localPosition, event.timeStamp);
      _centre = event.localPosition;
      _thumb = event.localPosition;
    });
  }

  void _move(PointerMoveEvent event) {
    final centre = _centre;
    if (event.pointer != _pointer || centre == null) {
      return;
    }
    final thumb = event.localPosition;
    var delta = thumb - centre;
    if (delta.distance > MoveZone.reach) {
      delta = delta / delta.distance * MoveZone.reach;
    }
    setState(() {
      _centre = thumb - delta;
      _thumb = thumb;
    });
    // With the pistol up, the right thumb has the say: Mario stands and
    // aims, and this one neither walks him nor fires.
    if (widget.game.aiming.value || delta.distance < MoveZone.deadZone / 2) {
      _stop();
      return;
    }
    if (delta.distance < MoveZone.deadZone && _walking == null) {
      return;
    }
    final direction = directionOf(delta, current: _walking);
    if (direction == _walking) {
      return;
    }
    _stop();
    _walking = direction;
    widget.game.pressDirection(direction);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _stop();
    setState(() {
      _pointer = null;
      _centre = null;
      _thumb = null;
    });
  }

  void _stop() {
    final walking = _walking;
    if (walking != null) {
      _walking = null;
      widget.game.releaseDirection(walking);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trascina per muoverti',
      child: Listener(
        key: const ValueKey<String>('touch-move'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: CustomPaint(
          painter: _StickPainter(centre: _centre, thumb: _thumb, seed: _seed),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The right half of the screen. A tap interacts. Holding raises the
/// pistol, with a splash of blood, and brings up a stick like the one that
/// walks: dragging turns Mario where it points, and lifting the finger
/// fires that way, unless it is lifted back in the ring in the middle,
/// which lowers the pistol without firing.
final class ActionZone extends StatefulWidget {
  const ActionZone({required this.game, super.key});

  final StepboundGame game;

  /// How long a finger stays down before Mario aims.
  static const Duration holdToAim = StepboundGame.holdToAim;

  /// How far a finger may wander and still count as a tap or a hold.
  static const double slop = 14;

  /// The aiming stick's reach: its centre follows a finger that goes
  /// further, as the walking one does.
  static const double reach = MoveZone.reach;

  /// The ring in the middle of the aiming stick: a finger lifted inside it
  /// lowers the pistol instead of firing.
  static const double cancelRadius = 18;

  @override
  State<ActionZone> createState() => _ActionZoneState();
}

enum _Touch {
  /// Down, not long enough to aim yet: lifting it now is a tap.
  pending,

  /// The pistol is up and follows the finger: lifting it fires, or lowers
  /// the pistol in the middle ring.
  aiming,

  /// Nothing more to do until it lifts.
  spent,
}

final class _ActionZoneState extends State<ActionZone> {
  int? _pointer;
  int _seed = 0;
  Offset? _centre;
  Offset? _thumb;
  _Touch _touch = _Touch.spent;
  Direction? _aim;
  Timer? _hold;

  StepboundGame get _game => widget.game;

  /// Where the stick points from its centre, no further than its reach.
  Offset get _delta {
    final centre = _centre;
    final thumb = _thumb;
    if (centre == null || thumb == null) {
      return Offset.zero;
    }
    return thumb - centre;
  }

  bool get _inCancelRing => _delta.distance <= ActionZone.cancelRadius;

  @override
  void initState() {
    super.initState();
    _game.pinching.addListener(_onPinch);
  }

  @override
  void dispose() {
    _game.pinching.removeListener(_onPinch);
    _hold?.cancel();
    super.dispose();
  }

  /// Two fingers are zooming: this one was one of them, neither a tap nor
  /// the start of aiming.
  void _onPinch() {
    if (!_game.pinching.value || _pointer == null) {
      return;
    }
    _hold?.cancel();
    _hold = null;
    setState(() {
      _pointer = null;
      _centre = null;
      _thumb = null;
      _aim = null;
      _touch = _Touch.spent;
    });
  }

  void _splat(Offset at, SplatKind kind, {Offset direction = Offset.zero}) {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      BloodSplatLayer.maybeOf(
        context,
      )?.splat(box.localToGlobal(at), kind, direction: direction);
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || _game.pinching.value) {
      return;
    }
    _pointer = event.pointer;
    _seed = Object.hash(event.localPosition, event.timeStamp);
    _centre = event.localPosition;
    _thumb = event.localPosition;
    _aim = null;
    // Already up (the space bar raised it): the stick is there at once.
    if (_game.aiming.value) {
      _touch = _Touch.aiming;
    } else {
      _touch = _Touch.pending;
      if (_game.isUnlocked(HudElement.shoot)) {
        _hold = Timer(ActionZone.holdToAim, _raisePistol);
      }
    }
    setState(() {});
  }

  void _raisePistol() {
    _hold = null;
    if (_touch != _Touch.pending) {
      return;
    }
    _game.beginAim();
    final thumb = _thumb;
    if (thumb != null) {
      _splat(thumb, SplatKind.hold);
    }
    setState(() {
      if (_game.aiming.value) {
        _touch = _Touch.aiming;
        // The stick is centred where the finger rests now.
        _centre = _thumb;
      } else {
        // Nothing loaded: the pistol only clicked.
        _touch = _Touch.spent;
      }
    });
  }

  void _move(PointerMoveEvent event) {
    final centre = _centre;
    if (event.pointer != _pointer || centre == null) {
      return;
    }
    final thumb = event.localPosition;
    switch (_touch) {
      case _Touch.pending:
        setState(() => _thumb = thumb);
        if ((thumb - centre).distance > ActionZone.slop) {
          // A swipe before the pistol is up is neither a tap nor a shot.
          _hold?.cancel();
          _hold = null;
          _touch = _Touch.spent;
        }
      case _Touch.aiming:
        var delta = thumb - centre;
        if (delta.distance > ActionZone.reach) {
          delta = delta / delta.distance * ActionZone.reach;
        }
        setState(() {
          _centre = thumb - delta;
          _thumb = thumb;
        });
        if (delta.distance <= ActionZone.cancelRadius) {
          return;
        }
        final direction = directionOf(delta, current: _aim);
        if (direction != _aim) {
          _aim = direction;
          _game.aimToward(direction);
        }
      case _Touch.spent:
        setState(() => _thumb = thumb);
    }
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final lifted = event is PointerUpEvent;
    _hold?.cancel();
    _hold = null;
    switch (_touch) {
      case _Touch.pending when lifted:
        if (_game.isUnlocked(HudElement.interact)) {
          _splat(event.localPosition, SplatKind.tap);
        }
        _game.pressInteract();
      case _Touch.aiming:
        final aim = _aim;
        final centre = _centre;
        if (lifted && aim != null && centre != null && !_inCancelRing) {
          _game.shootToward(aim);
          _splat(centre, SplatKind.swipe, direction: _delta);
        } else {
          _splat(event.localPosition, SplatKind.tap);
          _game.cancelAim();
        }
      case _Touch.pending || _Touch.spent:
        break;
    }
    setState(() {
      _pointer = null;
      _centre = null;
      _thumb = null;
      _aim = null;
      _touch = _Touch.spent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Tocca per interagire, tieni premuto e trascina per mirare, '
          'lascia per sparare',
      child: Listener(
        key: const ValueKey<String>('touch-act'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: ValueListenableBuilder<bool>(
          valueListenable: _game.aiming,
          builder: (context, aiming, _) => CustomPaint(
            painter: aiming && _touch == _Touch.aiming
                ? _StickPainter(
                    centre: _centre,
                    thumb: _thumb,
                    seed: _seed,
                    cancelRadius: ActionZone.cancelRadius,
                  )
                : null,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// A pool of blood where the finger landed and a drop of it under the
/// finger, smeared between the two, so the player sees which way the drag
/// points. Pixel art, on the same grid as the splats; [seed] picks where
/// the ring drips, so every touch drips differently. Aiming, the blood is
/// brighter and a pale ring of [cancelRadius] marks the middle: it lights
/// up, with the pistol greyed on the drop, while the finger rests inside
/// it, where lifting it fires nothing.
final class _StickPainter extends CustomPainter {
  const _StickPainter({
    required this.centre,
    required this.thumb,
    required this.seed,
    this.cancelRadius,
  });

  final Offset? centre;
  final Offset? thumb;
  final int seed;
  static const double reach = MoveZone.reach;
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
      const _PistolIcon(color: Color(0x88f2ebdd)).paint(canvas, icon);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StickPainter oldDelegate) =>
      oldDelegate.centre != centre ||
      oldDelegate.thumb != thumb ||
      oldDelegate.seed != seed ||
      oldDelegate.cancelRadius != cancelRadius;
}

/// The pistol and the bullets Mario carries, in the row of the things he
/// holds up in the corner: the pistol in colour like the rest, and the
/// count written in blood over the bottom-right corner, spilling past it.
/// Until the pistol is found the badge is a button nothing can press yet:
/// greyed out and deaf to taps, though the count keeps up with every round
/// picked up. With the pistol, a tap tells how many there are.
final class _AmmoBadge extends StatelessWidget {
  const _AmmoBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  /// How far the count spills past the right and bottom edges.
  static const double spill = 7;

  /// A disabled badge: the colour drained out of it, and half gone.
  static const ColorFilter _greyed = ColorFilter.matrix(<double>[
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0, 0, 0, 0.5, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoLoaded,
      builder: (context, loaded, _) => ValueListenableBuilder<bool>(
        valueListenable: game.hasGun,
        builder: (context, hasGun, _) {
          final isEmpty = loaded == 0;
          Widget frame = BloodOverlay(
            painter: const BloodPainter(
              band: 3,
              cornerRadius: 8,
              drips: <BloodDrip>[BloodDrip(0.22, 11, 4), BloodDrip(0.8, 7, 3)],
            ),
            child: Container(
              key: const ValueKey<String>('touch-ammo'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xcc241a1a),
                border: Border.all(
                  color: !hasGun
                      ? BloodColors.dried
                      : isEmpty
                      ? BloodColors.bright
                      : BloodColors.fresh,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
                ],
              ),
              // A little up and left of the middle, so the count does not
              // cover the grip.
              child: const Align(
                alignment: Alignment(-0.2, -0.3),
                child: CustomPaint(
                  size: Size(34, 23.4),
                  painter: _ColourPistolIcon(),
                ),
              ),
            ),
          );
          if (!hasGun) {
            frame = ColorFiltered(colorFilter: _greyed, child: frame);
          }
          return Semantics(
            button: true,
            enabled: hasGun,
            label: hasGun
                ? 'Pistola, proiettili: $loaded'
                : 'Pistola da trovare, proiettili: $loaded',
            child: GestureDetector(
              onTap: hasGun
                  ? () {
                      AudioScope.of(context).play(Sfx.uiClick);
                      game.inspectAmmo();
                    }
                  : null,
              child: Padding(
                // Room for the count spilling out, so the row does not lay
                // the next badge over it.
                padding: const EdgeInsets.only(right: spill, bottom: spill),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    frame,
                    Positioned(
                      right: -spill,
                      bottom: -spill,
                      child: Opacity(
                        opacity: hasGun ? 1 : 0.6,
                        child: _BloodCount(
                          key: const ValueKey<String>('touch-ammo-count'),
                          text: '×$loaded',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A count written with a finger dipped in blood: thick red strokes gone
/// dark at the edges, and drops running down from the foot of the figures.
final class _BloodCount extends StatelessWidget {
  const _BloodCount({required this.text, super.key});

  final String text;

  static const double fontSize = 17;

  static TextStyle _style({Paint? foreground, Color? color}) => TextStyle(
    color: color,
    foreground: foreground,
    fontFamily: 'monospace',
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: -1,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _BloodRunPainter(text.length),
      child: Stack(
        children: <Widget>[
          // The dried rim, then the wet blood over it.
          Text(
            text,
            style: _style(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xff2a0404),
            ),
          ),
          Text(text, style: _style(color: BloodColors.fresh)),
          Text(
            text,
            style: _style(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = BloodColors.bright,
            ),
          ),
        ],
      ),
    );
  }
}

/// The drops running down from the foot of a blood count: one under every
/// other figure, of lengths that do not repeat from one to the next.
final class _BloodRunPainter extends CustomPainter {
  const _BloodRunPainter(this.figures);

  final int figures;

  static const List<double> _lengths = <double>[5, 3, 6, 4];

  @override
  void paint(Canvas canvas, Size size) {
    final blood = Paint()..color = BloodColors.fresh;
    final drop = Paint()..color = BloodColors.bright;
    final step = size.width / math.max(1, figures);
    for (var i = 0; i < figures; i += 2) {
      final x = step * (i + 0.6);
      final length = _lengths[i % _lengths.length];
      final top = size.height - 3;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 1, top, 2, length),
            const Radius.circular(1),
          ),
          blood,
        )
        ..drawCircle(Offset(x, top + length), 1.6, drop);
    }
  }

  @override
  bool shouldRepaint(_BloodRunPainter oldDelegate) =>
      oldDelegate.figures != figures;
}

/// The censer found in San Nicola, hanging in the top corner for as long
/// as Mario carries it: the errand he is on, always in sight.
final class _IncenseBadge extends StatelessWidget {
  const _IncenseBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Incenso per Don Angelo',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Incenso');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.3, 13, 4), BloodDrip(0.74, 8, 3)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-incense'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: const Center(
              child: CustomPaint(size: Size(26, 30), painter: _CenserIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The key Don Angelo gives Mario for the Bar Arcobaleno service door.
final class _BarKeyBadge extends StatelessWidget {
  const _BarKeyBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chiave del Bar Arcobaleno',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Chiave del Bar Arcobaleno');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.24, 8, 3), BloodDrip(0.68, 12, 4)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-bar-key'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: const Center(
              child: CustomPaint(size: Size(28, 28), painter: _KeyIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The key taken from beside Don Angelo's body, for the door upstairs.
final class _DuomoKeyBadge extends StatelessWidget {
  const _DuomoKeyBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chiave del Duomo',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Chiave del Duomo');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.28, 11, 4), BloodDrip(0.7, 9, 3)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-duomo-key'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: const Center(
              child: CustomPaint(size: Size(28, 28), painter: _ChurchKeyIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Don Angelo's ring, carried only from the bar storeroom to the altar.
final class _EpiscopalRingBadge extends StatelessWidget {
  const _EpiscopalRingBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Anello episcopale',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Anello episcopale');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.34, 10, 3), BloodDrip(0.78, 7, 3)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-episcopal-ring'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/sprites/episcopal_ring.png',
                width: 28,
                height: 28,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    required this.size,
    this.drips = const <BloodDrip>[],
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final List<BloodDrip> drips;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: BloodOverlay(
          painter: BloodPainter(band: 5, cornerRadius: size / 2, drips: drips),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xcc2e2020),
              border: Border.all(color: BloodColors.fresh, width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

final class _PistolIcon extends CustomPainter {
  const _PistolIcon({required this.color});

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
  bool shouldRepaint(_PistolIcon oldDelegate) => oldDelegate.color != color;
}

/// A thurible swinging on its chain, smoking: the ring at the top, the
/// three chains down to the pierced lid, the bowl under it.
final class _CenserIcon extends CustomPainter {
  const _CenserIcon();

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
  bool shouldRepaint(_CenserIcon oldDelegate) => false;
}

/// The Duomo's own key: old iron, its bow a cross, so that it is not the
/// bar's brass key at a glance.
final class _ChurchKeyIcon extends CustomPainter {
  const _ChurchKeyIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final iron = Paint()..color = const Color(0xff8e949c);
    final dark = Paint()..color = const Color(0xff4e545c);
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawRect(const Rect.fromLTWH(4, 2, 3, 12), iron)
      ..drawRect(const Rect.fromLTWH(1, 6, 9, 3), iron)
      ..drawRect(const Rect.fromLTWH(1, 8, 9, 1), dark)
      ..drawRect(const Rect.fromLTWH(7, 15, 15, 3), iron)
      ..drawRect(const Rect.fromLTWH(7, 17, 15, 1), dark)
      ..drawRect(const Rect.fromLTWH(17, 18, 3, 4), iron)
      ..drawRect(const Rect.fromLTWH(20, 18, 2, 3), iron)
      ..restore();
  }

  @override
  bool shouldRepaint(_ChurchKeyIcon oldDelegate) => false;
}

final class _KeyIcon extends CustomPainter {
  const _KeyIcon();

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
  bool shouldRepaint(_KeyIcon oldDelegate) => false;
}

/// A semi-automatic pistol in profile, muzzle to the right, like the ones
/// the carabinieri carry: the blued steel slide with its serrations and the
/// barrel showing at the front, the hammer cocked at the back, the trigger
/// in its guard, and the grip in dark walnut.
final class _ColourPistolIcon extends CustomPainter {
  const _ColourPistolIcon();

  static const Color _outline = Color(0xff121417);
  static const Color _steel = Color(0xff66707c);
  static const Color _steelDark = Color(0xff3c434c);
  static const Color _steelLight = Color(0xffb4bec9);
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
  bool shouldRepaint(_ColourPistolIcon oldDelegate) => false;
}
