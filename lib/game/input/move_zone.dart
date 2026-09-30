import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/stick_painter.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/l10n/language.dart';

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
  static const double reach = StickPainter.reach;

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
    // A thumb still down when a text box takes the controls away keeps
    // sending its moves here: forgotten, they are ignored.
    _pointer = null;
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
    if (widget.game.input.aiming.value ||
        delta.distance < MoveZone.deadZone / 2) {
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
    widget.game.input.pressDirection(direction);
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
      widget.game.input.releaseDirection(walking);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: strings.moveZoneHint,
      child: Listener(
        key: const ValueKey<String>('touch-move'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: CustomPaint(
          painter: StickPainter(centre: _centre, thumb: _thumb, seed: _seed),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
