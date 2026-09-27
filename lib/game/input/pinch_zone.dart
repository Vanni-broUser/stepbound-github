import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/game/stepbound_game.dart';

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
    if (_game.pinching.value ||
        _touches.length != 2 ||
        _game.input.aiming.value) {
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
