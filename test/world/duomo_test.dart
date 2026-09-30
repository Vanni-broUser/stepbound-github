import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('Duomo', () {
    test('torches burn on every column and behind the altar, and light the '
        'nave', () {
      final duomo = place(PlaceId.duomo);
      final columns = duomo.tilesOf('P').toSet();
      final torches = duomo.torches.toSet();
      final onColumns = torches.intersection(columns);
      expect(onColumns, hasLength(8), reason: 'one on each column');
      final middleX = duomo.origin.x + duomo.width / 2;
      for (final torch in onColumns) {
        // On the side of the shaft facing the central nave.
        final inward = torch.x < middleX ? Direction.east : Direction.west;
        expect(columns.contains(torch.step(inward)), isFalse);
      }
      final altar = duomo.tilesOf('A');
      final altarTop = altar.map((tile) => tile.y).reduce(math.min);
      final behind = torches.difference(columns);
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
      final world = createGameWorld();
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
      expect(duomo.tilesOf('T'), hasLength(greaterThanOrEqualTo(30)));

      // Every column and every statue is a block of two tiles by two, with
      // room to walk round it.
      void blocksOfFour(String glyph, int count) {
        final tiles = duomo.tilesOf(glyph).toSet();
        expect(tiles, hasLength(4 * count), reason: glyph);
        for (final corner in tiles.where(
          (tile) =>
              !tiles.contains(tile.step(Direction.west)) &&
              !tiles.contains(tile.step(Direction.north)),
        )) {
          expect(
            <GridPoint>{
              corner,
              corner.step(Direction.east),
              corner.step(Direction.south),
              corner.step(Direction.east).step(Direction.south),
            }.every(tiles.contains),
            isTrue,
            reason: '$glyph at $corner is not two by two',
          );
        }
      }

      blocksOfFour('P', 8);
      // Six statues, each a different saint.
      for (final saint in 'MKFVYG'.split('')) {
        blocksOfFour(saint, 1);
      }

      final columnXs = duomo.tilesOf('P').map((tile) => tile.x).toSet().toList()
        ..sort();
      expect(
        columnXs,
        hasLength(4),
        reason: 'two colonnades, two tiles thick, make three naves',
      );
      expect(
        duomo
            .tilesOf('T')
            .every((pew) => pew.x > columnXs[1] && pew.x < columnXs[2]),
        isTrue,
        reason: 'the pews belong to the central nave',
      );

      // No stairs in the nave any more: one door in the back wall, in the
      // north-east corner, with the cultist straight in front of it.
      final door = duomo.tileOf('U');
      expect(door.x, greaterThan(duomo.bounds.left + duomo.width * 2 ~/ 3));
      expect(door.y, lessThan(duomo.bounds.top + duomo.height ~/ 3));
      expect(duomoStairCultistTile, door.step(Direction.south));
    });

    test('the door upstairs is reached only through the tile in front of '
        'it, whoever stands there', () {
      final world = createGameWorld();
      final door = duomoStairEntryTile;
      for (final side in <Direction>[
        Direction.north,
        Direction.east,
        Direction.west,
      ]) {
        expect(
          world.map.tileAt(door.step(side)).isWalkable,
          isFalse,
          reason: 'the door has wall on its $side side',
        );
      }
      expect(
        world.map.tileAt(duomoStairCultistTile).isWalkable,
        isFalse,
        reason: 'the cultist stands in the way until the ring',
      );
      final reached = world.map.floodFillDistances(
        duomo.tileOf('E').step(Direction.north),
        maxDistance: duomo.width * duomo.height,
      );
      expect(reached.containsKey(door), isFalse);
    });

    test(
      'the open portal is initially reachable only after opening the gate',
      () {
        final world = createGameWorld();
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
      final world = createGameWorld();
      expect(upper.indoor, isTrue);
      expect(upper.tilesOf('T'), hasLength(greaterThanOrEqualTo(20)));
      expect(upper.tilesOf('C'), hasLength(greaterThanOrEqualTo(20)));
      expect(upper.tilesOf('B'), hasLength(greaterThanOrEqualTo(24)));
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
        upper.tilesOf('T').every((tile) => tile.x > upper.tileOf('d').x),
        isTrue,
      );
      expect(
        upper.tilesOf('B').every((tile) => tile.x < upper.tileOf('d').x),
        isTrue,
      );

      // A real kitchen on the refectory side: counters, hearth, sink.
      for (final glyph in <String>['k', 'F', 'H']) {
        expect(
          upper.tilesOf(glyph).every((tile) => tile.x > upper.tileOf('d').x),
          isTrue,
          reason: glyph,
        );
      }
      // Every bed is two cells long with its night table beside its head,
      // and no bed touches another.
      final beds = upper.tilesOf('B').toSet();
      final heads = beds.where((b) => !beds.contains(b.step(Direction.north)));
      expect(heads, hasLength(12));
      for (final head in heads) {
        expect(beds, contains(head.step(Direction.south)));
        expect(upper.tilesOf('n'), contains(head.step(Direction.east)));
        for (final other in heads.where((h) => h != head)) {
          expect(
            (other.x - head.x).abs() > 1 || (other.y - head.y).abs() > 2,
            isTrue,
            reason: 'beds at $head and $other touch',
          );
        }
      }
      expect(upper.tilesOf('A'), hasLength(greaterThanOrEqualTo(2)));
    });

    test('the guarded door opens onto the upper floor and returns', () {
      final world = createGameWorld();
      final upper = place(PlaceId.duomoUpper);
      expect(world.map.tileAt(duomoStairEntryTile).isWalkable, isTrue);
      expect(world.map.tileAt(duomoStairCultistTile).isWalkable, isFalse);
      expect(world.map.tileAt(duomoUpperLockedDoorTile).isWalkable, isFalse);
      expect(
        world.portals[duomoStairEntryTile]!.to,
        duomoUpperStairTile.step(Direction.north),
      );
      expect(
        world.portals[duomoUpperStairTile]!.to,
        duomoStairEntryTile.step(Direction.south),
      );

      world.map.setTile(duomoStairCultistTile, const Tile(TileKind.floor));
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
        final world = createGameWorld();
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

    test('the four cultists close both ends of the aisle, looking out of '
        'it', () {
      final world = createGameWorld();
      final wall = duomoCultistSpawns.toSet();
      expect(wall, hasLength(4));
      // Two pairs, each two deep: the aisle is two tiles tall, so each pair
      // closes it from wall of pews to wall of pews.
      final rows = wall.map((tile) => tile.y).toSet();
      final columns = wall.map((tile) => tile.x).toSet().toList()..sort();
      expect(rows, hasLength(2));
      expect(columns, hasLength(2));
      expect(rows.contains(duomoKeyTile.y), isTrue);
      expect(rows.contains(duomoPriestCorpseTile.y), isTrue);
      final pews = duomo.tilesOf('T').map((tile) => tile.x);
      expect(columns.first, pews.reduce(math.min) - 1, reason: 'west end');
      expect(columns.last, greaterThan(duomoKeyTile.x), reason: 'east end');
      expect(
        columns.last,
        lessThan(duomoStairEntryTile.x),
        reason: 'the stair is further east still',
      );
      for (final tile in wall) {
        expect(world.map.tileAt(tile).isWalkable, isTrue, reason: 'floor');
        expect(world.entityAt(tile), isNull, reason: 'nobody there yet');
        expect(
          createDuomoCultist('c', tile).component<PositionComponent>().facing,
          tile.x == columns.first ? Direction.west : Direction.east,
        );
      }
    });

    test('the key of the upper floor waits, hidden, beside the body', () {
      final world = createGameWorld();
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

    test('their two pairs shut the aisle off at both ends: the key is only '
        'reached past one of them', () {
      final world = createGameWorld();
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
      final west = duomoKeyTile.step(Direction.west);
      expect(
        blocked,
        isNot(anyOf(contains(east), contains(west))),
        reason: 'the two pairs shut the aisle at both ends',
      );
      final open = walkFromTheStair(cultistsThere: false);
      expect(open, contains(east), reason: 'once they move, it opens again');
      expect(open, contains(west));
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
    });
  });
}
