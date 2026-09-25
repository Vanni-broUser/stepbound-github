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

  @override
  Widget build(BuildContext context) {
    // No buttons to play: the left half of the screen walks, the right
    // half interacts and shoots. What is drawn on top only shows state,
    // plus the menu and the items carried, which take their own taps.
    return ValueListenableBuilder<Set<HudElement>>(
      valueListenable: game.hud,
      builder: (context, unlocked, _) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Row(
                children: <Widget>[
                  Expanded(child: MoveZone(game: game)),
                  Expanded(child: ActionZone(game: game)),
                ],
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(10),
              child: Stack(
                children: <Widget>[
                  if (unlocked.contains(HudElement.ammo))
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(child: _AmmoCounter(game: game)),
                    ),
                  // Always there, unlocked or not: it is the way out, not
                  // something the tutorial hands over.
                  Positioned(right: 0, top: 0, child: _PauseButton(game: game)),
                  // No button at all: what Mario is carrying for Don Angelo.
                  // The far top corner from the menu, out of both thumbs' way.
                  if (unlocked.contains(HudElement.incense) ||
                      unlocked.contains(HudElement.barKey) ||
                      unlocked.contains(HudElement.episcopalRing))
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Column(
                        children: <Widget>[
                          if (unlocked.contains(HudElement.incense))
                            _IncenseBadge(game: game),
                          if (unlocked.contains(HudElement.barKey))
                            _BarKeyBadge(game: game),
                          if (unlocked.contains(HudElement.episcopalRing))
                            _EpiscopalRingBadge(game: game),
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
  void dispose() {
    _stop();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) {
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
    if (delta.distance < MoveZone.deadZone / 2) {
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

/// The right half of the screen. A tap interacts, or lowers the pistol if
/// Mario is aiming. Holding raises the pistol; a swipe while aiming, with
/// the same finger or a new one, turns towards it and shoots. Each of the
/// three leaves blood on the glass where the finger was, for a moment.
final class ActionZone extends StatefulWidget {
  const ActionZone({required this.game, super.key});

  final StepboundGame game;

  /// How long a finger stays down before Mario aims.
  static const Duration holdToAim = StepboundGame.holdToAim;

  /// How far a finger may wander and still count as a tap or a hold.
  static const double slop = 14;

  /// How far a swipe goes before the shot is fired.
  static const double swipe = 28;

  @override
  State<ActionZone> createState() => _ActionZoneState();
}

enum _Touch {
  /// Down, not long enough to aim yet: lifting it now is a tap.
  pending,

  /// The pistol is up: a swipe shoots, lifting it without one ends the
  /// touch (a tap, if the pistol was already up when it began).
  aiming,

  /// Nothing more to do until it lifts.
  spent,
}

final class _ActionZoneState extends State<ActionZone> {
  int? _pointer;
  int _seed = 0;
  Offset? _origin;
  Offset? _thumb;
  _Touch _touch = _Touch.spent;
  bool _aimedBefore = false;
  Timer? _hold;

  StepboundGame get _game => widget.game;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
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
    if (_pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _seed = Object.hash(event.localPosition, event.timeStamp);
    _origin = event.localPosition;
    _thumb = event.localPosition;
    _aimedBefore = _game.aiming.value;
    if (_aimedBefore) {
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
        // The swipe is measured from where the finger rests now.
        _origin = _thumb;
      } else {
        // Nothing loaded: the pistol only clicked.
        _touch = _Touch.spent;
      }
    });
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (event.pointer != _pointer || origin == null) {
      return;
    }
    setState(() => _thumb = event.localPosition);
    final delta = event.localPosition - origin;
    switch (_touch) {
      case _Touch.pending when delta.distance > ActionZone.slop:
        // A swipe before the pistol is up is neither a tap nor a shot.
        _hold?.cancel();
        _hold = null;
        _touch = _Touch.spent;
      case _Touch.aiming when delta.distance >= ActionZone.swipe:
        _game.shootToward(directionOf(delta));
        _touch = _Touch.spent;
        _splat(origin, SplatKind.swipe, direction: delta);
      case _Touch.pending || _Touch.aiming || _Touch.spent:
        break;
    }
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final tapped = event is PointerUpEvent;
    _hold?.cancel();
    _hold = null;
    if (tapped && _touch == _Touch.pending) {
      if (_game.isUnlocked(HudElement.interact)) {
        _splat(event.localPosition, SplatKind.tap);
      }
      _game.pressInteract();
    } else if (tapped && _touch == _Touch.aiming && _aimedBefore) {
      _splat(event.localPosition, SplatKind.tap);
      _game.cancelAim();
    }
    setState(() {
      _pointer = null;
      _origin = null;
      _thumb = null;
      _touch = _Touch.spent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tocca per interagire, tieni premuto per mirare',
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
                    centre: _origin,
                    thumb: _thumb,
                    seed: _seed,
                    reach: ActionZone.swipe,
                    aiming: true,
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
/// the ring drips, so every touch drips differently.
final class _StickPainter extends CustomPainter {
  const _StickPainter({
    required this.centre,
    required this.thumb,
    required this.seed,
    this.reach = MoveZone.reach,
    this.aiming = false,
  });

  final Offset? centre;
  final Offset? thumb;
  final int seed;
  final double reach;
  final bool aiming;

  static const double _cell = BloodSplatPainter.cell;
  static const Color _pool = Color(0x662a0606);
  static const Color _gloss = Color(0xffeaa29a);
  static const Color _litAiming = Color(0xffe05050);

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
    final radius = reach / _cell;
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

    if (aiming) {
      const icon = Size(20, 20);
      canvas
        ..save()
        ..translate(
          originX + (kx + 0.5) * _cell - icon.width / 2,
          originY + (ky + 0.5) * _cell - icon.height / 2,
        );
      const _PistolIcon(color: Color(0xff1a1010)).paint(canvas, icon);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StickPainter oldDelegate) =>
      oldDelegate.centre != centre ||
      oldDelegate.thumb != thumb ||
      oldDelegate.seed != seed ||
      oldDelegate.aiming != aiming;
}

final class _AmmoCounter extends StatelessWidget {
  const _AmmoCounter({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoLoaded,
      builder: (context, loaded, _) {
        final isEmpty = loaded == 0;
        final contentColor = isEmpty
            ? BloodColors.bright
            : const Color(0xffd8cfbf);
        return Semantics(
          label: 'Proiettili: $loaded',
          child: BloodOverlay(
            painter: const BloodPainter(
              band: 3,
              cornerRadius: 8,
              drips: <BloodDrip>[BloodDrip(0.22, 11, 4), BloodDrip(0.8, 7, 3)],
            ),
            child: Container(
              key: const ValueKey<String>('touch-ammo'),
              width: TouchControls.actionButtonSize,
              height: TouchControls.actionButtonSize,
              decoration: BoxDecoration(
                color: const Color(0xcc241a1a),
                border: Border.all(
                  color: isEmpty ? BloodColors.bright : BloodColors.fresh,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CustomPaint(
                    size: const Size(16, 11),
                    painter: _BulletIcon(color: contentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u00d7$loaded',
                    style: TextStyle(
                      color: contentColor,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

final class _BulletIcon extends CustomPainter {
  const _BulletIcon({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..scale(size.width / 14)
      ..drawRect(const Rect.fromLTWH(1, 2.5, 8, 6), paint)
      ..drawPath(
        Path()
          ..moveTo(9, 2.5)
          ..lineTo(13.5, 5.5)
          ..lineTo(9, 8.5)
          ..close(),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BulletIcon oldDelegate) => oldDelegate.color != color;
}
