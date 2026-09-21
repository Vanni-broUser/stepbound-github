import 'dart:collection';

import 'package:stepbound/core/core.dart';

final class VisualPosition {
  const VisualPosition(this.x, this.y);
  final double x;
  final double y;
}

final class MovementTrack {
  const MovementTrack({required this.from, required this.to});
  final GridPoint from;
  final GridPoint to;
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
  bool _isAnimating = false;
  int _turnCount = 0;

  bool get isAnimating => _isAnimating;
  int get bufferedActionCount => _buffer.length;
  int get turnCount => _turnCount;
  double get progress =>
      _isAnimating ? (_elapsed / turnDuration).clamp(0, 1) : 1;
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
      final untilComplete = turnDuration - _elapsed;
      if (remaining < untilComplete) {
        _elapsed += remaining;
        return;
      }
      remaining -= untilComplete;
      _finishCurrentTurn();
      if (_buffer.isNotEmpty) {
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
    final amount = progress;
    return VisualPosition(
      movement.from.x + (movement.to.x - movement.from.x) * amount,
      movement.from.y + (movement.to.y - movement.from.y) * amount,
    );
  }

  bool isEntityMoving(String entityId) =>
      _isAnimating && _movements.containsKey(entityId);

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
    _elapsed = 0;
    _isAnimating = true;
  }

  void _finishCurrentTurn() {
    _elapsed = 0;
    _isAnimating = false;
    _movements.clear();
  }
}
