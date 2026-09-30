import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('saves', () {
    Map<String, Object?> throughStorage(Map<String, Object?> json) =>
        jsonDecode(jsonEncode(json)) as Map<String, Object?>;

    test('store what changed, not the whole map: a few kilobytes', () {
      final world = createGameWorld();
      final save = jsonEncode(saveGameWorld(world));
      // Every zombie of every level is in it, Rome's streets' and the
      // palazzo's past the airliner too, the call center's, those in
      // the palazzo and the bank on Via Marsala, and those in the block
      // east of the hospital: some 450 bytes each, so the budget grows
      // with the cast.
      expect(save.length, lessThan(106 * 1024));
      expect(saveGameWorld(world).containsKey('map'), isFalse);
      expect(saveGameWorld(world)['mapChanges'], isEmpty);
    });

    test('zombies killed or moved, backpacks collected, the lifted shutter '
        'and Mario all survive a save and a load', () {
      final world = createGameWorld();
      final zombies = world.entities.values
          .where((entity) => entity.kind != EntityKind.player)
          .toList();
      final killed = zombies[0];
      final moved = zombies[1];
      killed.component<HealthComponent>().current = 0;
      final movedTo = moved.component<PositionComponent>().position.step(
        Direction.north,
      );
      moved.component<PositionComponent>()
        ..position = movedTo
        ..facing = Direction.north;
      world.pickups[ammoBackpackId]!
        ..active = false
        ..collected = true;
      final panel = mallPanelTile;
      world.player.component<PositionComponent>()
        ..position = panel.step(Direction.south)
        ..facing = Direction.north;
      world.player.component<AmmoComponent>().loaded = 3;
      const InteractAction().resolve(world);
      final shutter = GridPoint(luigiBars.left, luigiBars.top);
      expect(world.map.tileAt(shutter).isWalkable, isTrue);

      final save = throughStorage(saveGameWorld(world));
      expect(
        save['mapChanges'],
        hasLength(luigiBars.right - luigiBars.left + 1),
      );
      final restored = restoreGameWorld(save);

      expect(restored.entities[killed.id]!.isAlive, isFalse);
      expect(
        restored.entities[moved.id]!.component<PositionComponent>().position,
        movedTo,
      );
      expect(
        restored.entities[moved.id]!.component<PositionComponent>().facing,
        Direction.north,
      );
      expect(restored.pickups[ammoBackpackId]!.collected, isTrue);
      expect(restored.pickups[ammoBackpackId]!.active, isFalse);
      expect(restored.map.tileAt(shutter).isWalkable, isTrue);
      expect(restored.controls, isEmpty);
      expect(
        restored.player.component<PositionComponent>().position,
        panel.step(Direction.south),
      );
      expect(restored.player.component<AmmoComponent>().loaded, 3);
      expect(restored.map.width, world.map.width);
    });

    test('only the tiles set since the map was built are looked at, and one '
        'set back to the level is no change', () {
      final world = createGameWorld();
      final shutter = GridPoint(luigiBars.left, luigiBars.top);
      final was = world.map.tileAt(shutter);
      world.map.setTile(shutter, const Tile(TileKind.floor));
      expect(saveGameWorld(world)['mapChanges'], hasLength(1));
      world.map.setTile(shutter, was);
      expect(saveGameWorld(world)['mapChanges'], isEmpty);
      expect(
        world.map.touched,
        hasLength(1),
        reason: 'set twice, the cell is still one to look at',
      );
      // A restored world only has the saved changes to look at.
      world.map.setTile(shutter, const Tile(TileKind.floor));
      final restored = restoreGameWorld(throughStorage(saveGameWorld(world)));
      expect(restored.map.touched, hasLength(1));
      expect(saveGameWorld(restored)['mapChanges'], hasLength(1));
    });

    test('an older save gains backpacks added by the current level', () {
      final world = createGameWorld();
      world.pickups[ammoBackpackId]!
        ..active = false
        ..collected = true;
      final oldSave = throughStorage(saveGameWorld(world));
      (oldSave['pickups']! as List<Object?>).removeWhere(
        (encoded) =>
            (encoded! as Map<String, Object?>)['id'] == incenseBackpackId,
      );

      final restored = restoreGameWorld(oldSave);

      expect(restored.pickups[incenseBackpackId], isNotNull);
      expect(restored.pickups[incenseBackpackId]!.active, isTrue);
      expect(restored.pickups[incenseBackpackId]!.collected, isFalse);
      expect(
        restored.pickups[incenseBackpackId]!.position,
        createGameWorld().pickups[incenseBackpackId]!.position,
      );
      expect(
        restored.pickups[ammoBackpackId]!.collected,
        isTrue,
        reason: 'saved pickup state must win over the level default',
      );
    });

    test('an older save gains zombies added by the current level', () {
      final world = createGameWorld();
      world.entities[tutorialZombieId]!.component<HealthComponent>().current =
          0;
      final park = place(PlaceId.mallNorthStreet);
      final addedIds = <String>{
        for (final entity in world.entities.values)
          if (entity.id.startsWith(mallGroundZombiePrefix) ||
              entity.id.startsWith(stationUnderpassZombiePrefix) ||
              (entity.kind == EntityKind.carabiniere &&
                  park.bounds.contains(
                    entity.component<PositionComponent>().position,
                  )))
            entity.id,
      };
      expect(addedIds, hasLength(5));
      final oldSave = throughStorage(saveGameWorld(world));
      (oldSave['entities']! as List<Object?>).removeWhere(
        (encoded) =>
            addedIds.contains((encoded! as Map<String, Object?>)['id']),
      );

      final restored = restoreGameWorld(oldSave);

      for (final id in addedIds) {
        expect(restored.entities[id], isNotNull, reason: id);
        expect(restored.entities[id]!.isAlive, isTrue, reason: id);
      }
      expect(
        restored.entities[tutorialZombieId]!.isAlive,
        isFalse,
        reason: 'saved entity state must win over the level default',
      );
    });

    test('saving at the new camp behind the mall, after the first one, '
        'carries everything through both', () {
      GridPoint campIn(WorldState world, PlaceId id) =>
          world.campfires.firstWhere(place(id).bounds.contains);

      Map<String, Object?> rest(WorldState world, GridPoint camp) {
        world.player.component<PositionComponent>()
          ..position = camp.step(Direction.west)
          ..facing = Direction.east;
        final events = const TurnScheduler().advance(
          world,
          const InteractAction(),
        );
        expect(events.whereType<CampfireUsedEvent>().single.at, camp);
        return throughStorage(saveGameWorld(world));
      }

      final world = createGameWorld();
      final first = campIn(world, PlaceId.northDistrict);
      final second = campIn(world, PlaceId.mallNorthStreet);
      expect(campfireNames[first], 'Dietro la caserma');
      expect(
        campfireNames[second],
        'Zona nord',
        reason: 'the two camps are told apart in the save slots',
      );

      // Rest at the first camp with a zombie down and some rounds spent.
      final zombie = world.entities.values.firstWhere(
        (entity) => entity.kind != EntityKind.player,
      );
      zombie.component<HealthComponent>().current = 0;
      world.player.component<AmmoComponent>().loaded = 3;
      final loaded = restoreGameWorld(rest(world, first));
      expect(loaded.entities[zombie.id]!.isAlive, isFalse);
      expect(
        loaded.player.component<PositionComponent>().position,
        first.step(Direction.west),
      );

      // Then rest at the new one, and load that save in turn.
      final again = restoreGameWorld(rest(loaded, second));
      expect(again.campfires, contains(second));
      expect(
        again.entities[zombie.id]!.isAlive,
        isFalse,
        reason: 'what the first save held survives the second',
      );
      expect(again.player.component<AmmoComponent>().loaded, 3);
      expect(
        again.player.component<PositionComponent>().position,
        second.step(Direction.west),
        reason: 'Mario is left sitting at the camp he saved at',
      );
    });
  });
}
