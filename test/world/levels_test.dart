import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('the whole world survives a save and a load', () {
    final world = createGameWorld();
    world.pickups[ammoBackpackId]!
      ..active = false
      ..collected = true;
    world.player.component<AmmoComponent>().loaded = 2;
    final restored = WorldState.fromJson(
      jsonDecode(jsonEncode(world.toJson())) as Map<String, Object?>,
    );
    expect(restored.toJson(), world.toJson());
    expect(restored.campfires, world.campfires);
    expect(restored.portals.length, world.portals.length);
    expect(restored.pickups[ammoBackpackId]!.collected, isTrue);
  });

  test('the train door opens onto the station of the level it stands in, '
      'and Termini leads only back aboard and up to the overpass', () {
    final world = createGameWorld();
    expect(
      world.portals[trainExitTile]!.to,
      stationTrainDoorTile.step(Direction.south),
      reason: 'a new game starts with the train in Molfetta',
    );
    parkTrain(world, LevelId.rome);
    expect(
      world.portals[trainExitTile]!.to,
      terminiTrainDoorTile.step(Direction.south),
    );
    expect(world.portals[terminiTrainDoorTile]!.to, isNot(trainExitTile));
    expect(
      placeAt(world.portals[terminiTrainDoorTile]!.to)!.id,
      PlaceId.trainInterior,
    );
    expect(world.map.tileAt(terminiTrainDoorTile).isWalkable, isTrue);
    final termini = place(PlaceId.romeTermini);
    final overpass = place(PlaceId.terminiOverpass);
    for (final portal in world.portals.entries) {
      if (termini.bounds.contains(portal.key)) {
        expect(<GridPoint>[
          terminiTrainDoorTile,
          ...terminiStairsTiles,
        ], contains(portal.key));
      }
      if (termini.bounds.contains(portal.value.to)) {
        expect(
          portal.key == trainExitTile || overpass.bounds.contains(portal.key),
          isTrue,
        );
      }
    }
    parkTrain(world, LevelId.hometown);
    expect(
      world.portals[trainExitTile]!.to,
      stationTrainDoorTile.step(Direction.south),
    );
  });

  test('a level counts its own zombies, those its story raises, and its '
      'own fires', () {
    final hometown = levelZombieKinds(LevelId.hometown);
    final rome = levelZombieKinds(LevelId.rome);
    // Rome's wanderers, and the one sprinter on the piazza.
    expect(
      rome,
      hasLength(romeZombieSpots.values.expand((spots) => spots).length + 1),
    );
    final atStart = createGameWorld().entities.values
        .where((entity) => entity.kind != EntityKind.player)
        .length;
    expect(
      hometown,
      hasLength(
        atStart -
            rome.length +
            carabiniereSpawns.length +
            mallHordeSpawns.length +
            duomoCultistSpawns.length,
      ),
    );
    expect(hometown, contains(EntityKind.cultist));
    expect(levelCampfires(LevelId.hometown), hasLength(5));
    expect(levelCampfires(LevelId.rome), <String>{'Piazza dei Cinquecento'});
  });

  test('the wanderers of Termini stand on its platforms, and its stairs are '
      'walkable', () {
    final world = createGameWorld();
    final termini = place(PlaceId.romeTermini);
    final zombies = world.entities.values
        .where((entity) => entity.id.startsWith(terminiZombiePrefix))
        .toList();
    expect(zombies, hasLength(terminiZombieSpots.length));
    for (final zombie in zombies) {
      final at = zombie.component<PositionComponent>().position;
      expect(termini.bounds.contains(at), isTrue);
    }
    expect(terminiStairsTiles, isNotEmpty);
    for (final tile in terminiStairsTiles) {
      expect(world.map.tileAt(tile).isWalkable, isTrue);
    }
    // As on Molfetta's far platform, the train fills the track from edge
    // to edge: the only way on is the platform, never round the train.
    final door = terminiTrainDoorTile;
    for (var x = termini.bounds.left; x <= termini.bounds.right; x++) {
      for (var y = termini.bounds.top; y < door.y; y++) {
        expect(
          world.map.tileAt(GridPoint(x, y)).isWalkable,
          isFalse,
          reason: 'nothing to walk on north of the platform',
        );
      }
    }
    // Both of Rome's name boards are up.
    expect(termini.tilesOf('Q'), isNotEmpty);
    expect(termini.tilesOf('o'), isNotEmpty);
  });
}
