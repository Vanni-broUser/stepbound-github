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
      roadRows.every(
        (row) =>
            outdoorLegend.obstacles.contains(row[1]) ||
            outdoorLegend.fire.contains(row[1]),
      ),
      isTrue,
      reason:
          'wrecks, or the fuel of one burning, never a wall: the wrecks are '
          'nosed forward and back of one another, but each covers the '
          'second column from the edge',
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

  test('past the backpack behind the mall a lane has no car, only fire, '
      'and looking at it says what it would take', () {
    final world = createGameWorld();
    final street = place(PlaceId.mallNorthStreet);
    final fire = street.tilesOf('?');
    expect(fire, isNotEmpty);
    for (final tile in fire) {
      expect(world.map.tileAt(tile).kind, TileKind.fire);
      expect(world.map.tileAt(tile).blocksSight, isFalse);
    }
    // Across a lane of the shopping street, west of the parking campfire,
    // and the
    // cars either side of that lane caught fire from it.
    final camp = world.campfires.firstWhere(street.bounds.contains);
    expect(fire.every((tile) => tile.x < camp.x), isTrue);
    final lane = shoppingStreetFireTile.y - street.origin.y;
    for (final row in <int>[lane - 1, lane + 1]) {
      expect(
        street.rows[row].substring(1, 3),
        'XX',
        reason: 'a burning car beside the fire, in row $row',
      );
    }
    expect(world.lookouts, contains(shoppingStreetFireTile));

    // Walked up to from the campfire, and looked at.
    final reached = world.map.floodFillDistances(
      camp.step(Direction.east),
      maxDistance: street.width * street.height,
    );
    final stand = shoppingStreetFireTile.step(Direction.east);
    expect(reached.containsKey(stand), isTrue);
    world.player.component<PositionComponent>()
      ..position = stand
      ..facing = Direction.west;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(
      events.whereType<LookedOutEvent>().single.at,
      shoppingStreetFireTile,
    );
    expect(world.map.tileAt(shoppingStreetFireTile).kind, TileKind.fire);
  });

  test('the mall-north fire moves beside the rubbish and leaves a two-round '
      'backpack at its old site', () {
    final world = createGameWorld();
    final street = place(PlaceId.mallNorthStreet);
    final backpack = world.pickups[mallNorthBackpackId]!;

    expect(backpack.position, mallNorthBackpackTile);
    expect(backpack.ammo, mallNorthBackpackAmmo);
    expect(backpack.gun, isFalse);
    expect(world.campfires, isNot(contains(backpack.position)));
    expect(
      GridPoint(
        backpack.position.x - street.origin.x,
        backpack.position.y - street.origin.y,
      ),
      const GridPoint(7, 9),
      reason: 'the backpack occupies the previous campfire site',
    );

    expect(campfireNames[mallNorthCampfireTile], 'Zona nord');
    expect(world.campfires.where(street.bounds.contains), <GridPoint>[
      mallNorthCampfireTile,
    ]);
    final localCamp = GridPoint(
      mallNorthCampfireTile.x - street.origin.x,
      mallNorthCampfireTile.y - street.origin.y,
    );
    expect(mallNorthStreetRows[localCamp.y][localCamp.x], 'S');
    expect(
      Direction.values.any((direction) {
        final neighbour = localCamp.step(direction);
        if (neighbour.x < 0 ||
            neighbour.y < 0 ||
            neighbour.y >= mallNorthStreetRows.length ||
            neighbour.x >= mallNorthStreetRows[neighbour.y].length) {
          return false;
        }
        return ':;'.contains(mallNorthStreetRows[neighbour.y][neighbour.x]);
      }),
      isTrue,
      reason: 'the fire is on a parking bay immediately beside the rubbish',
    );
  });

  test('the block behind the mall walks as a circuit, never to the edge', () {
    final world = createGameWorld();
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

  test('only the campfire burns beyond the barracks back exit', () {
    final north = place(PlaceId.northDistrict);
    final nearbyFires = hometownFireSpots.where(
      (spot) => spot.tile.manhattanDistanceTo(northDistrictBackExitTile) <= 8,
    );

    expect(nearbyFires, isEmpty);
    expect(northDistrictRows[36].substring(69, 71), 'CC');
    expect(northDistrictRows[37][79], 'F');
    expect(
      hometownFireSpots.map((spot) => spot.tile),
      isNot(contains(extinguishedNorthDistrictBinTile)),
    );
    expect(
      north.tileOf('S').manhattanDistanceTo(northDistrictBackExitTile),
      greaterThan(8),
      reason: 'the real camp remains further along the closed street',
    );
  });

  test('four drunks stagger about the Bar Arcobaleno, one by the service '
      'door', () {
    final world = createGameWorld();
    final bar = place(PlaceId.barArcobaleno).bounds;
    final drunks = world.entities.values
        .where((entity) => entity.kind == EntityKind.drunk)
        .toList();
    expect(drunks, hasLength(4));
    final tiles = <GridPoint>{
      for (final drunk in drunks) drunk.component<PositionComponent>().position,
    };
    expect(tiles, hasLength(4));
    expect(tiles.every(bar.contains), isTrue);
    expect(tiles.every((tile) => world.map.tileAt(tile).isWalkable), isTrue);
    expect(
      tiles.any((tile) => tile.manhattanDistanceTo(barLockedDoorTile) <= 3),
      isTrue,
    );
    expect(world.entities, contains(barDrunkZombieId));
  });

  test('three lamps light the sign of the bar and one each pool table', () {
    final bar = place(PlaceId.barArcobaleno);
    String glyphAt(GridPoint tile) =>
        bar.rows[tile.y - bar.origin.y][tile.x - bar.origin.x];
    final lit = <GridPoint>{for (final light in bar.lights) light.tile};
    final onSign = lit.where(
      (tile) => tile.y == bar.origin.y + 2 && glyphAt(tile) == 'W',
    );
    expect(onSign, hasLength(3));
    final onTables = lit.where((tile) => glyphAt(tile) == 'P').toList();
    expect(onTables, hasLength(2));
    // One over each table: the two are not touching.
    expect(onTables.first.manhattanDistanceTo(onTables.last), greaterThan(2));
  });

  test('the service door of the bar is in its back wall, used going north', () {
    final world = createGameWorld();
    final bar = place(PlaceId.barArcobaleno);
    final above = barLockedDoorTile.step(Direction.north);
    expect(bar.rows[above.y - bar.origin.y][above.x - bar.origin.x], 'W');
    // Opened, the only way into it is from the floor below, going north.
    world.map.setTile(barLockedDoorTile, const Tile(TileKind.floor));
    expect(world.map.walkableNeighbors(barLockedDoorTile).toList(), <GridPoint>[
      barLockedDoorTile.step(Direction.south),
    ]);
  });

  test('the player starts unarmed with no bullets', () {
    final ammo = createGameWorld().player.component<AmmoComponent>();
    expect(ammo.hasGun, isFalse);
    expect(ammo.loaded, 0);
  });

  test('bullets pile up with no magazine to cap them', () {
    final ammo = createGameWorld().player.component<AmmoComponent>()
      ..add(4)
      ..add(5);
    expect(ammo.loaded, 9, reason: 'nothing is left in a reserve');
  });

  test('the crossroads opens north and east but not south', () {
    final map = createGameWorld().map;
    expect(map.tileAt(const GridPoint(16, 30)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(30, 46)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(16, 50)).isWalkable, isFalse);
  });

  test('the streets end against buildings, the north one at the barracks', () {
    final map = createGameWorld().map;
    expect(map.tileAt(const GridPoint(3, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(40, 46)).isWalkable, isFalse);
    // The dead-end street off the road north ends as far east.
    expect(map.tileAt(const GridPoint(40, 19)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(39, 18)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(15, 6)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(16, 6)).isWalkable, isTrue);
  });

  test('no cultist zombie stands in the level: the mass raises them', () {
    final cultists = createGameWorld().entities.values.where(
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

  test('the only zombie on the street, but for the two before the '
      'barracks, waits east of the crossroads', () {
    final world = createGameWorld();
    final zombies = zombiesIn(
      world,
      place(PlaceId.street),
    ).where((zombie) => !zombie.id.startsWith('barracks-road-')).toList();
    expect(zombies, hasLength(1));
    expect(zombies.single.id, tutorialZombieId);
    final position = zombies.single.component<PositionComponent>().position;
    // Past the crossroads, close enough to be in the view wherever it
    // notices Mario from (see zombie_framing_test.dart).
    expect(position.x, greaterThan(tutorialZombieTrigger.left + 6));
  });

  String northGlyph(GridPoint point) =>
      northDistrictRows[point.y -
          place(PlaceId.northDistrict).origin.y][point.x -
          place(PlaceId.northDistrict).origin.x];

  test('two zombies wander by the fountain in the north district square', () {
    final world = createGameWorld();
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
    final world = createGameWorld();
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
    final world = createGameWorld();
    final spots = <GridPoint>[
      for (final entity in world.entities.values)
        if (entity.kind != EntityKind.player)
          entity.component<PositionComponent>().position,
      ...carabiniereSpawns,
      ...mallHordeSpawns,
    ];
    for (final spot in spots) {
      for (final region in gamePlaces) {
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
    final pickups = createGameWorld().pickups;
    expect(pickups[ammoBackpackId]!.active, isTrue);
    expect(pickups[ammoBackpackId]!.ammo, 4);
    expect(pickups[accidentBackpackId]!.active, isTrue);
    expect(pickups[accidentBackpackId]!.ammo, 2);
    final gun = pickups[gunBackpackId]!;
    expect(gun.gun, isTrue);
    expect(place(PlaceId.barracks).indoor, isTrue);
    expect(place(PlaceId.barracks).bounds.contains(gun.position), isTrue);
  });

  test('interacting with a backpack collects its content', () {
    final world = createGameWorld();
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
    expect(pickedUp.ammo, 4);
    expect(backpack.active, isFalse);
    expect(backpack.collected, isTrue);
    final ammo = world.player.component<AmmoComponent>();
    expect(ammo.loaded, 4);
    expect(ammo.hasGun, isFalse);
  });

  test('without the pistol the player cannot shoot', () {
    final world = createGameWorld();
    world.player.component<AmmoComponent>().loaded = 2;
    final events = const TurnScheduler().advance(world, const ShootAction());
    expect(events.whereType<DryFiredEvent>(), hasLength(1));
    expect(world.player.component<AmmoComponent>().loaded, 2);
  });

  test('stepping into the crossroads alerts the zombie at once', () {
    final world = createGameWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      12,
      45,
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

  test('the top sidewalk, where it turns north, is part of the crossroads: '
      'nobody slips up the road past the first zombie', () {
    final world = createGameWorld();
    // On the sidewalk, one step short of the crossroads.
    world.player.component<PositionComponent>().position = GridPoint(
      tutorialZombieTrigger.left - 1,
      tutorialZombieTrigger.top,
    );
    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.east),
    );
    expect(events.whereType<AlertedEvent>().single.entityId, tutorialZombieId);
    // Every tile a step north of the crossroads is reached from inside it.
    for (var x = 0; x < 40; x++) {
      final north = GridPoint(x, tutorialZombieTrigger.top - 1);
      final south = GridPoint(x, tutorialZombieTrigger.top);
      if (world.map.tileAt(north).isWalkable &&
          world.map.tileAt(south).isWalkable) {
        expect(tutorialZombieTrigger.contains(south), isTrue, reason: '$x');
      }
    }
  });

  test('the zombie before the barracks stands on the road north a few steps '
      'past the dead-end street, whose backpack is clear of it', () {
    final world = createGameWorld();
    final zombie = world.entities[barracksRoadZombieId]!;
    expect(zombie.kind, EntityKind.wanderer);
    final zombieTile = zombie.component<PositionComponent>().position;
    final backpack = world.pickups[alleyBackpackId]!;
    expect(backpack.ammo, 2);
    final street = place(PlaceId.street);
    final barracksDoor = street.tileOf('E');
    // The first row where the road north opens east into the street.
    final opening = <GridPoint>[
      for (var y = barracksDoor.y; y < backpack.position.y; y++)
        GridPoint(zombieTile.x + 4, y),
    ].firstWhere((tile) => world.map.tileAt(tile).isWalkable);
    expect(zombieTile.x, barracksDoor.x, reason: 'mid-road');
    expect(opening.y - zombieTile.y, inInclusiveRange(1, 4));

    bool reaches(GridPoint goal) {
      final start = world.player.component<PositionComponent>().position;
      final seen = <GridPoint>{start};
      final queue = <GridPoint>[start];
      while (queue.isNotEmpty) {
        final here = queue.removeLast();
        if (here == goal) {
          return true;
        }
        for (final direction in Direction.values) {
          final next = here.step(direction);
          if (seen.contains(next) ||
              (next != goal && !world.map.tileAt(next).isWalkable) ||
              next.manhattanDistanceTo(zombieTile) <= 1) {
            continue;
          }
          seen.add(next);
          queue.add(next);
        }
      }
      return false;
    }

    expect(reaches(backpack.position), isTrue);
    expect(backpack.position.x, greaterThan(zombieTile.x), reason: 'east');
    expect(tutorialZombieId, isNot(barracksRoadZombieId));
    expect(world.entities[tutorialZombieId]!.kind, EntityKind.wanderer);
  });

  test('a second zombie waits four rows further up the road north, east '
      'of the first, looking south', () {
    final world = createGameWorld();
    final first = world.entities[barracksRoadZombieId]!
        .component<PositionComponent>();
    final upper = world.entities[barracksRoadUpperZombieId]!;
    expect(upper.kind, EntityKind.wanderer);
    final position = upper.component<PositionComponent>();
    expect(position.position.y, first.position.y - 4);
    expect(position.position.x, greaterThan(first.position.x));
    expect(position.facing, Direction.south);
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
      final world = createGameWorld();
      final inDoor = walk(world, const GridPoint(16, 7), Direction.north);
      expect(inside(inDoor), isTrue);
      final outDoor = walk(world, inDoor, Direction.south);
      expect(outDoor, const GridPoint(16, 7));
    });

    test('the back door opens on the street of the north district', () {
      final world = createGameWorld();
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
      final world = createGameWorld();
      final harbour = gamePlaces.firstWhere(
        (region) => region.name == harbourName,
      );
      expect(harbour.cardImage, hometownCoverImage);
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
    final world = createGameWorld();
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
}
