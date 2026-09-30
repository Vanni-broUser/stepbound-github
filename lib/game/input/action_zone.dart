import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/input/move_zone.dart';
import 'package:stepbound/game/input/stick_painter.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/blood_splat.dart';

/// The right half of the screen. A tap interacts. Holding raises the
/// pistol, with a splash of blood, and brings up a stick like the one that
/// walks: dragging turns Mario where it points, and lifting the finger
/// fires that way, unless it is lifted back in the ring in the middle,
/// which lowers the pistol without firing.
final class ActionZone extends StatefulWidget {
  const ActionZone({required this.game, super.key});

  final StepboundGame game;

  /// How long a finger stays down before Mario aims.
  static const Duration holdToAim = GameInputController.holdToAim;

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
    // A finger still down when a text box takes the controls away keeps
    // sending its moves and its lift here: forgotten, they are ignored.
    _pointer = null;
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
    if (_game.input.aiming.value) {
      _touch = _Touch.aiming;
    } else {
      _touch = _Touch.pending;
      if (_game.input.canAim) {
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
    _game.input.beginAim();
    final thumb = _thumb;
    if (thumb != null) {
      _splat(thumb, SplatKind.hold);
    }
    setState(() {
      if (_game.input.aiming.value) {
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
        if (_game.input.throwing) {
          // The square follows the stick: its way, and how far out it is
          // between the ring and the reach.
          _aim = direction;
          const span = ActionZone.reach - ActionZone.cancelRadius;
          final pull = (delta.distance - ActionZone.cancelRadius) / span;
          _game.input.aimThrow(delta / delta.distance * pull);
          return;
        }
        if (direction != _aim) {
          _aim = direction;
          _game.input.aimToward(direction);
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
        _game.input.pressInteract();
      case _Touch.aiming:
        final aim = _aim;
        final centre = _centre;
        if (lifted && aim != null && centre != null && !_inCancelRing) {
          if (_game.input.throwing) {
            _game.input.throwMolotov();
          } else {
            _game.input.shootToward(aim);
          }
          _splat(centre, SplatKind.swipe, direction: _delta);
        } else {
          _splat(event.localPosition, SplatKind.tap);
          _game.input.cancelAim();
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
      label: strings.actionZoneHint,
      child: Listener(
        key: const ValueKey<String>('touch-act'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: ValueListenableBuilder<bool>(
          valueListenable: _game.input.aiming,
          builder: (context, aiming, _) => CustomPaint(
            painter: aiming && _touch == _Touch.aiming
                ? StickPainter(
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
