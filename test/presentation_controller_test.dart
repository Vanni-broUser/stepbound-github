// Assertions intentionally separate presentation updates for readability.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';

import 'test_world.dart';

void main() {
  test('movement is interpolated over 130 milliseconds', () {
    final world = corridorWorld(EntityKind.wanderer);
    final presentation = TurnPresentationController(world: world);
    presentation
      ..submit(const MoveAction(Direction.east))
      ..update(0.065);
    final position = presentation.visualPositionFor('player');
    expect(position.x, closeTo(1.5, 0.001));
    expect(position.y, 1);
    expect(presentation.isAnimating, isTrue);
    presentation.update(0.065);
    expect(presentation.isAnimating, isFalse);
    expect(presentation.visualPositionFor('player').x, 2);
  });

  test('input is buffered while a turn animation is active', () {
    final world = corridorWorld(EntityKind.wanderer);
    final presentation = TurnPresentationController(world: world);
    presentation
      ..submit(const MoveAction(Direction.east))
      ..submit(const WaitAction());
    expect(presentation.bufferedActionCount, 1);
    expect(world.tick, 1);
    presentation.update(0.13);
    expect(presentation.bufferedActionCount, 0);
    expect(world.tick, 2);
    expect(presentation.isAnimating, isTrue);
    presentation.update(0.13);
    expect(presentation.isAnimating, isFalse);
  });
}
