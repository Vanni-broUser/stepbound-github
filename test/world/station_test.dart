import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('station', () {
    final station = place(PlaceId.station);
    final underpass = place(PlaceId.stationUnderpass);
    final farSide = place(PlaceId.stationFarSide);

    /// Everywhere reachable from [start] without leaving its place.
    Map<GridPoint, int> from(WorldState world, GridPoint start, Place place) =>
        world.map.floodFillDistances(
          start,
          maxDistance: place.width * place.height,
        );

    GridPoint travel(WorldState world, GridPoint threshold, Direction facing) {
      world.player.component<PositionComponent>().position = threshold.step(
        facing.opposite,
      );
      final events = const TurnScheduler().advance(world, MoveAction(facing));
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      return world.player.component<PositionComponent>().position;
    }

    test('the two doorways land in two corners of the hall with no way '
        'between them', () {
      final world = createGameWorld();
      final west = world.portals[stationWestDoor.first]!.to;
      final east = world.portals[stationEastDoor.first]!.to;
      expect(station.bounds.contains(west), isTrue);
      expect(station.bounds.contains(east), isTrue);

      final fromWest = from(world, west, station);
      expect(
        fromWest.containsKey(east),
        isFalse,
        reason: 'the fall between them closes the hall',
      );
      expect(
        from(world, east, station).containsKey(west),
        isFalse,
        reason: 'and closes it from the other side too',
      );
      for (final tile in fromWest.keys) {
        expect(
          station.bounds.contains(tile),
          isTrue,
          reason: 'nothing walkable leaves the station',
        );
      }
    });

    test('the west doorway reaches the platform, the train shuts it, and '
        'the two rounds are at the dead end', () {
      final world = createGameWorld();
      final reached = from(
        world,
        world.portals[stationWestDoor.first]!.to,
        station,
      );
      expect(
        station.tilesOf('-').where(reached.containsKey),
        isEmpty,
        reason: 'the burning car shuts the platform off from the tracks',
      );

      final backpack = world.pickups[stationBackpackId]!;
      expect(backpack.ammo, stationBackpackAmmo);
      expect(
        reached.containsKey(backpack.position.step(Direction.west)),
        isTrue,
        reason: 'it can be reached, and taken from the tile beside it',
      );

      // Nothing east of the hijacked train is walked to: its coach closes
      // the far track, the car that turned over the near one, the platform
      // and the hall down to the front wall.
      final wrecks = <GridPoint>[
        ...station.tilesOf('m'),
        ...station.tilesOf('V'),
        ...station.tilesOf('M'),
      ];
      final wreckLeft = wrecks
          .map((tile) => tile.x)
          .reduce((a, b) => a < b ? a : b);
      for (final tile in reached.keys) {
        expect(
          tile.x,
          lessThan(wreckLeft),
          reason: 'the train is as far east as the west side goes',
        );
      }
      final overturned = station.tilesOf('V');
      expect(
        overturned.map((tile) => tile.y).reduce((a, b) => a > b ? a : b),
        station.tilesOf('E').first.y - 1,
        reason: 'the overturned car reaches the front wall',
      );
      expect(
        overturned.map((tile) => tile.y).reduce((a, b) => a < b ? a : b),
        station
                .tilesOf('m')
                .map((tile) => tile.y)
                .reduce((a, b) => a > b ? a : b) +
            1,
        reason: 'it hangs off the end of the coach still on the rails',
      );
      for (final wreck in wrecks) {
        expect(world.map.tileAt(wreck).isWalkable, isFalse);
        expect(
          world.map.tileAt(wreck).blocksSight,
          isTrue,
          reason: 'the train is a wall, not something to shoot over',
        );
      }
      expect(
        station.indoor,
        isFalse,
        reason: 'the roof is gone: no darkness is drawn over the hall',
      );
    });

    test('the only way onto the tracks is the gap on fire by the burning '
        'car, and looking at it is all Mario can do', () {
      final world = createGameWorld();
      final platform = from(
        world,
        world.portals[stationWestDoor.first]!.to,
        station,
      );
      final fire = station.tilesOf('?');
      for (final tile in fire) {
        expect(world.map.tileAt(tile).kind, TileKind.fire);
      }
      // Put the fire out, and the tracks are reached through it alone.
      for (final tile in fire) {
        world.map.setTile(tile, const Tile(TileKind.floor));
      }
      final doused = from(
        world,
        world.portals[stationWestDoor.first]!.to,
        station,
      );
      expect(station.tilesOf('-').where(doused.containsKey), isNotEmpty);
      for (final tile in station.tilesOf('H')) {
        expect(world.map.tileAt(tile).blocksSight, isTrue);
      }

      expect(world.lookouts, contains(stationTrackFireTile));
      final stand = stationTrackFireTile.step(Direction.south);
      expect(platform.containsKey(stand), isTrue);
      final fresh = createGameWorld();
      fresh.player.component<PositionComponent>()
        ..position = stand
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        fresh,
        const InteractAction(),
      );
      expect(
        events.whereType<LookedOutEvent>().single.at,
        stationTrackFireTile,
      );
      expect(
        stationWreckFireSpots.every(
          (spot) => station.tilesOf('H').contains(spot.tile),
        ),
        isTrue,
        reason: 'the flames are on the car',
      );
      expect(outdoorFireSpots, containsAll(stationWreckFireSpots));
    });

    test('the rooms are walled at the sides from top to bottom, and the '
        'tracks run on past them', () {
      /// The rows of [room] with a side wall at both ends, and those with
      /// track in them.
      bool walled(String row) => row.trim().startsWith('|');
      bool track(String row) => row.contains(RegExp('[-,]'));
      for (final room in <Place>[station, underpass, farSide]) {
        final rows = room.rows;
        final sides = <int>[
          for (var y = 0; y < rows.length; y++)
            if (walled(rows[y].replaceAll(RegExp('[x_]'), ' '))) y,
        ];
        expect(sides, isNotEmpty, reason: '${room.id}');
        for (var y = sides.first; y <= sides.last; y++) {
          final row = rows[y];
          final west = row.indexOf('|');
          final east = row.lastIndexOf('|');
          expect(west, isNot(east), reason: '${room.id} row $y');
          expect(
            row.substring(0, west).replaceAll(RegExp('[x_]'), ''),
            isEmpty,
            reason: '${room.id} row $y: nothing outside the west wall',
          );
          expect(
            row.substring(east + 1).replaceAll(RegExp('[x_]'), ''),
            isEmpty,
            reason: '${room.id} row $y: nothing outside the east wall',
          );
        }
        for (final row in rows.where(track)) {
          expect(row, isNot(contains('|')), reason: '${room.id}: $row');
        }
      }
      // In the hall the tracks, and the train on them, run on past the
      // platform at both ends, off the edges of the map.
      final platform = station.rows.firstWhere((row) => row.contains('='));
      final tracks = station.rows.where(track).toList();
      expect(tracks, isNotEmpty);
      for (final row in station.rows.where(
        (row) => row.contains(RegExp('[HCmM]')),
      )) {
        expect(row[0], isNot('x'), reason: row);
        expect(row[row.length - 1], isNot('x'), reason: row);
      }
      expect(platform.indexOf('|'), greaterThan(0));
      expect(platform.lastIndexOf('|'), lessThan(platform.length - 1));
    });

    test('no wanderer waits right in front of a doorway', () {
      final world = createGameWorld();
      for (final door in <GridPoint>[
        world.portals[stationWestDoor.first]!.to,
        world.portals[stationEastDoor.first]!.to,
      ]) {
        for (final zombie in station.tilesOf('Z')) {
          expect(
            (zombie.x - door.x).abs() + (zombie.y - door.y).abs(),
            greaterThan(4),
          );
        }
      }
    });

    test('the east doorway reaches the stairs, and the underpass comes up '
        'on the far platform', () {
      final world = createGameWorld();
      final reached = from(
        world,
        world.portals[stationEastDoor.first]!.to,
        station,
      );
      final down = stationHallStairs;
      expect(down, hasLength(4), reason: 'two cells wide, two deep');
      expect(
        down.every(reached.containsKey),
        isTrue,
        reason: "the flight down is on the far doorway's side of the fall",
      );
      final head = down.first;
      final foot = stationHallStairsFoot;
      expect(foot, <GridPoint>[
        head.step(Direction.south),
        head.step(Direction.east).step(Direction.south),
      ]);
      for (final step in foot) {
        final below = step.step(Direction.south);
        expect(reached.containsKey(below), isTrue, reason: 'floor below it');
        expect(
          world.canStep(below, step),
          isFalse,
          reason: 'the flight is not got onto from below, as on the roofs',
        );
      }

      final door = station.doorRow('O').first;
      final corner = door
          .step(Direction.north)
          .step(Direction.north)
          .step(Direction.north)
          .step(Direction.north);
      expect(
        station.tilesOf('p').toSet(),
        <GridPoint>{
          for (var y = corner.y; y < door.y; y++) GridPoint(door.x, y),
          for (var x = corner.x; x <= head.x; x++) GridPoint(x, corner.y),
        },
        reason: 'the yellow line runs from the doorway to the head',
      );

      // Got onto only from the head, down it, and nowhere from the sides.
      for (final step in down) {
        for (final side in <Direction>[Direction.west, Direction.east]) {
          final beside = step.step(side);
          if (!down.contains(beside)) {
            expect(world.canStep(beside, step), isFalse, reason: '$step');
          }
        }
      }
      world.player.component<PositionComponent>().position = head.step(
        Direction.north,
      );
      const TurnScheduler().advance(world, const MoveAction(Direction.south));
      expect(
        world.player.component<PositionComponent>().position,
        head,
        reason: 'onto the head first, then down',
      );
      final corridor = travel(world, foot.first, Direction.south);
      expect(underpass.bounds.contains(corridor), isTrue);
      expect(
        underpass.height,
        lessThan(station.height ~/ 2),
        reason: 'a thin corridor, not a room',
      );

      final up = underpass.doorRow('U');
      final onward = from(world, corridor, underpass);
      expect(
        up.every(onward.containsKey),
        isTrue,
        reason: 'the corridor runs from one flight straight to the other',
      );

      final landing = travel(world, up.first, Direction.north);
      expect(landing, stationFarStairsFoot.first.step(Direction.north));
      expect(stationFarStairs, hasLength(4), reason: 'two cells, two deep');
      const TurnScheduler().advance(world, const MoveAction(Direction.north));
      expect(
        stationPlatform.contains(
          world.player.component<PositionComponent>().position,
        ),
        isTrue,
        reason: 'you come up onto the platform Luigi is waiting on',
      );

      final hall = travel(world, underpass.doorRow('D').first, Direction.north);
      expect(hall, foot.first.step(Direction.north));
      expect(
        world.player.component<PositionComponent>().facing,
        Direction.north,
        reason: 'back up onto the step above the last, facing up the flight',
      );
    });

    test('the east hall opens onto its platform through a four-cell gap, '
        'with only a little rubble left', () {
      final world = createGameWorld();
      final reached = from(
        world,
        world.portals[stationEastDoor.first]!.to,
        station,
      );
      final wreckRight = station.tilesOf('V').first.x + 3;
      final eastPlatform = station
          .tilesOf('=')
          .where((tile) => tile.x >= wreckRight);
      expect(eastPlatform.where(reached.containsKey), isNotEmpty);
      final backWall = station.rows.indexWhere(
        (row) => row.contains('WWWW....WWWW'),
      );
      expect(
        station
            .tilesOf('#')
            .where(
              (tile) =>
                  tile.x >= wreckRight && tile.y < station.origin.y + backWall,
            ),
        hasLength(3),
      );

      expect(backWall, isNonNegative);
      final localWreckRight = wreckRight - station.origin.x;
      expect(
        station.rows[backWall].substring(localWreckRight, localWreckRight + 12),
        'WWWW....WWWW',
      );
    });

    test('the far platform is one clear walk in front of the whole train', () {
      final world = createGameWorld();
      final reached = from(world, farSide.doorRow('D').first, farSide);
      final train = farSide.tilesOf('M');
      expect(train, isNotEmpty);
      for (final tile in train) {
        expect(world.map.tileAt(tile).isWalkable, isFalse);
        expect(
          stationPlatform.contains(tile),
          isFalse,
          reason: 'the train stands on the rails, not on the platform',
        );
      }
      // Every walkable tile of the platform is both reachable and inside
      // the trigger, so there is no slipping past Luigi.
      for (var y = stationPlatform.top; y <= stationPlatform.bottom; y++) {
        for (var x = stationPlatform.left; x <= stationPlatform.right; x++) {
          final tile = GridPoint(x, y);
          if (!world.map.tileAt(tile).isWalkable) {
            continue;
          }
          expect(reached.containsKey(tile), isTrue, reason: '$tile');
        }
      }
    });

    test('the whole railcar backs onto the wall and fills the map', () {
      final trainTop = stationFarSideRows.indexWhere(
        (row) => row.contains('M'),
      );
      expect(trainTop, 3, reason: 'the wall ends immediately above it');
      expect(
        stationFarSideRows[trainTop - 1].substring(1, 35).split(''),
        everyElement(isIn(<String>['W', 'l', 'r'])),
      );
      for (var y = trainTop; y < trainTop + 3; y++) {
        expect(
          stationFarSideRows[y].substring(1, 35).split(''),
          everyElement(isIn(<String>['M', 'P'])),
          reason: 'the train reaches both inner edges on row $y',
        );
      }
      expect(
        stationFarSideRows[trainTop + 2].indexOf('P'),
        6,
        reason: 'the extended train moves the door two cells west',
      );
    });

    test('the passenger door is closed by default and leads through two '
        'coaches to the locomotive when opened', () {
      final world = createGameWorld();
      final train = place(PlaceId.trainInterior);
      expect(
        world.map.tileAt(stationTrainDoorTile).isWalkable,
        isFalse,
        reason: 'without Luigi the train remains locked',
      );
      expect(world.portals, contains(stationTrainDoorTile));

      world.map.setTile(stationTrainDoorTile, const Tile(TileKind.floor));
      final inside = travel(world, stationTrainDoorTile, Direction.north);
      expect(train.bounds.contains(inside), isTrue);
      expect(inside, trainExitTile.step(Direction.north));

      final reached = from(world, inside, train);
      expect(
        reached.containsKey(trainMapStandTile),
        isTrue,
        reason: 'the clear gangways join both coaches to the locomotive',
      );
      expect(trainMapTiles, hasLength(12), reason: 'a table four by three');
      for (final map in trainMapTiles) {
        expect(world.map.tileAt(map).isWalkable, isFalse);
        expect(world.travelMaps, contains(map));
      }
      expect(trainMapTiles, contains(trainMapPanelTile));
      expect(
        trainMapTiles.any(
          (map) => reached.containsKey(map.step(Direction.south)),
        ),
        isTrue,
        reason:
            'the table can be walked round, not only reached from the aisle',
      );

      final platform = travel(world, trainExitTile, Direction.south);
      expect(stationPlatform.contains(platform), isTrue);
    });

    test('the train is a room with every light on: no darkness in it', () {
      final train = place(PlaceId.trainInterior);
      expect(train.indoor, isTrue, reason: 'it still sounds like a room');
      expect(train.lit, isTrue);
      expect(
        gamePlaces.where((place) => place.lit).map((place) => place.id),
        unorderedEquals(<PlaceId>[
          PlaceId.trainInterior,
          PlaceId.duomoUpper,
          PlaceId.terminiConcourse,
          PlaceId.palazzoGroundFloor,
          PlaceId.romePalazzoGround,
        ]),
        reason:
            'every other room stays in the dark but the upper floor of '
            'the Duomo, where the community lives, the concourse of '
            'Termini, under its glass, and the entrance hall of the '
            'palazzo past the airliner and of the one on Via Marsala',
      );
    });

    test('behind the engine Luigi, the books, the cot and the ammunition '
        'crate can each be walked '
        'up to and looked at, apart from each other', () {
      final world = createGameWorld();
      final train = place(PlaceId.trainInterior);
      final reached = from(world, trainExitTile.step(Direction.north), train);
      expect(reached.containsKey(trainMapStandTile), isTrue);
      final things = <GridPoint>[
        trainLuigiTile,
        ...trainBookTiles,
        ...trainWardrobeTiles,
        ...trainCotTiles,
        ...trainAmmoTiles,
      ];
      expect(trainBookTiles, isNotEmpty);
      expect(trainAmmoTiles, isNotEmpty);
      expect(trainCotTiles, hasLength(3));
      for (final thing in things) {
        expect(world.map.tileAt(thing).isWalkable, isFalse, reason: '$thing');
        expect(world.lookouts, contains(thing));
        expect(
          Direction.values.any((side) => reached.containsKey(thing.step(side))),
          isTrue,
          reason: '$thing can be stood next to',
        );
      }
      // Mario above the aisle and Luigi below it, both at the back, behind
      // the map table.
      final aisle = trainExitTile.y - 6;
      final divider = trainMapTiles.map((tile) => tile.x).reduce(math.min);
      expect(trainLuigiTile.x, lessThan(divider));
      expect(trainLuigiTile.y, greaterThan(aisle));
      for (final tile in <GridPoint>[
        ...trainBookTiles,
        ...trainWardrobeTiles,
        ...trainCotTiles,
        ...trainAmmoTiles,
      ]) {
        expect(tile.x, lessThan(divider));
        expect(tile.y, lessThan(aisle));
      }
    });

    test("what can be looked at is the level's, not the save's: a game "
        'saved when only the middle of the desk opened the book reaches it '
        'from all of it', () {
      final ends = <GridPoint>{trainBookTiles.first, trainBookTiles.last};
      final saved = saveGameWorld(createGameWorld());
      saved['lookouts'] = <Object?>[
        for (final point
            in (saved['lookouts']! as List<Object?>)
                .cast<Map<String, Object?>>())
          if (!ends.contains(GridPoint.fromJson(point))) point,
      ];
      final restored = restoreGameWorld(saved);
      for (final desk in trainBookTiles) {
        expect(restored.lookouts, contains(desk));
      }
    });

    test('two wanderers wait in the booking hall and one in the church', () {
      final world = createGameWorld();
      final indoors = world.entities.values
          .where((entity) => entity.id.startsWith(indoorZombiePrefix))
          .toList();
      expect(indoors, hasLength(station.tilesOf('Z').length + 2));
      expect(
        indoors.every(
          (zombie) => zombie.component<HealthComponent>().current > 0,
        ),
        isTrue,
      );
      for (final zombie in indoors) {
        final at = zombie.component<PositionComponent>().position;
        expect(world.map.tileAt(at).isWalkable, isTrue);
        expect(
          station.bounds.contains(at) ||
              place(PlaceId.church).bounds.contains(at),
          isTrue,
        );
      }
    });

    test('two wanderers roam the station underpass', () {
      final world = createGameWorld();
      final zombies = world.entities.values
          .where((entity) => entity.id.startsWith(stationUnderpassZombiePrefix))
          .toList();
      expect(zombies, hasLength(2));
      for (final zombie in zombies) {
        expect(zombie.kind, EntityKind.wanderer);
        expect(
          underpass.bounds.contains(
            zombie.component<PositionComponent>().position,
          ),
          isTrue,
        );
      }
    });
  });
}
