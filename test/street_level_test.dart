import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('every street and barracks row has the same width', () {
    for (final rows in <List<String>>[streetLevelRows, barracksRows]) {
      final width = rows.first.length;
      expect(rows.every((row) => row.length == width), isTrue);
    }
  });

  test('the player starts unarmed with no bullets', () {
    final ammo = createStreetWorld().player.component<AmmoComponent>();
    expect(ammo.hasGun, isFalse);
    expect(ammo.loaded, 0);
    expect(ammo.reserve, 0);
  });

  test('the crossroads opens north and east but not south', () {
    final map = createStreetWorld().map;
    expect(map.tileAt(const GridPoint(16, 30)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(30, 46)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(16, 50)).isWalkable, isFalse);
  });

  test('the streets end against buildings, the north one at the barracks', () {
    final map = createStreetWorld().map;
    expect(map.tileAt(const GridPoint(3, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(40, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(15, 16)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(16, 16)).isWalkable, isTrue);
  });

  List<Entity> zombiesIn(WorldState world, LevelRegion region) => world
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
    final world = createStreetWorld();
    final zombies = zombiesIn(world, levelRegions.first);
    expect(zombies, hasLength(1));
    expect(zombies.single.id, tutorialZombieId);
    final position = zombies.single.component<PositionComponent>().position;
    // The view is 24 tiles wide and starts clamped to the west end.
    expect(position.x, greaterThanOrEqualTo(24));
  });

  String northGlyph(GridPoint point) =>
      northDistrictRows[point.y - northDistrictOrigin.y][point.x -
          northDistrictOrigin.x];

  test('two zombies wander by the fountain in the north district square', () {
    final world = createStreetWorld();
    final byFountain = zombiesIn(world, levelRegions[1]).where((zombie) {
      final position = zombie.component<PositionComponent>().position;
      return Direction.values.any(
        (direction) => northGlyph(position.step(direction)) == 'O',
      );
    });
    expect(byFountain, hasLength(2));
  });

  test('hordes too many to fight block the way to the hospital', () {
    final world = createStreetWorld();
    // The square, in the north district's own tiles.
    final square = GridRect(
      northDistrictOrigin.x + 38,
      northDistrictOrigin.y + 30,
      northDistrictOrigin.x + 58,
      northDistrictOrigin.y + 42,
    );
    final hordes = zombiesIn(world, levelRegions[1]).where(
      (zombie) =>
          zombie.component<PositionComponent>().position.x < square.left,
    );
    expect(hordes.length, greaterThanOrEqualTo(30));
    expect(
      hordes.map((zombie) => zombie.kind).toSet(),
      containsAll(<EntityKind>[
        EntityKind.wanderer,
        EntityKind.sprinter,
        EntityKind.brute,
      ]),
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
          levelRegions[1].bounds.contains(tile) && northGlyph(tile) == 'G',
    );
    expect(hospital, isEmpty);
  });

  test('zombies are beyond the simulation radius of the other places', () {
    final world = createStreetWorld();
    final spots = <GridPoint>[
      for (final entity in world.entities.values)
        if (entity.kind != EntityKind.player)
          entity.component<PositionComponent>().position,
      ...carabiniereSpawns(),
    ];
    for (final spot in spots) {
      for (final region in levelRegions) {
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
    final pickups = createStreetWorld().pickups;
    expect(pickups[ammoBackpackId]!.active, isTrue);
    expect(pickups[ammoBackpackId]!.ammo, 2);
    expect(pickups[accidentBackpackId]!.active, isTrue);
    expect(pickups[accidentBackpackId]!.ammo, 4);
    final gun = pickups[gunBackpackId]!;
    expect(gun.gun, isTrue);
    expect(levelRegions.last.indoor, isTrue);
    expect(levelRegions.last.bounds.contains(gun.position), isTrue);
  });

  test('interacting with a backpack collects its content', () {
    final world = createStreetWorld();
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
    final world = createStreetWorld();
    world.player.component<AmmoComponent>().loaded = 2;
    final events = const TurnScheduler().advance(world, const ShootAction());
    expect(events.whereType<DryFiredEvent>(), hasLength(1));
    expect(world.player.component<AmmoComponent>().loaded, 2);
  });

  test('stepping into the crossroads alerts the zombie at once', () {
    final world = createStreetWorld();
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

    bool inside(GridPoint tile) => levelRegions.last.bounds.contains(tile);

    test('the front door leads inside the barracks and back out', () {
      final world = createStreetWorld();
      final inDoor = walk(world, const GridPoint(16, 17), Direction.north);
      expect(inside(inDoor), isTrue);
      final outDoor = walk(world, inDoor, Direction.south);
      expect(outDoor, const GridPoint(16, 17));
    });

    test('the back door opens on the street of the north district', () {
      final world = createStreetWorld();
      final backDoor = world.portals.keys.firstWhere(
        (tile) => inside(tile) && tile.y == barracksOrigin.y + 2,
      );
      final out = walk(world, backDoor.step(Direction.south), Direction.north);
      expect(levelRegions[1].bounds.contains(out), isTrue);
      expect(world.map.tileAt(out).isWalkable, isTrue);
      final back = walk(world, out, Direction.south);
      expect(back, backDoor.step(Direction.south));
    });
  });

  test('the barracks has lamps and two carabinieri waiting in the dark', () {
    expect(barracksLights(), isNotEmpty);
    expect(barracksLights().where((light) => light.flickers), isNotEmpty);
    expect(carabiniereSpawns(), hasLength(2));
    final world = createStreetWorld();
    for (final spawn in carabiniereSpawns()) {
      expect(world.map.tileAt(spawn).isWalkable, isTrue);
    }
  });

  test('the carabiniere in the middle steps south into the lamp light', () {
    final world = createStreetWorld();
    // Mario a few steps past the front door, where the carabinieri come out.
    world.player.component<PositionComponent>().position = GridPoint(
      barracksOrigin.x + 10,
      barracksOrigin.y + 11,
    );
    final spawn = carabiniereSpawns().firstWhere(
      (tile) => tile.x == barracksOrigin.x + 10,
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
    bool lit(GridPoint tile) => barracksLights().any(
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

  test('fires burn on the street and in the north district', () {
    int count(List<FireSpot> spots, FireKind kind) =>
        spots.where((s) => s.kind == kind).length;
    final street = streetFireSpots();
    expect(count(street, FireKind.car), 2);
    expect(count(street, FireKind.bin), 2);
    expect(count(street, FireKind.window), 3);
    final all = outdoorFireSpots();
    expect(count(all, FireKind.car), 6);
    expect(count(all, FireKind.bin), 5);
    expect(count(all, FireKind.window), 8);
    expect(count(all, FireKind.campfire), 1);
    final north = levelRegions[1].bounds;
    expect(
      all
          .where((spot) => spot.kind == FireKind.campfire)
          .every((spot) => north.contains(spot.tile)),
      isTrue,
    );
  });

  test('the camp burns at the closed east end of the north street', () {
    final world = createStreetWorld();
    final camp = world.campfires.single;
    final (x, y) = (
      camp.x - northDistrictOrigin.x,
      camp.y - northDistrictOrigin.y,
    );
    final row = northDistrictRows[y];
    expect(row.indexOf('B', x), lessThan(x + 4), reason: 'a dead end');
    expect(x, greaterThan(_outdoorColumn('e')), reason: 'past the barracks');
  });

  test('the flagpole stands on the barracks forecourt', () {
    final pole = flagpoleTile();
    expect(barracksForecourt.contains(pole), isTrue);
    expect(createStreetWorld().map.tileAt(pole).isWalkable, isFalse);
  });

  test('resting at the camp beyond the barracks asks the game to save', () {
    final world = createStreetWorld();
    final camp = world.campfires.single;
    expect(campfireNames()[camp], 'Accampamento dietro la caserma');
    expect(world.map.tileAt(camp).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = camp.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<CampfireUsedEvent>().single.at, camp);
  });

  test('a save from before the north district is moved onto it', () {
    final old = createStreetWorld().toJson();
    // The old layout: a smaller map, the camp on the street behind the
    // barracks and Mario resting beside it.
    old['map'] = TileMap(
      width: 106,
      height: 52,
      tiles: List<Tile>.filled(106 * 52, const Tile(TileKind.floor)),
    ).toJson();
    old['campfires'] = <Object?>[const GridPoint(21, 7).toJson()];
    final entities = (old['entities']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .where((entity) => entity['id'] == 'player')
        .toList();
    old['entities'] = entities;

    final world = restoreStreetWorld(
      jsonDecode(jsonEncode(old)) as Map<String, Object?>,
    );
    final current = createStreetWorld();
    expect(world.map.width, current.map.width);
    expect(world.campfires, current.campfires);
    final position = world.player.component<PositionComponent>();
    expect(world.map.tileAt(position.position).isWalkable, isTrue);
    expect(
      position.position.step(position.facing),
      world.campfires.single,
      reason: 'Mario faces the camp he rested at',
    );
    expect(world.entities.keys, unorderedEquals(current.entities.keys));
  });

  test('a save on the current layout is resumed as it was', () {
    final world = createStreetWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      30,
    );
    final restored = restoreStreetWorld(
      jsonDecode(jsonEncode(world.toJson())) as Map<String, Object?>,
    );
    expect(
      restored.player.component<PositionComponent>().position,
      const GridPoint(16, 30),
    );
  });

  test('the whole world survives a save and a load', () {
    final world = createStreetWorld();
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
