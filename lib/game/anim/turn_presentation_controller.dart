import 'dart:collection';

import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/grapple_component.dart';
import 'package:stepbound/game/render/molotov_blast_component.dart';

final class VisualPosition {
  const VisualPosition(this.x, this.y);
  final double x;
  final double y;
}

final class MovementTrack {
  const MovementTrack({
    required this.from,
    required this.to,
    this.startAt = 0,
    this.walking = true,
  });
  final GridPoint from;
  final GridPoint to;

  /// How far into the turn the movement starts: before, the entity waits
  /// at [from]; from there it eases into [to] by the end of the turn.
  final double startAt;

  /// False when the entity is carried rather than walking (along the rope
  /// of the grappling hook): its legs stay still.
  final bool walking;
}

final class TurnPresentationController {
  TurnPresentationController({
    required this.world,
    this.scheduler = const TurnScheduler(),
    this.turnDuration = 0.13,
    this.maximumBufferedActions = 16,
  });

  final WorldState world;
  final TurnScheduler scheduler;
  final double turnDuration;
  final int maximumBufferedActions;
  final Queue<PlayerAction> _buffer = Queue<PlayerAction>();
  final Map<String, MovementTrack> _movements = <String, MovementTrack>{};
  List<WorldEvent> _lastEvents = const <WorldEvent>[];
  double _elapsed = 0;

  /// This turn's length: [turnDuration], or longer for a swing across a
  /// gap with the grappling hook, or for a molotov in the air.
  double _duration = 0.13;
  bool _isAnimating = false;
  int _turnCount = 0;

  /// The burst of the molotov in the air, played as soon as it lands:
  /// before anything Mario asked for meanwhile, which waits for it.
  MolotovBurstAction? _burst;

  /// Seconds from the throw to the bottle breaking: Mario's swing, then
  /// its flight. Nobody moves until then.
  static const double molotovHoldSeconds =
      CharacterComponent.throwReleaseDelay +
      MolotovBlastComponent.flightSeconds;

  bool get isAnimating => _isAnimating;

  /// Whether a molotov is in the air: thrown, and not burst yet.
  bool get holdsMolotov => _burst != null;
  int get bufferedActionCount => _buffer.length;
  int get turnCount => _turnCount;
  double get progress => _isAnimating ? (_elapsed / _duration).clamp(0, 1) : 1;
  List<WorldEvent> get lastEvents => List<WorldEvent>.unmodifiable(_lastEvents);

  void submit(PlayerAction action) {
    if (_isAnimating) {
      if (_buffer.length < maximumBufferedActions) {
        _buffer.addLast(action);
      }
      return;
    }
    _start(action);
  }

  void update(double dt) {
    var remaining = dt;
    while (_isAnimating && remaining > 0) {
      final untilComplete = _duration - _elapsed;
      if (remaining < untilComplete) {
        _elapsed += remaining;
        return;
      }
      remaining -= untilComplete;
      _finishCurrentTurn();
      if (_burst case final burst?) {
        _burst = null;
        _start(burst);
      } else if (_buffer.isNotEmpty) {
        _start(_buffer.removeFirst());
      }
    }
  }

  VisualPosition visualPositionFor(String entityId) {
    final movement = _movements[entityId];
    if (movement == null || !_isAnimating) {
      final point = world.entities[entityId]!
          .component<PositionComponent>()
          .position;
      return VisualPosition(point.x.toDouble(), point.y.toDouble());
    }
    var amount = progress;
    if (movement.startAt > 0) {
      final t = ((amount - movement.startAt) / (1 - movement.startAt)).clamp(
        0.0,
        1.0,
      );
      // Eased: slow off the edge, quick over the gap, slow to land.
      amount = t * t * (3 - 2 * t);
    }
    return VisualPosition(
      movement.from.x + (movement.to.x - movement.from.x) * amount,
      movement.from.y + (movement.to.y - movement.from.y) * amount,
    );
  }

  bool isEntityMoving(String entityId) =>
      _isAnimating && (_movements[entityId]?.walking ?? false);

  void clearBuffer() => _buffer.clear();

  void _start(PlayerAction action) {
    _lastEvents = scheduler.advance(world, action);
    _turnCount += 1;
    _movements
      ..clear()
      ..addEntries(
        _lastEvents.whereType<MovedEvent>().map(
          (event) => MapEntry<String, MovementTrack>(
            event.entityId,
            MovementTrack(from: event.from, to: event.to),
          ),
        ),
      );
    _duration = turnDuration;
    for (final event in _lastEvents) {
      if (event case MolotovThrownEvent(:final target)) {
        _duration = molotovHoldSeconds;
        _burst = MolotovBurstAction(target);
      }
      if (event case TeleportedEvent(
        grappled: true,
        :final entityId,
        :final from,
        :final to,
      )) {
        _duration = GrappleComponent.totalSeconds;
        _movements[entityId] = MovementTrack(
          from: from,
          to: to,
          startAt:
              GrappleComponent.throwSeconds / GrappleComponent.totalSeconds,
          walking: false,
        );
      }
    }
    _elapsed = 0;
    _isAnimating = true;
  }

  void _finishCurrentTurn() {
    _elapsed = 0;
    _isAnimating = false;
    _movements.clear();
  }
}
