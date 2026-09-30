import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  List<WorldEvent> knockAtTheLockedDoor() {
    world.player.component<PositionComponent>()
      ..position = palazzoLockedDoorTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    director.onEvents(events);
    settle();
    return events;
  }

  test('the key of the third floor, found on the first, is told and goes '
      'on the badges', () {
    director.onEvents(<WorldEvent>[
      pickedUp(palazzoKeyPickupId, palazzoKey: true),
    ]);
    settle();
    expect(host.shown.single.single.text, BackpacksScript.palazzoKeyFound);
    expect(host.unlocked, contains(HudElement.palazzoKey));
    expect(HudElement.palazzoKey.level, LevelId.hometown);
  });

  test('without the key, the flat door still locked on the third floor '
      'only says so, and stays shut', () {
    final events = knockAtTheLockedDoor();
    expect(events.whereType<NoInteractionEvent>(), hasLength(1));
    expect(host.shown.single.single.text, PalazzoScript.lockedDoorLine);
    expect(host.workInProgressShown, 0);
    expect(world.map.tileAt(palazzoLockedDoorTile).isWalkable, isFalse);
  });

  test('with the key, the door opens for good on the flat behind it and '
      'the key is used up: a sprinter shut in there, and in the bedroom a '
      'backpack with two molotovs', () {
    host.unlock(HudElement.palazzoKey);
    knockAtTheLockedDoor();
    expect(host.workInProgressShown, 0);
    expect(host.shown.single.single.text, PalazzoScript.keyUsedLine);
    expect(host.unlocked, isNot(contains(HudElement.palazzoKey)));
    expect(world.map.tileAt(palazzoLockedDoorTile).isWalkable, isTrue);
    expect(placeAt(palazzoSprinterTile)?.id, PlaceId.palazzoLockedFlat);
    expect(world.entities[palazzoSprinterId]!.kind, EntityKind.sprinter);
    final backpack = world.pickups[palazzoMolotovBackpackId]!;
    expect(backpack.molotovs, 2);
    expect(placeAt(backpack.position)?.id, PlaceId.palazzoLockedFlat);
    // Through the open door, into the flat.
    world.player.component<PositionComponent>()
      ..position = palazzoLockedDoorTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.east),
    );
    expect(events.whereType<TeleportedEvent>(), hasLength(1));
    expect(
      world.player.component<PositionComponent>().position,
      palazzoLockedFlatDoor.step(Direction.east),
    );
  });
}
