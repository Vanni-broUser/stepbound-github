// Assertions intentionally separate presentation updates for readability.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/render/grapple_component.dart';

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

  test('a swing with the grappling hook is played out, not snapped: Mario '
      'waits for the hook to catch, then goes over along the rope', () {
    final world = createGameWorld();
    world.player.component<AmmoComponent>().grapplingHook = true;
    final there = world.grapples[duomoTowerLookoutTile]!;
    final start = duomoTowerLookoutTile.step(there.facing.opposite);
    world.player.component<PositionComponent>()
      ..position = start
      ..facing = there.facing;
    final presentation = TurnPresentationController(world: world);
    presentation
      ..submit(const InteractAction())
      ..update(GrappleComponent.throwSeconds / 2);
    expect(presentation.isAnimating, isTrue);
    expect(presentation.visualPositionFor('player').x, start.x);
    expect(
      presentation.isEntityMoving('player'),
      isFalse,
      reason: 'carried by the rope, not walking',
    );

    presentation.update(
      GrappleComponent.throwSeconds / 2 +
          (GrappleComponent.totalSeconds - GrappleComponent.throwSeconds) / 2,
    );
    final halfway = presentation.visualPositionFor('player').x;
    expect(halfway, greaterThan(start.x));
    expect(halfway, lessThan(there.to.x));

    presentation.update(GrappleComponent.totalSeconds);
    expect(presentation.isAnimating, isFalse);
    expect(presentation.visualPositionFor('player').x, there.to.x);
  });

  test('the turn after a swing is an ordinary one again', () {
    final world = createGameWorld();
    world.player.component<AmmoComponent>().grapplingHook = true;
    final there = world.grapples[duomoTowerLookoutTile]!;
    world.player.component<PositionComponent>()
      ..position = duomoTowerLookoutTile.step(there.facing.opposite)
      ..facing = there.facing;
    final presentation = TurnPresentationController(world: world)
      ..submit(const InteractAction())
      ..update(GrappleComponent.totalSeconds)
      ..submit(const WaitAction())
      ..update(0.13);
    expect(presentation.isAnimating, isFalse);
  });
}
