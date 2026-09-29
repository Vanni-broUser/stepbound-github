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

  test('with the key, the flat behind it has no map yet: the '
      'work-in-progress screen, and the key is kept for it', () {
    host.unlock(HudElement.palazzoKey);
    knockAtTheLockedDoor();
    expect(host.workInProgressShown, 1);
    expect(host.unlocked, contains(HudElement.palazzoKey));
    expect(world.map.tileAt(palazzoLockedDoorTile).isWalkable, isFalse);
  });
}
