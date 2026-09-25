import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('the street behind the mall keeps the outdoor perspective', () {
    final width = mallNorthStreetRows.first.length;
    final facadeRows = mallNorthStreetRows
        .takeWhile((row) => !row.contains('-'))
        .where((row) => row.contains('H'));
    expect(facadeRows, isNotEmpty, reason: 'north-side palazzi face south');

    final exitRow = mallNorthStreetRows.indexWhere((row) => row.contains('j'));
    expect(
      mallNorthStreetRows.skip(exitRow).every((row) => !row.contains('H')),
      isTrue,
      reason: 'the southern building shows only its roof and exit',
    );

    final lastParkingColumn = mallNorthStreetRows
        .map((row) => row.lastIndexOf('L'))
        .reduce((left, right) => left > right ? left : right);
    expect(
      lastParkingColumn,
      lessThan(width - 10),
      reason: 'right-side palazzi narrow the car park',
    );
  });

  test('wrecks and road blocks close the block behind the mall, west', () {
    // East there is nothing to close: both streets run into the buildings.
    final roadRows = mallNorthStreetRows.where((row) => row.contains('-'));
    expect(
      roadRows.every((row) => outdoorLegend.obstacles.contains(row[1])),
      isTrue,
      reason:
          'wrecks on the four-lane road, concrete blocks on the shopping '
          'street, never a wall: the wrecks are nosed forward and back of '
          'one another, but each covers the second column from the edge',
    );
    // The second pile-up stands midway between the park's two south gates
    // and cuts the four-lane road, so the park joins its two halves.
    final railing = mallNorthStreetRows.lastIndexWhere(
      (row) => row.contains('<'),
    );
    final gates = <int>[
      for (var x = 0; x < mallNorthStreetRows[railing].length; x++)
        if (mallNorthStreetRows[railing][x] == '<') x,
    ];
    expect(gates, hasLength(2));
    final between = (gates.first + gates.last) ~/ 2;
    expect(
      mallNorthStreetRows
          .skip(railing + 1)
          .take(6)
          .every((row) => outdoorLegend.obstacles.contains(row[between])),
      isTrue,
      reason: 'the pile-up closes the road on the column between the gates',
    );
  });

  test('the block behind the mall walks as a circuit, never to the edge', () {
    final world = createTutorialWorld();
    final street = place(PlaceId.mallNorthStreet);
    final reached = world.map.floodFillDistances(
      mallNorthStreetEntry,
      maxDistance: street.width * street.height,
    );
    expect(reached.length, greaterThan(street.width), reason: 'sanity check');
    final gates = <GridPoint>[
      for (var y = 0; y < street.height; y++)
        for (var x = 0; x < street.width; x++)
          if (mallNorthStreetRows[y][x] == '<')
            GridPoint(street.origin.x + x, street.origin.y + y),
    ];
    expect(
      gates,
      hasLength(3),
      reason: 'one gate north of the park, two south',
    );
    final doors = <GridPoint>[...stationWestDoor, ...stationEastDoor];
    expect(doors, hasLength(4), reason: 'two doorways, two tiles wide each');
    for (final way in <GridPoint>[...gates, ...doors]) {
      expect(
        reached.containsKey(way),
        isTrue,
        reason: 'every gate and station doorway can be walked to',
      );
    }
    for (final tile in reached.keys) {
      expect(
        tile.x,
        inExclusiveRange(street.bounds.left + 1, street.bounds.right - 1),
        reason: 'nothing walkable touches the edge of the map',
      );
    }
  });

  test('the player starts unarmed with no bullets', () {
    final ammo = createTutorialWorld().player.component<AmmoComponent>();
    expect(ammo.hasGun, isFalse);
    expect(ammo.loaded, 0);
  });

  test('bullets pile up with no magazine to cap them', () {
    final ammo = createTutorialWorld().player.component<AmmoComponent>()
      ..add(4)
      ..add(5);
    expect(ammo.loaded, 9, reason: 'nothing is left in a reserve');
  });

  test('the crossroads opens north and east but not south', () {
    final map = createTutorialWorld().map;
    expect(map.tileAt(const GridPoint(16, 20)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(30, 36)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(16, 40)).isWalkable, isFalse);
  });

  test('the streets end against buildings, the north one at the barracks', () {
    final map = createTutorialWorld().map;
    expect(map.tileAt(const GridPoint(3, 36)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(40, 36)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(15, 6)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(16, 6)).isWalkable, isTrue);
  });

  test('no cultist zombie stands in the level: the mass raises them', () {
    final cultists = createTutorialWorld().entities.values.where(
      (entity) => entity.kind == EntityKind.cultist,
    );

    expect(cultists, isEmpty);
    expect(duomoCultistSpawns, hasLength(4), reason: 'four of them, later');
  });

  List<Entity> zombiesIn(WorldState world, Place region) => world
      .entities
      .values
      .where(
        (entity) =>
            entity.kind != EntityKind.player &&
            region.bounds.contains(
              entity.component<PositionComponent>().position,
            ),
      )
      .toList();

  test('the only zombie on the street waits east of the crossroads', () {
    final world = createTutorialWorld();
    final zombies = zombiesIn(world, place(PlaceId.street));
    expect(zombies, hasLength(1));
    expect(zombies.single.id, tutorialZombieId);
    final position = zombies.single.component<PositionComponent>().position;
    // The view is 24 tiles wide and starts clamped to the west end.
    expect(position.x, greaterThanOrEqualTo(24));
  });

  String northGlyph(GridPoint point) =>
      northDistrictRows[point.y -
          place(PlaceId.northDistrict).origin.y][point.x -
          place(PlaceId.northDistrict).origin.x];

  test('two zombies wander by the fountain in the north district square', () {
    final world = createTutorialWorld();
    final byFountain = zombiesIn(world, place(PlaceId.northDistrict)).where((
      zombie,
    ) {
      final position = zombie.component<PositionComponent>().position;
      return Direction.values.any(
        (direction) => northGlyph(position.step(direction)) == 'O',
      );
    });
    expect(byFountain, hasLength(2));
  });

  test('hordes of wanderers and carabinieri block the way to the '
      'hospital', () {
    final world = createTutorialWorld();
    // The square, in the north district's own tiles.
    final square = GridRect(
      place(PlaceId.northDistrict).origin.x + 38,
      place(PlaceId.northDistrict).origin.y + 30,
      place(PlaceId.northDistrict).origin.x + 58,
      place(PlaceId.northDistrict).origin.y + 42,
    );
    final hordes = zombiesIn(world, place(PlaceId.northDistrict)).where(
      (zombie) =>
          zombie.component<PositionComponent>().position.x < square.left,
    );
    expect(hordes.length, greaterThanOrEqualTo(30));
    expect(hordes.map((zombie) => zombie.kind).toSet(), <EntityKind>{
      EntityKind.wanderer,
      EntityKind.carabiniere,
    });
    final carabinieri = hordes.where(
      (zombie) => zombie.kind == EntityKind.carabiniere,
    );
    expect(carabinieri.length, inInclusiveRange(3, hordes.length ~/ 4));
    expect(
      carabinieri.map((zombie) => zombie.id).toSet().intersection(<String>{
        for (var i = 0; i < carabiniereSpawns.length; i++) 'carabiniere-$i',
      }),
      isEmpty,
      reason: 'the barracks spawns its own carabinieri later',
    );
    // None of them can see someone standing anywhere in the square.
    for (final zombie in hordes) {
      final position = zombie.component<PositionComponent>().position;
      final range = zombie.component<VisionComponent>().range;
      final dx = square.left - position.x;
      expect(dx, greaterThan(range), reason: '${zombie.id} at $position');
    }
    // The hospital has no door to go through.
    final hospital = world.portals.keys.where(
      (tile) =>
          place(PlaceId.northDistrict).bounds.contains(tile) &&
          northGlyph(tile) == 'G',
    );
    expect(hospital, isEmpty);
  });

  test('zombies are beyond the simulation radius of the other places', () {
    final world = createTutorialWorld();
    final spots = <GridPoint>[
      for (final entity in world.entities.values)
        if (entity.kind != EntityKind.player)
          entity.component<PositionComponent>().position,
      ...carabiniereSpawns,
      ...mallHordeSpawns,
    ];
    for (final spot in spots) {
      for (final region in tutorialPlaces) {
        final bounds = region.bounds;
        if (bounds.contains(spot)) {
          continue;
        }
        for (var y = bounds.top; y <= bounds.bottom; y++) {
          for (var x = bounds.left; x <= bounds.right; x++) {
            final tile = GridPoint(x, y);
            if (world.map.tileAt(tile).isWalkable) {
              expect(
                spot.manhattanDistanceTo(tile),
                greaterThan(40),
                reason: 'zombie at $spot, player at $tile',
              );
            }
          }
        }
      }
    }
  });

  test('backpacks: ammo on the street and by the accident, pistol in the '
      'barracks', () {
    final pickups = createTutorialWorld().pickups;
    expect(pickups[ammoBackpackId]!.active, isTrue);
    expect(pickups[ammoBackpackId]!.ammo, 2);
    expect(pickups[accidentBackpackId]!.active, isTrue);
    expect(pickups[accidentBackpackId]!.ammo, 4);
    final gun = pickups[gunBackpackId]!;
    expect(gun.gun, isTrue);
    expect(place(PlaceId.barracks).indoor, isTrue);
    expect(place(PlaceId.barracks).bounds.contains(gun.position), isTrue);
  });

  test('interacting with a backpack collects its content', () {
    final world = createTutorialWorld();
    final backpack = world.pickups[ammoBackpackId]!;
    world.player.component<PositionComponent>()
      ..position = backpack.position.step(Direction.south)
      ..facing = Direction.north;

    const MoveAction(Direction.north).resolve(world);
    expect(
      world.player.component<PositionComponent>().position,
      backpack.position.step(Direction.south),
      reason: 'a backpack blocks its tile',
    );

    final events = const TurnScheduler().advance(world, const InteractAction());
    final pickedUp = events.whereType<PickedUpEvent>().single;
    expect(pickedUp.ammo, 2);
    expect(backpack.active, isFalse);
    expect(backpack.collected, isTrue);
    final ammo = world.player.component<AmmoComponent>();
    expect(ammo.loaded, 2);
    expect(ammo.hasGun, isFalse);
  });

  test('without the pistol the player cannot shoot', () {
    final world = createTutorialWorld();
    world.player.component<AmmoComponent>().loaded = 2;
    final events = const TurnScheduler().advance(world, const ShootAction());
    expect(events.whereType<DryFiredEvent>(), hasLength(1));
    expect(world.player.component<AmmoComponent>().loaded, 2);
  });

  test('stepping into the crossroads alerts the zombie at once', () {
    final world = createTutorialWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      13,
      35,
    );
    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.east),
    );
    expect(events.whereType<AlertedEvent>().single.entityId, tutorialZombieId);
    expect(
      events.whereType<MovedEvent>().where(
        (event) => event.entityId == tutorialZombieId,
      ),
      hasLength(1),
      reason: 'it steps towards the player on the turn it notices them',
    );
  });

  group('doors', () {
    GridPoint walk(WorldState world, GridPoint from, Direction direction) {
      world.player.component<PositionComponent>().position = from;
      final events = const TurnScheduler().advance(
        world,
        MoveAction(direction),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      return world.player.component<PositionComponent>().position;
    }

    bool inside(GridPoint tile) =>
        place(PlaceId.barracks).bounds.contains(tile);

    test('the front door leads inside the barracks and back out', () {
      final world = createTutorialWorld();
      final inDoor = walk(world, const GridPoint(16, 7), Direction.north);
      expect(inside(inDoor), isTrue);
      final outDoor = walk(world, inDoor, Direction.south);
      expect(outDoor, const GridPoint(16, 7));
    });

    test('the back door opens on the street of the north district', () {
      final world = createTutorialWorld();
      final backDoor = world.portals.keys.firstWhere(
        (tile) =>
            inside(tile) && tile.y == place(PlaceId.barracks).origin.y + 2,
      );
      final out = walk(world, backDoor.step(Direction.south), Direction.north);
      expect(place(PlaceId.northDistrict).bounds.contains(out), isTrue);
      expect(world.map.tileAt(out).isWalkable, isTrue);
      final back = walk(world, out, Direction.south);
      expect(back, backDoor.step(Direction.south));
    });

    test('the south road of the square goes down to the harbour and back', () {
      final world = createTutorialWorld();
      final harbour = tutorialPlaces.firstWhere(
        (region) => region.name == harbourName,
      );
      expect(harbour.cardImage, harbourCardImage);
      // The centre line of the road, one step before its last row.
      final road = GridPoint(
        place(PlaceId.northDistrict).origin.x +
            northDistrictRows.last.indexOf('|'),
        place(PlaceId.northDistrict).origin.y + northDistrictRows.length - 2,
      );
      final down = walk(world, road, Direction.south);
      expect(harbour.bounds.contains(down), isTrue);
      expect(down.y, place(PlaceId.harbour).origin.y + 1);
      expect(
        world.player.component<PositionComponent>().facing,
        Direction.south,
      );
      final up = walk(world, down, Direction.north);
      expect(up, road);
    });
  });

  test('a sprinter prowls the middle of the car park, the backpack is '
      'further west', () {
    final world = createTutorialWorld();
    final sprinters = zombiesIn(
      world,
      place(PlaceId.northDistrict),
    ).where((zombie) => zombie.kind == EntityKind.sprinter);
    final sprinter = sprinters.single.component<PositionComponent>().position;
    final backpack = world.pickups[parkingBackpackId]!.position;
    final carPark =
        northDistrictRows[sprinter.y - place(PlaceId.northDistrict).origin.y];
    expect(carPark.contains('L'), isTrue);
    // Straight ahead of the road up from the square, so framing it with
    // Mario never swings the camera west to the backpack.
    final road =
        place(PlaceId.northDistrict).origin.x +
        northDistrictRows.last.indexOf('|');
    expect((sprinter.x - road).abs(), lessThanOrEqualTo(1));
    expect(road - backpack.x, greaterThanOrEqualTo(12));
  });

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
      final world = createTutorialWorld();
      final door = northTile('m');
      final inside = walk(world, door.step(Direction.south), Direction.north);
      final ground = tutorialPlaces.firstWhere(
        (region) => region.bounds == place(PlaceId.mallGround).bounds,
      );
      expect(ground.indoor, isTrue);
      expect(ground.lights, isNotEmpty);
      expect(place(PlaceId.mallGround).bounds.contains(inside), isTrue);
      final out = walk(world, inside, Direction.south);
      expect(out, door.step(Direction.south));
    });

    test('the stairs join the two floors', () {
      final world = createTutorialWorld();
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
      expectWalkableStraightPath(createTutorialWorld(), luigiExitPath);
    });

    test('the hall and upper shops join on the west, with central stairs '
        'below and the fire exit in the second area', () {
      final world = createTutorialWorld();
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
      final world = createTutorialWorld();
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
      final world = createTutorialWorld();
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
      final backpack = createTutorialWorld().pickups[parkingBackpackId]!;
      expect(backpack.ammo, 2);
      expect(backpack.active, isTrue);
      final row = northDistrictRows[backpack.position.y];
      expect(
        row[backpack.position.x - place(PlaceId.northDistrict).origin.x - 1],
        '=',
      );
    });
  });

  group('harbour', () {
    final harbour = place(PlaceId.harbour);
    GridPoint at(int x, int y) =>
        GridPoint(harbour.origin.x + x, harbour.origin.y + y);
    String glyph(int x, int y) => harbourRows[y][x];

    test('the promenade ends at the parapet over the sea, round the corner '
        'too, but for the two piers', () {
      final map = createTutorialWorld().map;
      final parapet = harbourRows.indexWhere((row) => row.startsWith('R'));
      final corner = harbourRows[parapet].lastIndexOf('R');
      for (var x = 0; x <= corner; x++) {
        if (glyph(x, parapet) == 'l') {
          continue; // the shipyard's slipway runs down through it
        }
        expect(map.tileAt(at(x, parapet)).isWalkable, isFalse);
        expect(map.tileAt(at(x, parapet)).blocksSight, isFalse);
      }
      var piers = 0;
      for (var y = parapet + 1; glyph(corner, y) != 'B'; y++) {
        if (glyph(corner, y) == 'l') {
          piers++;
          continue;
        }
        expect(glyph(corner, y), 'R', reason: 'row $y');
        expect(glyph(corner - 1, y), anyOf('~', 'b'), reason: 'row $y');
      }
      expect(piers, 4, reason: 'two piers, two planks wide');
    });

    test('an alley climbs north off the seafront road, then turns east to '
        'the Bar Arcobaleno, which you can walk into and out of', () {
      final world = createTutorialWorld();
      final door = harbourRows.indexWhere((row) => row.contains('h'));
      final doorX = harbourRows[door].indexOf('h');
      final road = harbourRows.indexWhere((row) => row.contains('-'));
      final alleyX = harbourRows[door].indexOf('P');
      expect(alleyX, lessThan(doorX));
      for (var y = door; y < road; y++) {
        expect(
          world.map.tileAt(at(alleyX, y)).isWalkable,
          isTrue,
          reason: 'the alley at row $y',
        );
      }
      world.player.component<PositionComponent>().position = at(
        doorX,
        door + 1,
      );
      var events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.north),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      final inside = world.player.component<PositionComponent>().position;
      final bar = place(PlaceId.barArcobaleno);
      expect(bar.indoor, isTrue);
      expect(bar.tilesOf('*'), hasLength(greaterThanOrEqualTo(4)));
      expect(
        bar.lights.where((light) => light.tile.y == bar.origin.y + 3),
        hasLength(3),
        reason: 'three lamps wash the sign across the back wall',
      );
      expect(
        bar.lights.any(
          (light) =>
              (light.tile.x - barLockedDoorTile.x).abs() <= 2 &&
              (light.tile.y - barLockedDoorTile.y).abs() <= 1,
        ),
        isTrue,
        reason: 'the locked door has a lamp beside it',
      );
      expect(world.map.tileAt(barLockedDoorTile).isWalkable, isFalse);
      expect(bar.bounds.contains(inside), isTrue);
      events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.south),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      expect(
        world.player.component<PositionComponent>().position,
        at(doorX, door + 1),
      );
    });

    test('a rowboat moored at the second pier holds four rounds', () {
      final world = createTutorialWorld();
      final boat = world.pickups[boatBackpackId]!;
      expect(boat.ammo, 4);
      expect(boat.gun, isFalse);
      expect(harbour.bounds.contains(boat.position), isTrue);
      final deck = <GridPoint>[
        for (final direction in Direction.values) boat.position.step(direction),
      ].where((tile) => world.map.tileAt(tile).isWalkable).toList();
      expect(deck, isNotEmpty, reason: 'you can step aboard next to it');
      final pier = harbourRows.lastIndexWhere((row) => row.contains('l'));
      final onPier = at(harbourRows[pier].indexOf('l'), pier);
      expect(world.map.tileAt(onPier).isWalkable, isTrue);
      expect(
        world.map.tileAt(onPier.step(Direction.south)).isWalkable,
        isTrue,
        reason: 'the boat is alongside the end of the pier',
      );
    });

    test('the seafront road runs on west past the Duomo until the shipyard '
        'closes it, the way in round the side', () {
      final duomo = harbourRows.indexWhere((row) => row.contains('W'));
      final west = harbourRows[duomo].indexOf('W');
      final road = harbourRows.indexWhere((row) => row.contains('-'));
      // The yard is walled all round; the one standing across the road is
      // its east wall, the last before the tarmac starts.
      final wall = harbourRows[road].lastIndexOf('%');
      expect(
        wall,
        lessThan(west),
        reason: 'the road goes further west than the church itself',
      );
      final world = createTutorialWorld();
      for (var x = wall + 1; x < west; x++) {
        expect(
          world.map.tileAt(at(x, road)).isWalkable,
          isTrue,
          reason: 'the seafront road at column $x',
        );
      }
      expect(
        world.map.tileAt(at(wall, road)).isWalkable,
        isFalse,
        reason: 'the yard wall stands across the road',
      );

      // The way in is off the promenade, past the end of the wall: from
      // there the yard, its hull and its crane are reachable.
      final promenade = harbourRows.indexWhere(
        (row) => row.startsWith('R') && row.contains('l'),
      );
      final gate = GridPoint(wall, promenade - 1);
      expect(world.map.tileAt(at(gate.x, gate.y)).isWalkable, isTrue);
      expect(
        world.map.tileAt(at(gate.x - 1, gate.y)).isWalkable,
        isTrue,
        reason: 'the yard itself',
      );
      expect(harbourRows.any((row) => row.contains('*')), isTrue);
      expect(harbourRows.any((row) => row.contains('i')), isTrue);
    });

    test('the alleys of the old town climb off the seafront road and cross '
        'one another, with the church and the fountain among them', () {
      final world = createTutorialWorld();
      final duomoRow = harbourRows.indexWhere((row) => row.contains('W'));
      final duomoX = harbourRows[duomoRow].indexOf('W');
      List<GridPoint> tilesOf(String wanted) => <GridPoint>[
        for (var y = 0; y < harbourRows.length; y++)
          for (var x = 0; x < harbourRows[y].length; x++)
            if (glyph(x, y) == wanted) GridPoint(x, y),
      ];

      // Alleys west of the Duomo, counted where each one opens onto the
      // sidewalk of the seafront road.
      var mouths = 0;
      for (var y = 0; y < harbourRows.length - 1; y++) {
        for (var x = 1; x < duomoX; x++) {
          if (glyph(x, y) == 'P' &&
              glyph(x, y + 1) == '=' &&
              glyph(x - 1, y) != 'P') {
            mouths++;
          }
        }
      }
      expect(mouths, greaterThanOrEqualTo(3), reason: 'alleys off the road');

      // The small church stands at the far end of them from the Duomo, and
      // takes up less of the map than it does.
      final church = tilesOf('#');
      expect(church, isNotEmpty);
      expect(
        church.map((tile) => tile.x).reduce((a, b) => a > b ? a : b),
        lessThan(duomoX),
        reason: 'west of the Duomo',
      );
      expect(
        church.length,
        lessThan(tilesOf('W').length),
        reason: 'smaller than the Duomo',
      );

      // The fountain, two cells by two, with room to walk in front of it.
      final fountain = tilesOf('!');
      expect(fountain, hasLength(4));
      final top = fountain
          .map((tile) => tile.y)
          .reduce((a, b) => a < b ? a : b);
      for (final tile in fountain) {
        expect(world.map.tileAt(at(tile.x, tile.y)).isWalkable, isFalse);
        expect(
          world.map.tileAt(at(tile.x, top - 1)).isWalkable,
          isTrue,
          reason: 'room to pass in front of it',
        );
      }
      expect(tilesOf('&'), isNotEmpty, reason: 'the flower beds with it');
    });

    test('the Duomo stands back from the road: a two-cell alley climbs to '
        'its gate, then opens into the T of the sagrato', () {
      final world = createTutorialWorld();
      final gate = harbourRows.indexWhere((row) => row.contains('x'));
      final alley = harbourRows[gate].indexOf('x');
      final alleyWidth = priestGateFront.right - priestGateFront.left + 1;
      expect(harbourRows[gate].lastIndexOf('x') - alley + 1, alleyWidth);

      // Two cells of alley between the sidewalk and the gate.
      expect(priestGateFront.top, at(alley, gate + 1).y);
      expect(priestGateFront.bottom, at(alley, gate + 2).y);
      for (var y = priestGateFront.top; y <= priestGateFront.bottom; y++) {
        for (var x = alley; x < alley + alleyWidth; x++) {
          expect(
            world.map.tileAt(GridPoint(at(x, 0).x, y)).isWalkable,
            isTrue,
            reason: 'the alley at $x,$y',
          );
        }
        expect(
          world.map.tileAt(GridPoint(at(alley - 1, 0).x, y)).isWalkable,
          isFalse,
          reason: 'palazzi close the alley on the west',
        );
        expect(
          world.map
              .tileAt(GridPoint(at(alley + alleyWidth, 0).x, y))
              .isWalkable,
          isFalse,
          reason: 'and on the east',
        );
      }
      expect(
        world.map.tileAt(at(alley, gate + 3)).isWalkable,
        isTrue,
        reason: 'the sidewalk of the seafront road at the alley mouth',
      );

      // Past the gate the sagrato spreads both ways, wide as the church.
      final front =
          harbourRows[harbourRows.lastIndexWhere((row) => row.contains('W'))];
      final west = front.indexOf('W');
      final east = front.lastIndexOf('W');
      expect(west, lessThan(alley));
      expect(east, greaterThan(alley + alleyWidth - 1));
      for (var x = west; x <= east; x++) {
        expect(
          world.map.tileAt(at(x, gate - 1)).isWalkable,
          isTrue,
          reason: 'the sagrato in front of the church at column $x',
        );
      }
      expect(world.map.tileAt(at(west - 1, gate - 1)).isWalkable, isFalse);
      expect(world.map.tileAt(at(east + 1, gate - 1)).isWalkable, isFalse);
    });

    test('the gate shuts the alley, Don Angelo behind it and two wanderers '
        'before it', () {
      final world = createTutorialWorld();
      for (var x = priestGateFront.left; x <= priestGateFront.right; x++) {
        final gate = GridPoint(x, priestGateFront.top - 1);
        expect(world.map.tileAt(gate).isWalkable, isFalse);
        expect(
          world.map.tileAt(gate).blocksSight,
          isFalse,
          reason: 'railings: Mario and the priest can see each other',
        );
      }
      expect(priestTile.y, lessThan(priestGateFront.top));
      expect(world.map.tileAt(priestTile).isWalkable, isTrue);

      expect(priestZombieTiles, hasLength(2));
      for (final (index, tile) in priestZombieTiles.indexed) {
        expect(priestGateFront.contains(tile), isTrue);
        final zombie = world.entities['$priestZombiePrefix$index']!;
        expect(zombie.kind, EntityKind.wanderer);
        expect(zombie.component<PositionComponent>().position, tile);
      }
    });

    test('Don Angelo hails Mario from anywhere on the seafront road in '
        'front of the alley', () {
      final world = createTutorialWorld();
      final gate = harbourRows.indexWhere((row) => row.contains('x'));
      final road = <GridPoint>[
        for (var y = gate + 3; y < harbourRows.length; y++)
          if (harbourRows[y][harbourRows[gate].indexOf('x')] == '=')
            at(harbourRows[gate].indexOf('x'), y),
      ];
      expect(road, hasLength(2), reason: 'a sidewalk either side of the road');
      for (var y = road.first.y; y <= road.last.y; y++) {
        final lane = GridPoint(road.first.x, y);
        expect(world.map.tileAt(lane).isWalkable, isTrue);
        expect(
          priestSceneTrigger.contains(lane),
          isTrue,
          reason: 'walking the seafront at row $y',
        );
      }
      expect(
        priestSceneTrigger.contains(GridPoint(road.first.x, road.last.y + 1)),
        isFalse,
        reason: 'the promenade beyond the sidewalk is already too far',
      );
    });
  });

  group('Duomo', () {
    test('torches burn on every column and behind the altar, and light the '
        'nave', () {
      final duomo = place(PlaceId.duomo);
      final columns = duomo.tilesOf('P');
      expect(columns, hasLength(10));
      final torches = duomo.torches.toSet();
      expect(torches, containsAll(columns), reason: 'one on each column');
      final altar = duomo.tilesOf('A');
      final altarTop = altar.map((tile) => tile.y).reduce(math.min);
      final behind = torches.difference(columns.toSet());
      expect(behind, hasLength(4));
      final middle =
          (altar.map((t) => t.x).reduce(math.min) +
              altar.map((t) => t.x).reduce(math.max)) /
          2;
      for (final torch in behind) {
        expect(torch.y, altarTop - 1, reason: 'on the wall right behind it');
        expect(
          behind.any((other) => other.x - middle == middle - torch.x),
          isTrue,
          reason: 'in pairs either side of the altar middle',
        );
      }
      final world = createTutorialWorld();
      for (final torch in torches) {
        expect(
          world.map.tileAt(torch).isWalkable,
          isFalse,
          reason: 'fixed to a wall or a column, never in the way',
        );
      }
      final lit = duomo.lights.where((light) => light.torch).map((l) => l.tile);
      expect(lit.toSet(), torches);
      expect(
        duomo.darkness,
        lessThan(PlaceSpec.defaultDarkness),
        reason: 'far brighter than the other rooms',
      );
    });

    final duomo = place(PlaceId.duomo);

    test('it is larger than San Nicola and has three furnished naves', () {
      final church = place(PlaceId.church);
      expect(
        duomo.width * duomo.height,
        greaterThan(church.width * church.height),
      );
      expect(duomo.tilesOf('P'), hasLength(greaterThanOrEqualTo(8)));
      expect(duomo.tilesOf('T'), hasLength(greaterThanOrEqualTo(30)));
      expect(duomo.tilesOf('S'), hasLength(greaterThanOrEqualTo(6)));

      final columnXs = duomo.tilesOf('P').map((tile) => tile.x).toSet().toList()
        ..sort();
      expect(columnXs, hasLength(2), reason: 'two colonnades make three naves');
      expect(
        duomo
            .tilesOf('T')
            .every((pew) => pew.x > columnXs.first && pew.x < columnXs.last),
        isTrue,
        reason: 'the pews belong to the central nave',
      );

      final stairs = duomo.tilesOf('U');
      expect(stairs, hasLength(4));
      expect(
        stairs.every(
          (tile) => tile.x > duomo.bounds.left + duomo.width * 2 ~/ 3,
        ),
        isTrue,
      );
      expect(
        stairs.every((tile) => tile.y < duomo.bounds.top + duomo.height ~/ 3),
        isTrue,
      );
      expect(
        stairs
            .map(duomoStairCultistTile.manhattanDistanceTo)
            .reduce((left, right) => left < right ? left : right),
        1,
      );
    });

    test(
      'the open portal is initially reachable only after opening the gate',
      () {
        final world = createTutorialWorld();
        expect(world.map.tileAt(duomoPortalTile).isWalkable, isTrue);
        expect(world.portals[duomoPortalTile], isNotNull);
        expect(
          priestGateTiles.every((tile) => !world.map.tileAt(tile).isWalkable),
          isTrue,
        );

        final start = GridPoint(priestGateFront.left, priestGateFront.bottom);
        var reached = world.map.floodFillDistances(start, maxDistance: 80);
        expect(reached.containsKey(duomoPortalTile), isFalse);
        for (final tile in priestGateTiles) {
          world.map.setTile(tile, const Tile(TileKind.floor));
        }
        reached = world.map.floodFillDistances(start, maxDistance: 80);
        expect(reached.containsKey(duomoPortalTile), isTrue);

        world.player.component<PositionComponent>().position = duomoPortalTile
            .step(Direction.south);
        final events = const TurnScheduler().advance(
          world,
          const MoveAction(Direction.north),
        );
        expect(events.whereType<TeleportedEvent>(), hasLength(1));
        expect(
          duomo.bounds.contains(
            world.player.component<PositionComponent>().position,
          ),
          isTrue,
        );
      },
    );

    test('the upper floor contains a dining hall and communal dormitory', () {
      final upper = place(PlaceId.duomoUpper);
      final world = createTutorialWorld();
      expect(upper.indoor, isTrue);
      expect(upper.tilesOf('T'), hasLength(greaterThanOrEqualTo(20)));
      expect(upper.tilesOf('C'), hasLength(greaterThanOrEqualTo(20)));
      expect(upper.tilesOf('B'), hasLength(greaterThanOrEqualTo(24)));
      expect(upper.tilesOf('K'), hasLength(1));
      expect(upper.tilesOf('d'), hasLength(1));
      expect(upper.tilesOf('L'), hasLength(1));
      expect(upper.tilesOf('R'), hasLength(1));
      expect(upper.lit, isTrue, reason: 'no darkness upstairs');
      // The robe lies in a backpack, like everything Mario picks up.
      expect(world.pickupAt(duomoUpperRobeTile)?.cultistRobe, isTrue);

      final divider = upper.tilesOf('I').map((tile) => tile.x).toSet();
      expect(
        divider,
        contains(upper.tileOf('d').x),
        reason: 'the open doorway interrupts the wall between both rooms',
      );
      expect(
        upper.tilesOf('T').every((tile) => tile.x < upper.tileOf('d').x),
        isTrue,
      );
      expect(
        upper.tilesOf('B').every((tile) => tile.x > upper.tileOf('d').x),
        isTrue,
      );
    });

    test('the guarded stair opens onto the upper floor and returns', () {
      final world = createTutorialWorld();
      final upper = place(PlaceId.duomoUpper);
      expect(world.map.tileAt(duomoStairEntryTile).isWalkable, isFalse);
      expect(world.map.tileAt(duomoUpperLockedDoorTile).isWalkable, isFalse);
      expect(
        world.portals[duomoStairEntryTile]!.to,
        duomoUpperStairTile.step(Direction.north),
      );
      expect(
        world.portals[duomoUpperStairTile]!.to,
        duomoStairEntryTile.step(Direction.south),
      );

      world.map
        ..setTile(duomoStairCultistTile, const Tile(TileKind.floor))
        ..setTile(duomoStairEntryTile, const Tile(TileKind.floor));
      world.player.component<PositionComponent>().position =
          duomoStairCultistTile;
      var events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.north),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      expect(
        upper.bounds.contains(
          world.player.component<PositionComponent>().position,
        ),
        isTrue,
      );

      world.player.component<PositionComponent>().position = duomoUpperStairTile
          .step(Direction.north);
      events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.south),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      expect(
        place(
          PlaceId.duomo,
        ).bounds.contains(world.player.component<PositionComponent>().position),
        isTrue,
      );
    });

    test(
      'the bar storeroom contains the episcopal ring and returns to the bar',
      () {
        final world = createTutorialWorld();
        final backroom = place(PlaceId.barBackroom);
        final ring = world.pickups[episcopalRingPickupId]!;
        expect(backroom.bounds.contains(ring.position), isTrue);
        expect(ring.episcopalRing, isTrue);
        expect(
          world.pickups.values.where((pickup) => pickup.episcopalRing),
          hasLength(1),
        );
        expect(
          world.portals[barLockedDoorTile]!.to,
          barBackroomDoorTile.step(Direction.north),
        );
        expect(
          world.portals[barBackroomDoorTile]!.to,
          barLockedDoorTile.step(Direction.south),
        );

        world.player.component<PositionComponent>()
          ..position = ring.position.step(Direction.south)
          ..facing = Direction.north;
        final events = const TurnScheduler().advance(
          world,
          const InteractAction(),
        );
        final pickedUp = events.whereType<PickedUpEvent>().single;
        expect(pickedUp.episcopalRing, isTrue);
        expect(ring.collected, isTrue);
      },
    );

    test('what the mass leaves lies in the aisle between the first two '
        'blocks of pews', () {
      final pews = duomo.tilesOf('T').toSet();
      expect(
        duomoKeyTile,
        duomoPriestCorpseTile.step(Direction.north),
        reason: 'the backpack right beside the body',
      );
      expect(pews, isNot(contains(duomoPriestCorpseTile)));
      expect(pews, isNot(contains(duomoKeyTile)));
      // The aisle is only these two rows: pews close it north and south, so
      // neither the body nor the backpack can be reached from the pews.
      expect(pews, contains(duomoKeyTile.step(Direction.north)));
      expect(pews, contains(duomoPriestCorpseTile.step(Direction.south)));
    });

    test('the four cultists stand across the aisle, between Mario and the '
        'key', () {
      final world = createTutorialWorld();
      final wall = duomoCultistSpawns.toSet();
      expect(wall, hasLength(4));
      // Two abreast and two deep: the aisle is two tiles tall, so the wall
      // of bodies closes it from wall of pews to wall of pews.
      final rows = wall.map((tile) => tile.y).toSet();
      final columns = wall.map((tile) => tile.x).toSet();
      expect(rows, hasLength(2));
      expect(columns, hasLength(2));
      expect(rows.contains(duomoKeyTile.y), isTrue);
      expect(rows.contains(duomoPriestCorpseTile.y), isTrue);
      // East of the body and the backpack: between them and the stair Mario
      // comes down, never on top of them.
      expect(columns.every((x) => x > duomoKeyTile.x), isTrue);
      expect(
        columns.every((x) => x < duomoStairEntryTile.x),
        isTrue,
        reason: 'the stair is further east still',
      );
      for (final tile in wall) {
        expect(world.map.tileAt(tile).isWalkable, isTrue, reason: 'floor');
        expect(world.entityAt(tile), isNull, reason: 'nobody there yet');
      }
    });

    test('the key of the upper floor waits, hidden, beside the body', () {
      final world = createTutorialWorld();
      final key = world.pickups[duomoKeyPickupId]!;

      expect(key.duomoKey, isTrue);
      expect(key.position, duomoKeyTile);
      expect(duomo.bounds.contains(key.position), isTrue);
      expect(key.active, isFalse, reason: 'nothing to find before the mass');
      expect(key.collected, isFalse);
      expect(world.pickupAt(duomoKeyTile), isNull);
      expect(
        world.map.tileAt(duomoUpperLockedDoorTile).isWalkable,
        isFalse,
        reason: 'the door it opens starts shut',
      );
      expect(
        world.pickups.values.where((pickup) => pickup.duomoKey),
        hasLength(1),
      );
    });

    test('their wall shuts the aisle off from the stair, and only the long '
        'way round reaches the key', () {
      final world = createTutorialWorld();
      // The Duomo as the mass leaves it: the stair open behind Mario, the
      // body in the aisle, the backpack beside it and the four of them
      // across it.
      final map = world.map
        ..setTile(duomoStairCultistTile, const Tile(TileKind.floor))
        ..setTile(duomoStairEntryTile, const Tile(TileKind.floor))
        ..setTile(duomoPriestCorpseTile, const Tile(TileKind.obstacle))
        ..setTile(duomoPriestTile, const Tile(TileKind.floor))
        ..setTile(duomoWelcomingCultistTile, const Tile(TileKind.floor));
      world.pickups[duomoKeyPickupId]!.active = true;
      for (final (index, tile) in duomoCultistSpawns.indexed) {
        world.addEntity(createDuomoCultist('$duomoCultistPrefix$index', tile));
      }

      Set<GridPoint> walkFromTheStair({required bool cultistsThere}) {
        final seen = <GridPoint>{duomoStairEntryTile};
        final queue = <GridPoint>[duomoStairEntryTile];
        while (queue.isNotEmpty) {
          final from = queue.removeLast();
          for (final direction in Direction.values) {
            final next = from.step(direction);
            if (seen.contains(next) ||
                !place(PlaceId.duomo).bounds.contains(next) ||
                !map.tileAt(next).isWalkable) {
              continue;
            }
            final occupied = cultistsThere
                ? world.isBlocked(next)
                : world.pickupAt(next) != null;
            if (occupied) {
              continue;
            }
            seen.add(next);
            queue.add(next);
          }
        }
        return seen;
      }

      final blocked = walkFromTheStair(cultistsThere: true);
      final east = duomoKeyTile.step(Direction.east);
      expect(
        blocked,
        isNot(contains(east)),
        reason: 'the four of them shut the aisle between Mario and the key',
      );
      expect(
        blocked,
        contains(duomoKeyTile.step(Direction.west)),
        reason: 'but the nave can be walked round to the far side of them',
      );
      // Which is the only way past them while they stand: down the aisle it
      // cannot be done.
      expect(
        walkFromTheStair(cultistsThere: false),
        contains(east),
        reason: 'once they move, the short way is open again',
      );
    });

    test('the mutated cultists take three shots and walk like wanderers', () {
      final cultist = createDuomoCultist(
        '${duomoCultistPrefix}0',
        duomoCultistSpawns.first,
      );
      final wanderer = createMallZombie('mall-0', duomoCultistSpawns.last);

      expect(cultist.kind, EntityKind.cultist);
      expect(cultist.component<HealthComponent>().current, 3);
      expect(
        cultist.component<ActorComponent>().tickCost,
        wanderer.component<ActorComponent>().tickCost,
      );
      expect(
        cultist.component<PositionComponent>().facing,
        Direction.east,
        reason: 'looking down the aisle Mario has to come along',
      );
    });
  });

  group('San Nicola', () {
    final church = place(PlaceId.church);

    test('its portal stands open on the church square and goes both ways', () {
      final world = createTutorialWorld();
      // The portal is a hole in the bottom row of the church's own block,
      // with the paving of its little square under it.
      expect(
        harbourRows[churchPortalTile.y -
            place(PlaceId.harbour).origin.y][churchPortalTile.x -
            place(PlaceId.harbour).origin.x],
        '(',
      );
      expect(world.map.tileAt(churchPortalTile).isWalkable, isTrue);
      expect(
        world.map.tileAt(churchPortalTile.step(Direction.north)).isWalkable,
        isFalse,
        reason: 'the front of the church stands over its own door',
      );

      final square = churchPortalTile.step(Direction.south);
      world.player.component<PositionComponent>().position = square;
      var events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.north),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      final inside = world.player.component<PositionComponent>().position;
      expect(church.bounds.contains(inside), isTrue);

      events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.south),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      expect(world.player.component<PositionComponent>().position, square);
    });

    test('the nave lights the portal, roof holes and incense backpack', () {
      expect(church.indoor, isTrue);
      expect(
        church.lights,
        hasLength(church.tilesOf('^').length + 2),
        reason: 'the backpack has a dedicated pool of light',
      );
      expect(church.lights.every((light) => !light.flickers), isTrue);
      expect(
        church.lights.any(
          (light) =>
              light.tile ==
              createTutorialWorld().pickups[incenseBackpackId]!.position,
        ),
        isTrue,
      );
    });

    test('the backpack by the east wall holds the incense, and nothing '
        'else in the game does', () {
      final world = createTutorialWorld();
      final backpack = world.pickups[incenseBackpackId]!;
      expect(church.bounds.contains(backpack.position), isTrue);
      expect(backpack.ammo, 0);
      expect(backpack.gun, isFalse);
      expect(
        world.pickups.values.where((pickup) => pickup.incense),
        hasLength(1),
      );

      world.player.component<PositionComponent>()
        ..position = backpack.position.step(Direction.south)
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );
      final pickedUp = events.whereType<PickedUpEvent>().single;
      expect(pickedUp.incense, isTrue);
      expect(pickedUp.ammo, 0);
      expect(backpack.collected, isTrue);
    });
  });

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
      final world = createTutorialWorld();
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

    test('the west doorway reaches the tracks, the train shuts them, and '
        'the two rounds are at the dead end', () {
      final world = createTutorialWorld();
      final reached = from(
        world,
        world.portals[stationWestDoor.first]!.to,
        station,
      );
      final rails = station.tilesOf('-');
      expect(
        rails.where(reached.containsKey),
        isNotEmpty,
        reason: 'the platform lets Mario down onto the track',
      );

      final backpack = world.pickups[stationBackpackId]!;
      expect(backpack.ammo, stationBackpackAmmo);
      expect(
        reached.containsKey(backpack.position.step(Direction.west)),
        isTrue,
        reason: 'it can be reached, and taken from the tile beside it',
      );

      // Nothing east of the two wrecks is walked to: the railcar closes
      // the near track and the coach on its side the far one.
      final wrecks = <GridPoint>[
        ...station.tilesOf('M'),
        ...station.tilesOf('m'),
      ];
      final wreckLeft = wrecks
          .map((tile) => tile.x)
          .reduce((a, b) => a < b ? a : b);
      for (final tile in reached.keys) {
        expect(
          tile.x,
          lessThanOrEqualTo(wreckLeft + 1),
          reason: 'the wrecks are as far east as the tracks go',
        );
      }
      for (final wreck in wrecks) {
        expect(world.map.tileAt(wreck).isWalkable, isFalse);
      }
      expect(
        station
            .tilesOf('M')
            .every((tile) => world.map.tileAt(tile).blocksSight),
        isTrue,
        reason: 'the railcar is a wall, not something to shoot over',
      );
      expect(
        station
            .tilesOf('m')
            .every((tile) => !world.map.tileAt(tile).blocksSight),
        isTrue,
        reason: 'the coach is down on its side: you see over it',
      );
    });

    test('the east doorway reaches the stairs, and the underpass comes up '
        'on the far platform', () {
      final world = createTutorialWorld();
      final reached = from(
        world,
        world.portals[stationEastDoor.first]!.to,
        station,
      );
      final down = station.doorRow('U');
      expect(down, hasLength(2));
      expect(
        down.every(reached.containsKey),
        isTrue,
        reason: "the flight down is on the far doorway's side of the fall",
      );

      GridPoint through(GridPoint step, Direction facing) {
        world.player.component<PositionComponent>().position = step.step(
          facing.opposite,
        );
        final events = const TurnScheduler().advance(world, MoveAction(facing));
        expect(events.whereType<TeleportedEvent>(), hasLength(1));
        return world.player.component<PositionComponent>().position;
      }

      final corridor = through(down.first, Direction.north);
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

      final platform = through(up.first, Direction.north);
      expect(farSide.bounds.contains(platform), isTrue);
      expect(
        stationPlatform.contains(platform),
        isTrue,
        reason: 'you come up onto the platform Luigi is waiting on',
      );
    });

    test('the far platform is one clear walk in front of the whole train', () {
      final world = createTutorialWorld();
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

    test('the passenger door is closed by default and leads through two '
        'coaches to the locomotive when opened', () {
      final world = createTutorialWorld();
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
      expect(trainMapTiles, hasLength(8), reason: 'a table four by two');
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
        tutorialPlaces.where((place) => place.lit).map((place) => place.id),
        <PlaceId>[PlaceId.trainInterior, PlaceId.duomoUpper],
        reason:
            'every other room stays in the dark but the upper floor of '
            'the Duomo, where the community lives',
      );
    });

    test('behind the engine Luigi, the books and the cot can each be walked '
        'up to and looked at, apart from each other', () {
      final world = createTutorialWorld();
      final train = place(PlaceId.trainInterior);
      final reached = from(world, trainExitTile.step(Direction.north), train);
      expect(reached.containsKey(trainMapStandTile), isTrue);
      final things = <GridPoint>[
        trainLuigiTile,
        ...trainBookTiles,
        ...trainCotTiles,
      ];
      expect(trainBookTiles, isNotEmpty);
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
      // Mario above the aisle and Luigi below it, both at the back, walled
      // off from the map table by the luggage.
      final aisle = trainExitTile.y - 6;
      final luggage = train
          .tilesOf('L')
          .where((tile) => tile.x > trainExitTile.x + 30);
      final divider = luggage.map((tile) => tile.x).reduce(math.min);
      expect(trainLuigiTile.x, lessThan(divider));
      expect(trainLuigiTile.y, greaterThan(aisle));
      for (final tile in <GridPoint>[...trainBookTiles, ...trainCotTiles]) {
        expect(tile.x, lessThan(divider));
        expect(tile.y, lessThan(aisle));
      }
      for (final map in trainMapTiles) {
        expect(map.x, greaterThan(divider + 1));
      }
    });

    test('two wanderers wait in the booking hall and one in the church', () {
      final world = createTutorialWorld();
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
      final world = createTutorialWorld();
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

  group('the crashed airliner', () {
    final street = place(PlaceId.mallNorthStreet);
    final cabin = place(PlaceId.airlinerCabin);
    final roofs = place(PlaceId.airlinerRoofs);

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

    test('it lies across the crossroads, wings where the street sees '
        'them', () {
      final world = createTutorialWorld();
      final body = street.tilesOf('_');
      final wings = street.tilesOf('+');
      expect(body, isNotEmpty);
      expect(wings, isNotEmpty);
      for (final tile in body) {
        expect(world.map.tileAt(tile).isWalkable, isFalse);
      }
      for (final tile in wings) {
        expect(world.map.tileAt(tile).kind, TileKind.obstacle);
      }
      // It runs off the east edge of the map: the tail is somewhere else.
      expect(body.map((tile) => tile.x).reduce(math.max), street.bounds.right);
      // Nose in the road, tail high up in the palazzi.
      final nose = body.reduce((a, b) => a.x < b.x ? a : b);
      final tail = body.reduce((a, b) => a.x > b.x ? a : b);
      expect(tail.y, lessThan(nose.y), reason: 'it climbed as it went');

      final reached = from(world, mallNorthStreetEntry, street);
      // Everywhere the block was walked for before is still walked for:
      // the wreck narrows the junction, it never shuts a way to anything.
      for (final way in <GridPoint>[
        ...street.tilesOf('<'),
        ...stationWestDoor,
        ...stationEastDoor,
        ...airlinerTear,
      ]) {
        expect(reached.containsKey(way), isTrue, reason: '$way is cut off');
      }
      // The wings came down on the junction, not away over roofs nobody
      // can walk to: a good half of them are within three tiles of ground
      // the player stands on, so they are seen from the street.
      bool seenFrom(GridPoint wing) {
        for (var dx = -3; dx <= 3; dx++) {
          for (var dy = -3; dy <= 3; dy++) {
            if (reached.containsKey(GridPoint(wing.x + dx, wing.y + dy))) {
              return true;
            }
          }
        }
        return false;
      }

      expect(wings.where(seenFrom).length * 2, greaterThan(wings.length));
    });

    test('the tear in its belly leads into the cabin and back out', () {
      final world = createTutorialWorld();
      expect(airlinerTear, hasLength(2), reason: 'as wide as the aisle');
      final inside = travel(world, airlinerTear.first, Direction.north);
      expect(cabin.bounds.contains(inside), isTrue);
      expect(inside, airlinerCabinTear.first.step(Direction.north));

      final back = travel(world, airlinerCabinTear.first, Direction.south);
      expect(back, airlinerTear.first.step(Direction.south));
      expect(street.bounds.contains(back), isTrue);
      expect(
        world.map.tileAt(back).isWalkable,
        isTrue,
        reason: 'it comes out in the lane the wreck left open',
      );
    });

    test('the cabin walks from the tear to the tail break', () {
      final world = createTutorialWorld();
      final reached = from(
        world,
        airlinerCabinTear.first.step(Direction.north),
        cabin,
      );
      // A trolley closes one half of the break; the other is open, for
      // whoever gets past the mutilated zombie lying in it.
      expect(
        airlinerTailBreak.where(
          (door) => reached.containsKey(door.step(Direction.south)),
        ),
        hasLength(1),
        reason: 'the aisle runs the length of the cabin',
      );
      expect(cabin.lights, isNotEmpty, reason: 'a room on a dark background');
    });

    test('two wanderers are left in the cabin', () {
      final world = createTutorialWorld();
      final zombies = world.entities.values
          .where((entity) => entity.id.startsWith(airlinerZombiePrefix))
          .toList();
      expect(zombies, hasLength(2));
      for (final zombie in zombies) {
        expect(zombie.kind, EntityKind.wanderer);
        final at = zombie.component<PositionComponent>().position;
        expect(cabin.bounds.contains(at), isTrue);
        expect(world.map.tileAt(at).isWalkable, isTrue);
      }
    });

    group('the mutilated zombies', () {
      List<GridPoint> mutilatedTiles(WorldState world) => <GridPoint>[
        for (final entity in world.entities.values)
          if (entity.kind == EntityKind.mutilated && entity.isAlive)
            entity.component<PositionComponent>().position,
      ];

      /// The tiles Mario walks to from the tear without stepping over a
      /// mutilated zombie, nor next to one outside [bitesAllowed].
      Set<GridPoint> walk(
        WorldState world, {
        bool bitesAllowed = true,
        GridPoint? except,
      }) {
        final lying = mutilatedTiles(world);
        bool bitten(GridPoint tile) => lying.any(
          (zombie) => zombie != except && zombie.manhattanDistanceTo(tile) <= 1,
        );
        final start = airlinerCabinTear.first.step(Direction.north);
        final seen = <GridPoint>{start};
        final frontier = <GridPoint>[start];
        while (frontier.isNotEmpty) {
          final tile = frontier.removeLast();
          for (final direction in Direction.values) {
            final next = tile.step(direction);
            if (!cabin.bounds.contains(next) ||
                seen.contains(next) ||
                !world.map.tileAt(next).isWalkable ||
                lying.contains(next) ||
                (!bitesAllowed && bitten(next))) {
              continue;
            }
            seen.add(next);
            frontier.add(next);
          }
        }
        return seen;
      }

      final guard = airlinerTailBreak.first.step(Direction.south);

      test('lie in the cabin, many of them, facing the aisle', () {
        final world = createTutorialWorld();
        final zombies = world.entities.values
            .where((entity) => entity.id.startsWith(airlinerMutilatedPrefix))
            .toList();
        expect(zombies.length, greaterThanOrEqualTo(4));
        for (final zombie in zombies) {
          expect(zombie.kind, EntityKind.mutilated);
          final at = zombie.component<PositionComponent>().position;
          expect(cabin.bounds.contains(at), isTrue);
          expect(world.map.tileAt(at).isWalkable, isTrue);
          expect(
            zombie.component<ActorComponent>().stationary,
            isTrue,
            reason: 'none of them ever moves',
          );
        }
      });

      test('the one under the tail break has to be killed to get out', () {
        final world = createTutorialWorld();
        expect(mutilatedTiles(world), contains(guard));
        final reached = walk(world);
        for (final door in airlinerTailBreak) {
          expect(reached.contains(door), isFalse, reason: 'he is in the way');
        }
        // Shot, he is out of the way: the break opens on the roofs.
        world.entities.values
                .firstWhere(
                  (entity) =>
                      entity.component<PositionComponent>().position == guard,
                )
                .component<HealthComponent>()
                .current =
            0;
        final afterwards = walk(world);
        expect(afterwards.contains(airlinerTailBreak.first), isTrue);
      });

      test('he can be shot from a distance, without a bite', () {
        final world = createTutorialWorld();
        final reached = walk(world, bitesAllowed: false, except: guard);
        final inLine = <GridPoint>[
          for (var y = guard.y + 2; y < cabin.bounds.bottom; y++)
            GridPoint(guard.x, y),
        ];
        final spot = inLine.firstWhere(reached.contains);
        world.player.component<PositionComponent>()
          ..position = spot
          ..facing = Direction.north;
        world.player.component<AmmoComponent>()
          ..hasGun = true
          ..loaded = 1;
        const TurnScheduler().advance(world, const ShootAction());
        expect(mutilatedTiles(world), isNot(contains(guard)));
      });

      test('all the others can be walked round without a bite, and so can '
          'the flight bag with the rounds be reached', () {
        final world = createTutorialWorld();
        final reached = walk(world, bitesAllowed: false, except: guard);
        final bag = world.pickups[airlinerBackpackId]!;
        expect(bag.ammo, greaterThanOrEqualTo(1));
        expect(cabin.bounds.contains(bag.position), isTrue);
        expect(
          Direction.values.any(
            (direction) => reached.contains(bag.position.step(direction)),
          ),
          isTrue,
          reason: 'the bag is picked up from a tile next to it',
        );
        // Right up to the tile in front of the one in the way.
        expect(reached.contains(guard.step(Direction.south)), isTrue);
      });
    });

    group('the burning zombie', () {
      Entity burning(WorldState world) =>
          world.entities[rooftopBurningZombieId]!;

      test('stands on the lower terrace, in front of the corner on fire', () {
        final world = createTutorialWorld();
        final zombie = burning(world);
        expect(zombie.kind, EntityKind.burning);
        expect(zombie.component<ActorComponent>().trailsFire, isTrue);
        final at = zombie.component<PositionComponent>().position;
        expect(at, roofs.tileOf('Y'));

        final corner = roofs.tilesOf('&');
        expect(corner.length, greaterThanOrEqualTo(5));
        for (final tile in corner) {
          expect(world.map.tileAt(tile).kind, TileKind.fire);
          expect(world.map.tileAt(tile).isWalkable, isFalse);
          // The south-east corner of the lower terrace.
          expect(tile.y, greaterThan(rooftopGapTile.y - 5));
          expect(tile.x, greaterThan(rooftopGapTile.x));
        }
        expect(
          corner.any((tile) => tile.manhattanDistanceTo(at) == 1),
          isTrue,
          reason: 'it walked out of the fire',
        );
      });

      test('going after Mario it leaves a trail of fire nobody crosses, and '
          'the way back to the tail stays open', () {
        final world = createTutorialWorld();
        final zombie = burning(world);
        final start = zombie.component<PositionComponent>().position;
        world.player.component<PositionComponent>()
          ..position = GridPoint(start.x - 5, start.y)
          ..facing = Direction.east;
        final fires = <GridPoint>[];
        const scheduler = TurnScheduler();
        for (var i = 0; i < 6; i++) {
          fires.addAll(
            scheduler
                .advance(world, const WaitAction())
                .whereType<FireStartedEvent>()
                .map((event) => event.at),
          );
        }
        expect(fires, isNotEmpty);
        expect(fires.first, start, reason: 'where it stood caught fire');
        for (final tile in fires) {
          expect(roofs.bounds.contains(tile), isTrue);
          expect(world.map.tileAt(tile).kind, TileKind.fire);
        }
        final reached = world.map.floodFillDistances(
          world.player.component<PositionComponent>().position,
          maxDistance: roofs.width * roofs.height,
        );
        expect(
          reached.containsKey(airlinerRoofBreak.first.step(Direction.south)),
          isTrue,
        );
      });

      test('the tiles it set alight are still burning after a save', () {
        final world = createTutorialWorld();
        final tile = roofs.tileOf('Y').step(Direction.west);
        world.map.setTile(tile, const Tile(TileKind.fire));
        final restored = restoreTutorialWorld(
          jsonDecode(jsonEncode(saveTutorialWorld(world)))
              as Map<String, Object?>,
        );
        expect(restored.map.tileAt(tile).kind, TileKind.fire);
        for (final corner in roofs.tilesOf('&')) {
          expect(restored.map.tileAt(corner).kind, TileKind.fire);
        }
      });
    });

    test('the tail break comes out on the roofs, and goes back in', () {
      final world = createTutorialWorld();
      final roof = travel(world, airlinerTailBreak.first, Direction.south);
      expect(roofs.bounds.contains(roof), isTrue);
      expect(roof, airlinerRoofBreak.first.step(Direction.south));

      final back = travel(world, airlinerRoofBreak.first, Direction.south);
      expect(cabin.bounds.contains(back), isTrue);
      expect(back, airlinerTailBreak.first.step(Direction.south));
    });

    test('the roofs end at the gap, which can only be looked at', () {
      final world = createTutorialWorld();
      final reached = from(
        world,
        airlinerRoofBreak.first.step(Direction.south),
        roofs,
      );
      expect(
        reached.containsKey(rooftopGapTile.step(Direction.north)),
        isTrue,
        reason: 'both terraces walk, the lower one down to the parapet',
      );
      expect(world.map.tileAt(rooftopGapTile).isWalkable, isFalse);
      expect(world.lookouts, contains(rooftopGapTile));
      // Beyond the parapet there is the drop, and then a roof nobody can
      // reach from here.
      for (final tile in roofs.tilesOf('%')) {
        expect(reached.containsKey(tile), isFalse);
      }
      for (final tile in reached.keys) {
        expect(roofs.bounds.contains(tile), isTrue);
      }
    });

    test('looking at the gap says what it would take to cross it', () {
      final world = createTutorialWorld();
      world.player.component<PositionComponent>()
        ..position = rooftopGapTile.step(Direction.north)
        ..facing = Direction.south;

      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );

      expect(events.whereType<LookedOutEvent>().single.at, rooftopGapTile);
      expect(events.whereType<NoInteractionEvent>(), isEmpty);
      expect(
        world.lookouts,
        contains(rooftopGapTile),
        reason: 'looking changes nothing: it can be looked at again',
      );
    });
  });

  test('a carabiniere zombie patrols the park behind the mall', () {
    final world = createTutorialWorld();
    final park = place(PlaceId.mallNorthStreet);
    final carabinieri = world.entities.values.where(
      (entity) =>
          entity.kind == EntityKind.carabiniere &&
          park.bounds.contains(entity.component<PositionComponent>().position),
    );
    expect(carabinieri, hasLength(1));
  });

  test('the barracks has lamps and two carabinieri waiting in the dark', () {
    expect(place(PlaceId.barracks).lights, isNotEmpty);
    expect(
      place(PlaceId.barracks).lights.where((light) => light.flickers),
      isNotEmpty,
    );
    expect(carabiniereSpawns, hasLength(2));
    final world = createTutorialWorld();
    for (final spawn in carabiniereSpawns) {
      expect(world.map.tileAt(spawn).isWalkable, isTrue);
    }
  });

  test('the carabiniere in the middle steps south into the lamp light', () {
    final world = createTutorialWorld();
    // Mario a few steps past the front door, where the carabinieri come out.
    world.player.component<PositionComponent>().position = GridPoint(
      place(PlaceId.barracks).origin.x + 10,
      place(PlaceId.barracks).origin.y + 11,
    );
    final spawn = carabiniereSpawns.firstWhere(
      (tile) => tile.x == place(PlaceId.barracks).origin.x + 10,
    );
    final carabiniere = createCarabiniere('carabiniere-0', spawn);
    world.addEntity(carabiniere);
    final position = carabiniere.component<PositionComponent>();
    var before = position.position;
    while (true) {
      const TurnScheduler().advance(world, const WaitAction());
      if (position.position.y > before.y) {
        break;
      }
      before = position.position;
    }
    bool lit(GridPoint tile) => place(PlaceId.barracks).lights.any(
      (light) =>
          (light.tile.x - tile.x).abs() + (light.tile.y - tile.y).abs() <= 1,
    );
    expect(lit(before), isFalse, reason: 'still in the dark at $before');
    expect(
      lit(position.position),
      isTrue,
      reason: 'lit at ${position.position}',
    );
  });

  test('fires burn on the street, in the north district, at the harbour and '
      'in the pile-up behind the hypermarket', () {
    int count(List<FireSpot> spots, FireKind kind) =>
        spots.where((s) => s.kind == kind).length;
    final street = streetFireSpots;
    expect(count(street, FireKind.car), 2);
    expect(count(street, FireKind.bin), 2);
    expect(count(street, FireKind.window), 3);
    final all = outdoorFireSpots;
    final behindMall = place(PlaceId.mallNorthStreet).bounds;
    expect(
      all.where(
        (spot) => spot.kind == FireKind.car && behindMall.contains(spot.tile),
      ),
      hasLength(4),
      reason: 'the burning wrecks blocking the road west',
    );
    expect(count(all, FireKind.car), 11);
    expect(count(all, FireKind.bin), 10);
    expect(count(all, FireKind.window), 14);
    expect(count(all, FireKind.campfire), 2);
    // One camp in the north district, one in the dead end the wrecks
    // leave at the west end of the shopping street behind the mall.
    expect(
      all
          .where((spot) => spot.kind == FireKind.campfire)
          .map((spot) => placeAt(spot.tile)?.id)
          .toSet(),
      <PlaceId>{PlaceId.northDistrict, PlaceId.mallNorthStreet},
    );
  });

  test('the camp burns at the closed east end of the north street', () {
    final world = createTutorialWorld();
    final camp = world.campfires.firstWhere(
      place(PlaceId.northDistrict).bounds.contains,
    );
    final (x, y) = (
      camp.x - place(PlaceId.northDistrict).origin.x,
      camp.y - place(PlaceId.northDistrict).origin.y,
    );
    final row = northDistrictRows[y];
    expect(row.indexOf('B', x), lessThan(x + 4), reason: 'a dead end');
    expect(x, greaterThan(_outdoorColumn('e')), reason: 'past the barracks');
  });

  test('the flagpole stands on the barracks forecourt', () {
    final pole = flagpoleTile;
    expect(barracksForecourt.contains(pole), isTrue);
    expect(createTutorialWorld().map.tileAt(pole).isWalkable, isFalse);
  });

  test('resting at the camp beyond the barracks asks the game to save', () {
    final world = createTutorialWorld();
    final camp = world.campfires.firstWhere(
      place(PlaceId.northDistrict).bounds.contains,
    );
    expect(campfireNames[camp], 'Dietro la caserma');
    expect(world.map.tileAt(camp).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = camp.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<CampfireUsedEvent>().single.at, camp);
  });

  group('saves', () {
    Map<String, Object?> throughStorage(Map<String, Object?> json) =>
        jsonDecode(jsonEncode(json)) as Map<String, Object?>;

    test('store what changed, not the whole map: a few kilobytes', () {
      final world = createTutorialWorld();
      final save = jsonEncode(saveTutorialWorld(world));
      expect(save.length, lessThan(40 * 1024));
      expect(saveTutorialWorld(world).containsKey('map'), isFalse);
      expect(saveTutorialWorld(world)['mapChanges'], isEmpty);
    });

    test('zombies killed or moved, backpacks collected, the lifted shutter '
        'and Mario all survive a save and a load', () {
      final world = createTutorialWorld();
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

      final save = throughStorage(saveTutorialWorld(world));
      expect(
        save['mapChanges'],
        hasLength(luigiBars.right - luigiBars.left + 1),
      );
      final restored = restoreTutorialWorld(save);

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

    test('an older save gains backpacks added by the current level', () {
      final world = createTutorialWorld();
      world.pickups[ammoBackpackId]!
        ..active = false
        ..collected = true;
      final oldSave = throughStorage(saveTutorialWorld(world));
      (oldSave['pickups']! as List<Object?>).removeWhere(
        (encoded) =>
            (encoded! as Map<String, Object?>)['id'] == incenseBackpackId,
      );

      final restored = restoreTutorialWorld(oldSave);

      expect(restored.pickups[incenseBackpackId], isNotNull);
      expect(restored.pickups[incenseBackpackId]!.active, isTrue);
      expect(restored.pickups[incenseBackpackId]!.collected, isFalse);
      expect(
        restored.pickups[incenseBackpackId]!.position,
        createTutorialWorld().pickups[incenseBackpackId]!.position,
      );
      expect(
        restored.pickups[ammoBackpackId]!.collected,
        isTrue,
        reason: 'saved pickup state must win over the level default',
      );
    });

    test('an older save gains zombies added by the current level', () {
      final world = createTutorialWorld();
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
      final oldSave = throughStorage(saveTutorialWorld(world));
      (oldSave['entities']! as List<Object?>).removeWhere(
        (encoded) =>
            addedIds.contains((encoded! as Map<String, Object?>)['id']),
      );

      final restored = restoreTutorialWorld(oldSave);

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
        return throughStorage(saveTutorialWorld(world));
      }

      final world = createTutorialWorld();
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
      final loaded = restoreTutorialWorld(rest(world, first));
      expect(loaded.entities[zombie.id]!.isAlive, isFalse);
      expect(
        loaded.player.component<PositionComponent>().position,
        first.step(Direction.west),
      );

      // Then rest at the new one, and load that save in turn.
      final again = restoreTutorialWorld(rest(loaded, second));
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

  test('the whole world survives a save and a load', () {
    final world = createTutorialWorld();
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
}

int _outdoorColumn(String glyph) =>
    northDistrictRows.firstWhere((row) => row.contains(glyph)).indexOf(glyph);
