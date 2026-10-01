import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
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

    test('five emergency lamps evenly mark the cabin aisle', () {
      final aisleRow = airlinerCabinRows.indexWhere(
        (row) => row.startsWith('xI..*'),
      );
      final lamps = cabin
          .tilesOf('*')
          .where((tile) => tile.y == cabin.origin.y + aisleRow)
          .toList();
      expect(lamps, hasLength(5));
      expect(
        <int>[
          for (var i = 1; i < lamps.length; i++) lamps[i].x - lamps[i - 1].x,
        ],
        everyElement(9),
        reason: 'the light pools continue at the existing nine-cell rhythm',
      );
      expect(
        cabin.tilesOf('+'),
        hasLength(1),
        reason: 'the damaged lamp still flickers separately',
      );
    });

    test('it lies across the crossroads, wings where the street sees '
        'them', () {
      final world = createGameWorld();
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
      final world = createGameWorld();
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
      final world = createGameWorld();
      final reached = from(
        world,
        airlinerCabinTear.first.step(Direction.north),
        cabin,
      );
      // The trolleys stand aside: the whole break is open.
      expect(
        airlinerTailBreak.where(
          (door) => reached.containsKey(door.step(Direction.north)),
        ),
        hasLength(airlinerTailBreak.length),
        reason: 'the aisle runs the length of the cabin',
      );
      expect(cabin.lights, isNotEmpty, reason: 'a room on a dark background');
    });

    test('two wanderers are left in the cabin', () {
      final world = createGameWorld();
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

      /// The one lying across the aisle.
      final guard = cabin
          .tilesOf('M')
          .singleWhere((tile) => tile.y == cabin.origin.y + 5);

      test('lie in the cabin, many of them, facing the aisle', () {
        final world = createGameWorld();
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

      test('the one lying across the aisle is passed over the broken '
          'seats, and only there', () {
        final world = createGameWorld();
        expect(mutilatedTiles(world), contains(guard));
        final exit = airlinerTailBreak.first.step(Direction.north);
        final reached = walk(world, bitesAllowed: false);
        expect(reached.contains(exit), isTrue, reason: 'no bite to get out');
        // With the broken seats as whole as the rest, he shuts the aisle.
        for (final seat in cabin.tilesOf('r')) {
          world.map.setTile(seat, const Tile(TileKind.obstacle));
        }
        expect(walk(world, bitesAllowed: false).contains(exit), isFalse);
      });

      test('the first one lies under a light, in sight of the tear', () {
        final world = createGameWorld();
        final start = airlinerCabinTear.first.step(Direction.north);
        final first = mutilatedTiles(world).reduce(
          (a, b) => a.manhattanDistanceTo(start) <= b.manhattanDistanceTo(start)
              ? a
              : b,
        );
        expect(first.manhattanDistanceTo(start), lessThanOrEqualTo(3));
        expect(
          cabin.lights.any(
            (light) => light.tile.manhattanDistanceTo(first) <= 1,
          ),
          isTrue,
        );
      });

      test('none lies in front of the tail break', () {
        final world = createGameWorld();
        for (final door in airlinerTailBreak) {
          expect(
            mutilatedTiles(world),
            isNot(contains(door.step(Direction.north))),
          );
        }
      });

      test('he can be shot from a distance, without a bite', () {
        final world = createGameWorld();
        final reached = walk(world, bitesAllowed: false, except: guard);
        final inLine = <GridPoint>[
          for (var x = guard.x - 2; x > cabin.bounds.left; x--)
            GridPoint(x, guard.y),
        ];
        final spot = inLine.firstWhere(reached.contains);
        world.player.component<PositionComponent>()
          ..position = spot
          ..facing = Direction.east;
        world.player.component<AmmoComponent>()
          ..hasGun = true
          ..loaded = 1;
        const TurnScheduler().advance(world, const ShootAction());
        expect(mutilatedTiles(world), isNot(contains(guard)));
      });

      test('all the others can be walked round without a bite, and so can '
          'the flight bag with the rounds be reached', () {
        final world = createGameWorld();
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
        expect(reached.contains(guard.step(Direction.west)), isTrue);
      });
    });

    group('the burning zombies', () {
      Entity burning(WorldState world) =>
          world.entities[rooftopBurningZombieId]!;

      test('two stand on the upper terrace, out of the corner on fire', () {
        final world = createGameWorld();
        final zombies = world.entities.values
            .where((entity) => entity.id.startsWith(rooftopBurningZombiePrefix))
            .toList();
        expect(zombies, hasLength(2));
        final corner = roofs.tilesOf('&');
        expect(corner.length, greaterThanOrEqualTo(5));
        for (final tile in corner) {
          expect(world.map.tileAt(tile).kind, TileKind.fire);
          expect(world.map.tileAt(tile).isWalkable, isFalse);
          // The north-west corner of the upper terrace, where the airliner
          // struck.
          expect(tile.y, lessThan(roofs.origin.y + 8));
          expect(tile.x, lessThan(airlinerRoofBreak.first.x));
        }
        for (final zombie in zombies) {
          expect(zombie.kind, EntityKind.burning);
          expect(zombie.component<ActorComponent>().trailsFire, isTrue);
          final at = zombie.component<PositionComponent>().position;
          expect(roofs.tilesOf('Y'), contains(at));
          expect(
            corner.any((tile) => tile.manhattanDistanceTo(at) == 1),
            isTrue,
            reason: 'it walked out of the fire',
          );
        }
      });

      test('going after Mario it leaves a trail of fire nobody crosses, and '
          'the way back to the tail stays open', () {
        final world = createGameWorld();
        final zombie = burning(world);
        final start = zombie.component<PositionComponent>().position;
        world.player.component<PositionComponent>()
          ..position = GridPoint(start.x + 5, start.y)
          ..facing = Direction.west;
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
        final world = createGameWorld();
        final tile = roofs.tilesOf('Y').first.step(Direction.east);
        world.map.setTile(tile, const Tile(TileKind.fire));
        final restored = restoreGameWorld(
          jsonDecode(jsonEncode(saveGameWorld(world))) as Map<String, Object?>,
        );
        expect(restored.map.tileAt(tile).kind, TileKind.fire);
        for (final corner in roofs.tilesOf('&')) {
          expect(restored.map.tileAt(corner).kind, TileKind.fire);
        }
      });
    });

    test('the tail break comes out on the roofs, and goes back in', () {
      final world = createGameWorld();
      final roof = travel(world, airlinerTailBreak.first, Direction.south);
      expect(roofs.bounds.contains(roof), isTrue);
      expect(roof, airlinerRoofBreak.first.step(Direction.south));

      final back = travel(world, airlinerRoofBreak.first, Direction.north);
      expect(cabin.bounds.contains(back), isTrue);
      expect(back, airlinerTailBreak.first.step(Direction.north));
    });

    test('a backpack with two rounds waits in the south-east corner of '
        'the first roof after the airliner', () {
      final world = createGameWorld();
      final backpack = world.pickups[rooftopBackpackId]!;
      expect(backpack.ammo, rooftopBackpackAmmo);
      expect(backpack.position, rooftopBackpackTile);
      expect(roofs.bounds.contains(backpack.position), isTrue);
      expect(
        backpack.position.x,
        greaterThan((roofs.bounds.left + roofs.bounds.right) ~/ 2),
      );
      expect(
        backpack.position.y,
        greaterThan((roofs.bounds.top + roofs.bounds.bottom) ~/ 2),
      );

      final reached = from(
        world,
        airlinerRoofBreak.first.step(Direction.south),
        roofs,
      );
      expect(
        Direction.values.map(backpack.position.step).any(reached.containsKey),
        isTrue,
        reason: 'Mario can stand beside it to collect it',
      );
    });

    test('the roofs end at the gap, which can only be looked at', () {
      final world = createGameWorld();
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
      // reach from here, though it can be walked on, down its stairs too.
      final farRoof = <GridPoint>[...roofs.tilesOf('%'), ...roofs.tilesOf('S')];
      expect(roofs.tilesOf('S'), isNotEmpty);
      for (final tile in farRoof) {
        expect(reached.containsKey(tile), isFalse);
        expect(world.map.tileAt(tile).isWalkable, isTrue);
      }
      for (final tile in reached.keys) {
        expect(roofs.bounds.contains(tile), isTrue);
      }
    });

    test('looking at the gap says what it would take to cross it', () {
      final world = createGameWorld();
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
}
