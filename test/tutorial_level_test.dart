import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('every row of each place has the same width', () {
    for (final rows in <List<String>>[
      streetLevelRows,
      northDistrictRows,
      harbourRows,
      barracksRows,
    ]) {
      final width = rows.first.length;
      expect(rows.every((row) => row.length == width), isTrue);
    }
  });

  test('the player starts unarmed with no bullets', () {
    final ammo = createTutorialWorld().player.component<AmmoComponent>();
    expect(ammo.hasGun, isFalse);
    expect(ammo.loaded, 0);
    expect(ammo.reserve, 0);
  });

  test('the crossroads opens north and east but not south', () {
    final map = createTutorialWorld().map;
    expect(map.tileAt(const GridPoint(16, 30)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(30, 46)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(16, 50)).isWalkable, isFalse);
  });

  test('the streets end against buildings, the north one at the barracks', () {
    final map = createTutorialWorld().map;
    expect(map.tileAt(const GridPoint(3, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(40, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(15, 16)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(16, 16)).isWalkable, isTrue);
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
      final inDoor = walk(world, const GridPoint(16, 17), Direction.north);
      expect(inside(inDoor), isTrue);
      final outDoor = walk(world, inDoor, Direction.south);
      expect(outDoor, const GridPoint(16, 17));
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
      final up = GridPoint(
        place(PlaceId.mallGround).origin.x + mallGroundRows[2].indexOf('U'),
        place(PlaceId.mallGround).origin.y + 2,
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

  test('the harbour ends at the parapet over the sea', () {
    final map = createTutorialWorld().map;
    final parapet = harbourRows.indexWhere((row) => row.startsWith('R'));
    for (var x = 0; x < harbourRows.first.length; x++) {
      final below = GridPoint(
        place(PlaceId.harbour).origin.x + x,
        place(PlaceId.harbour).origin.y + parapet,
      );
      expect(map.tileAt(below).isWalkable, isFalse);
      expect(map.tileAt(below).blocksSight, isFalse);
    }
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
    world.entities[carabiniere.id] = carabiniere;
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

  test(
    'fires burn on the street, in the north district and at the harbour',
    () {
      int count(List<FireSpot> spots, FireKind kind) =>
          spots.where((s) => s.kind == kind).length;
      final street = streetFireSpots;
      expect(count(street, FireKind.car), 2);
      expect(count(street, FireKind.bin), 2);
      expect(count(street, FireKind.window), 3);
      final all = outdoorFireSpots;
      expect(count(all, FireKind.car), 7);
      expect(count(all, FireKind.bin), 8);
      expect(count(all, FireKind.window), 11);
      expect(count(all, FireKind.campfire), 1);
      final north = place(PlaceId.northDistrict).bounds;
      expect(
        all
            .where((spot) => spot.kind == FireKind.campfire)
            .every((spot) => north.contains(spot.tile)),
        isTrue,
      );
    },
  );

  test('the camp burns at the closed east end of the north street', () {
    final world = createTutorialWorld();
    final camp = world.campfires.single;
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
    final camp = world.campfires.single;
    expect(campfireNames[camp], 'Accampamento dietro la caserma');
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
