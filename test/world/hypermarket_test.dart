import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('hypermarket', () {
    GridPoint walk(WorldState world, GridPoint from, Direction direction) {
      world.player.component<PositionComponent>().position = from;
      final events = const TurnScheduler().advance(
        world,
        MoveAction(direction),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      return world.player.component<PositionComponent>().position;
    }

    GridPoint northTile(String glyph) {
      final y = northDistrictRows.indexWhere((row) => row.contains(glyph));
      return GridPoint(
        place(PlaceId.northDistrict).origin.x +
            northDistrictRows[y].indexOf(glyph),
        place(PlaceId.northDistrict).origin.y + y,
      );
    }

    test('its open entrance leads to the ground floor and back', () {
      final world = createGameWorld();
      final door = northTile('m');
      final inside = walk(world, door.step(Direction.south), Direction.north);
      final ground = gamePlaces.firstWhere(
        (region) => region.bounds == place(PlaceId.mallGround).bounds,
      );
      expect(ground.indoor, isTrue);
      expect(ground.lights, isNotEmpty);
      expect(place(PlaceId.mallGround).bounds.contains(inside), isTrue);
      final out = walk(world, inside, Direction.south);
      expect(out, door.step(Direction.south));
    });

    test('only the electronics sign flickers while optics, shoes and bar '
        'stay dark', () {
      final ground = place(PlaceId.mallGround);
      GridPoint absolute(GridPoint local) =>
          GridPoint(ground.origin.x + local.x, ground.origin.y + local.y);

      const electronics = GridPoint(6, 15);
      const unlitSigns = <GridPoint>[
        GridPoint(9, 1), // OTTICA
        GridPoint(12, 15), // SCARPE
        GridPoint(27, 15), // BAR
      ];

      final electronicsLight = ground.lights.singleWhere(
        (light) => light.tile == absolute(electronics),
      );
      expect(electronicsLight.flickers, isTrue);
      for (final sign in unlitSigns) {
        expect(
          ground.lights.map((light) => light.tile),
          isNot(contains(absolute(sign))),
        );
      }
    });

    test('the stairs join the two floors', () {
      final world = createGameWorld();
      final lowerStep = mallGroundRows.lastIndexWhere(
        (row) => row.contains('U'),
      );
      final up = GridPoint(
        place(PlaceId.mallGround).origin.x +
            mallGroundRows[lowerStep].indexOf('U'),
        place(PlaceId.mallGround).origin.y + lowerStep,
      );
      final upstairs = walk(world, up, Direction.north);
      expect(
        upstairs.x,
        greaterThanOrEqualTo(place(PlaceId.mallFirst).origin.x),
      );
      expect(
        mallFirstRows[upstairs.y -
            place(PlaceId.mallFirst).origin.y][upstairs.x -
            place(PlaceId.mallFirst).origin.x],
        'D',
      );
      final downstairs = walk(world, upstairs, Direction.north);
      expect(downstairs, up);
    });

    void expectWalkableStraightPath(WorldState world, List<GridPoint> path) {
      var from = path.first;
      for (final to in path.skip(1)) {
        expect(
          from.x == to.x || from.y == to.y,
          isTrue,
          reason: 'not a straight line: $from to $to',
        );
        final dx = (to.x - from.x).sign;
        final dy = (to.y - from.y).sign;
        var tile = from;
        while (tile != to) {
          expect(
            world.map.tileAt(tile).isWalkable,
            isTrue,
            reason: 'tile $tile blocks the way',
          );
          tile = GridPoint(tile.x + dx, tile.y + dy);
        }
        expect(world.map.tileAt(to).isWalkable, isTrue);
        from = to;
      }
    }

    test('Luigi walks a clear path from his shop down to the stairs', () {
      expectWalkableStraightPath(createGameWorld(), luigiExitPath);
    });

    test('the hall and upper shops join on the west, with central stairs '
        'below and the fire exit in the second area', () {
      final world = createGameWorld();
      final ground = place(PlaceId.mallGround);
      final entrance = ground.doorRow('E').first;
      final stairs = ground.doorRow('U');
      // The hall is the lower area: its entrance is south of its stairs,
      // and the fire exit is north of them, in the area above.
      expect(entrance.y, greaterThan(stairs.first.y));
      expect(mallExitTile.y, lessThan(stairs.first.y));
      expect(
        <int>[for (final tile in stairs) tile.x - ground.origin.x],
        <int>[for (final tile in ground.doorRow('E')) tile.x - ground.origin.x],
        reason: 'the stairs align exactly with the entrance below',
      );
      // The only way between the two areas: two cells wide, on the west.
      final passage = <List<GridPoint>>[
        for (var y = 0; y < ground.height; y++)
          if (ground.walkableRow(y).length == 2) ground.walkableRow(y),
      ];
      expect(passage, hasLength(greaterThanOrEqualTo(3)));
      for (final row in passage) {
        expect(row.last.x - row.first.x, 1, reason: 'two cells side by side');
        expect(
          row.first.x - ground.origin.x,
          lessThan(ground.width ~/ 4),
          reason: 'down the west side',
        );
      }
      final west = passage.first.first.x;
      expect(
        stairs.first.x - west,
        greaterThan(ground.width ~/ 3),
        reason: 'the long way round, not a nook',
      );
      // Down the passage into the hall, and back up and east to the exit.
      expectWalkableStraightPath(world, <GridPoint>[
        GridPoint(west, passage.first.first.y - 1),
        GridPoint(west, stairs.first.y + 2),
      ]);
      expectWalkableStraightPath(world, <GridPoint>[
        GridPoint(west, mallExitTile.y + 1),
        GridPoint(mallExitTile.x, mallExitTile.y + 1),
        mallExitTile,
      ]);
      final beyond = walk(
        world,
        mallExitTile.step(Direction.south),
        Direction.north,
      );
      expect(place(PlaceId.mallNorthStreet).bounds.contains(beyond), isTrue);
      // It lands on the door itself, set in the hypermarket's rear wall and
      // walled in on every other side, not out on the car park's tarmac.
      expect(beyond, mallNorthStreetEntry);
      for (final side in <Direction>[
        Direction.east,
        Direction.west,
        Direction.south,
      ]) {
        expect(
          world.map.tileAt(mallNorthStreetEntry.step(side)).isWalkable,
          isFalse,
          reason: 'the door stands in the wall, $side of it does not',
        );
      }
      // From the doorway, pushing on into the wall goes back inside; so
      // does stepping out and back onto the door.
      final back = walk(world, beyond, Direction.south);
      expect(back, mallExitTile.step(Direction.south));
      expect(walk(world, back, Direction.north), mallNorthStreetEntry);
      const TurnScheduler().advance(world, const MoveAction(Direction.north));
      final tarmac = world.player.component<PositionComponent>().position;
      expect(tarmac, mallNorthStreetEntry.step(Direction.north));
      expect(walk(world, tarmac, Direction.south), back);
    });

    test('two wanderers wait by the north exit on the ground floor', () {
      final world = createGameWorld();
      final ground = place(PlaceId.mallGround);
      final zombies = world.entities.values
          .where((entity) => entity.id.startsWith(mallGroundZombiePrefix))
          .toList();
      expect(zombies, hasLength(2));
      for (final zombie in zombies) {
        expect(zombie.kind, EntityKind.wanderer);
        final position = zombie.component<PositionComponent>().position;
        expect(ground.bounds.contains(position), isTrue);
        expect(
          position.manhattanDistanceTo(mallExitTile),
          lessThanOrEqualTo(4),
        );
      }
    });

    test('the panel beyond the gate lifts the shutter in front of Luigi', () {
      final world = createGameWorld();
      final bars = luigiBars;
      final luigi = luigiTile;
      expect(luigi.y, lessThan(bars.top));
      expect(bars.left <= luigi.x && luigi.x <= bars.right, isTrue);
      final shutter = GridPoint(bars.left, bars.top);
      expect(world.map.tileAt(shutter).isWalkable, isFalse);
      expect(world.map.tileAt(shutter).blocksSight, isFalse);

      final panel = mallPanelTile;
      world.player.component<PositionComponent>()
        ..position = panel.step(Direction.south)
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );
      expect(events.whereType<ControlUsedEvent>().single.opened, bars);
      expect(world.map.tileAt(shutter).isWalkable, isTrue);
      expect(world.controls, isEmpty);
      // The horde comes between the shutter and the panel.
      for (final spawn in mallHordeSpawns) {
        expect(spawn.x, greaterThan(bars.right));
        expect(spawn.x, lessThanOrEqualTo(panel.x + 2));
      }
    });

    test('a backpack with two rounds waits at the far corner of the car '
        'park', () {
      final backpack = createGameWorld().pickups[parkingBackpackId]!;
      expect(backpack.ammo, 2);
      expect(backpack.active, isTrue);
      // On the sidewalk at the car park's west edge: nothing of the car
      // park west of it, the bays straight east.
      final row = northDistrictRows[backpack.position.y];
      final x = backpack.position.x - place(PlaceId.northDistrict).origin.x;
      expect(row.substring(0, x), isNot(contains('L')));
      expect(row[x + 1], 'L');
    });
  });
}
