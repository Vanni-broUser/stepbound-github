import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  List<WorldEvent> interact(GridPoint door, Direction facing) {
    world.player.component<PositionComponent>()
      ..position = door.step(facing.opposite)
      ..facing = facing;
    final events = const TurnScheduler().advance(world, const InteractAction());
    director.onEvents(events);
    settle();
    return events;
  }

  // Whatever the start of Molfetta has to say, said and gone.
  setUp(() {
    for (settle(); host.isPromptVisible; settle()) {
      host.dismiss();
    }
    host.shown.clear();
  });

  test('from the street behind the barracks the shutter is down, and '
      'stays down', () {
    interact(northDistrictShopDoor, Direction.north);
    expect(
      host.shown.single.single.text,
      ElectronicsShopScript.shutterDownLine,
    );
    host.dismiss();
    expect(world.map.tileAt(northDistrictShopDoor).isWalkable, isFalse);
    expect(world.map.tileAt(electronicsShopBackDoor).isWalkable, isFalse);
  });

  test('from inside the shop the back door says to open it from inside, '
      'then opens, and the shutter by the camp with it', () {
    final events = interact(electronicsShopBackDoor, Direction.south);
    expect(events.whereType<NoInteractionEvent>(), hasLength(1));
    expect(
      host.shown.single.single.text,
      ElectronicsShopScript.openFromInsideLine,
    );
    expect(
      world.map.tileAt(electronicsShopBackDoor).isWalkable,
      isFalse,
      reason: 'the line first',
    );
    host.dismiss();
    expect(world.map.tileAt(electronicsShopBackDoor).isWalkable, isTrue);
    expect(world.map.tileAt(northDistrictShopDoor).isWalkable, isTrue);

    // Open, it has nothing more to say, from either side.
    host.shown.clear();
    interact(northDistrictShopDoor, Direction.north);
    expect(host.shown, isEmpty);
  });

  test('once open it is saved: a restored world has it open', () {
    interact(electronicsShopBackDoor, Direction.south);
    host.dismiss();
    final restored = restoreGameWorld(saveGameWorld(world));
    expect(restored.map.tileAt(electronicsShopBackDoor).isWalkable, isTrue);
    expect(restored.map.tileAt(northDistrictShopDoor).isWalkable, isTrue);
  });
}
