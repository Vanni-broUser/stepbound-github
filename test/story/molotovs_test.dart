import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('molotovs', () {
    AmmoComponent ammo() => world.player.component<AmmoComponent>();

    test('found with the pistol: the count, the area, and choosing', () {
      ammo()
        ..hasGun = true
        ..molotovs = 2;
      director.onEvents(<WorldEvent>[pickedUp(molotovBackpackId, molotovs: 2)]);
      settle();
      expect(host.shown.last.map((line) => line.text), <String>[
        'Hai trovato 2 molotov',
        BackpacksScript.molotovLesson,
        BackpacksScript.weaponChoiceLesson,
      ]);
      expect(
        host.shown.last.map((line) => line.demo),
        <ControlDemo?>[null, ControlDemo.aim, null],
        reason: 'the same finger that fires the pistol throws the bottle',
      );
      expect(host.unlocked, contains(HudElement.molotov));
      host.dismiss();

      // Found again: only the count.
      director.onEvents(<WorldEvent>[pickedUp(molotovBackpackId, molotovs: 2)]);
      settle();
      expect(host.shown.last.map((line) => line.text), <String>[
        'Hai trovato 2 molotov',
      ]);
    });

    test('found with no pistol: no choice to tell of, until the pistol', () {
      ammo()
        ..hasGun = false
        ..molotovs = 2;
      director.onEvents(<WorldEvent>[pickedUp(molotovBackpackId, molotovs: 2)]);
      settle();
      expect(host.shown.last.map((line) => line.text), <String>[
        'Hai trovato 2 molotov',
        BackpacksScript.molotovLesson,
      ]);
      host.dismiss();

      ammo().hasGun = true;
      director.onEvents(<WorldEvent>[pickedUp(gunBackpackId, gun: true)]);
      settle();
      expect(host.shown.last.last.text, BackpacksScript.weaponChoiceLesson);
    });

    test('told once, even across a save', () {
      ammo()
        ..hasGun = true
        ..molotovs = 2;
      director.onEvents(<WorldEvent>[pickedUp(molotovBackpackId, molotovs: 2)]);
      settle();
      host.dismiss();
      final saved = director.toJson();
      director =
          StoryDirector(
              world: world,
              host: host = FakeStoryHost(progress),
              progress: progress,
            )
            ..restore(saved)
            ..onEvents(<WorldEvent>[pickedUp(gunBackpackId, gun: true)]);
      settle();
      expect(
        host.shown.last.map((line) => line.text),
        isNot(contains(BackpacksScript.weaponChoiceLesson)),
      );
    });
  });

  test('Mario speaks when he reaches the barracks', () {
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      7,
    );
    settle();
    final lines = host.shown.single;
    expect(lines.map((line) => line.text), <String>[
      BarracksScript.barracksReached,
      BarracksScript.barracksSafe,
    ]);
    expect(lines.every((line) => line.speaker == 'Mario Rossi'), isTrue);
    expect(lines.first.portrait, isNotNull);
  });

  test('a few steps inside, the carabinieri come out of the dark', () {
    final inside = GridPoint(
      place(PlaceId.barracks).origin.x + 10,
      place(PlaceId.barracks).origin.y + 13,
    );
    MovedEvent step() => MovedEvent(
      entityId: world.playerId,
      from: inside.step(Direction.south),
      to: inside,
    );
    for (var i = 1; i < BarracksScript.stepsBeforeCarabinieri; i++) {
      director.onEvents(<WorldEvent>[step()]);
    }
    expect(host.spawned, isEmpty);
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns.length));
    expect(
      host.spawned.every((zombie) => zombie.kind == EntityKind.carabiniere),
      isTrue,
    );
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns.length));
  });

  test('steps outside do not count', () {
    for (var i = 0; i < 10; i++) {
      director.onEvents(<WorldEvent>[
        MovedEvent(
          entityId: world.playerId,
          from: const GridPoint(7, 36),
          to: const GridPoint(8, 36),
        ),
      ]);
    }
    expect(host.spawned, isEmpty);
  });

  test('the accident backpack teaches interaction if it is seen first', () {
    host.visible.add(world.pickups[accidentBackpackId]!.position);
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      BackpacksScript.backpackLesson,
      BackpacksScript.interactLesson,
    ]);
    host
      ..dismiss()
      ..visible.add(world.pickups[ammoBackpackId]!.position);
    settle();
    expect(host.shown, hasLength(1), reason: 'taught only once');
    expect(host.unlocked, contains(HudElement.interact));
  });

  test('hints have no speaker; only people are named', () {
    host.visible.add(world.pickups[ammoBackpackId]!.position);
    settle();
    expect(host.shown.single.every((line) => line.speaker == null), isTrue);
  });

  test('the first camp teaches saving, with the button if still missing', () {
    host.visible.add(
      world.campfires.firstWhere(place(PlaceId.northDistrict).bounds.contains),
    );
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      NorthDistrictScript.campLesson,
      BackpacksScript.interactLesson,
    ]);
    host.dismiss();
    expect(host.unlocked, contains(HudElement.interact));
  });

  test('a player who already interacts only hears about the camps', () {
    host
      ..unlocked.add(HudElement.interact)
      ..visible.add(
        world.campfires.firstWhere(
          place(PlaceId.northDistrict).bounds.contains,
        ),
      );
    settle();
    expect(host.shown.single.single.text, NorthDistrictScript.campLesson);
  });

  test('its progress survives a save', () {
    director.onEvents(<WorldEvent>[
      AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
    ]);
    final saved = director.toJson();
    final restored = StoryDirector(
      world: world,
      host: FakeStoryHost(),
      progress: Progress(),
    )..restore(saved);
    expect(restored.toJson(), saved);
    expect((saved['street']! as Map<String, Object?>)['zombieLesson'], isTrue);
  });

  test('the first sprinter in sight has its pace explained', () {
    final sprinter = world.entities.values.firstWhere(
      (entity) => entity.kind == EntityKind.sprinter,
    );
    final at = sprinter.component<PositionComponent>().position;
    settle();
    expect(host.shown, isEmpty);
    host.visible.add(at);
    settle();
    expect(host.wholeViews, 1);
    final line = host.shown.single.single;
    expect(line.text, zombieLore[EntityKind.sprinter]!.lesson);
    expect(line.portrait, zombieLore[EntityKind.sprinter]!.portrait);
    expect(line.speaker, isNull);
    host.dismiss();
    settle();
    expect(host.shown, hasLength(1), reason: 'the lesson is given once');
  });
}
