import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('harbour', () {
    final harbour = place(PlaceId.harbour);
    GridPoint at(int x, int y) =>
        GridPoint(harbour.origin.x + x, harbour.origin.y + y);
    String glyph(int x, int y) => harbourRows[y][x];

    test('the promenade ends at the parapet over the sea, round the corner '
        'too, jutting out square at it, but for the two piers', () {
      final map = createGameWorld().map;
      void wall(int x, int y) {
        expect(map.tileAt(at(x, y)).isWalkable, isFalse, reason: '$x,$y');
        expect(map.tileAt(at(x, y)).blocksSight, isFalse, reason: '$x,$y');
      }

      final parapet = harbourRows.indexWhere((row) => row.startsWith('R'));
      final end = harbourRows[parapet].lastIndexOf('R');
      for (var x = 0; x <= end; x++) {
        if (glyph(x, parapet) == 'l') {
          continue; // the shipyard's slipway runs down through it
        }
        wall(x, parapet);
      }
      // By the corner the paving juts out square into the sea: the
      // parapet turns south, runs down its west side, turns east at its
      // point, along its south side, and turns south again onto the one
      // along the road.
      var x = end + 1;
      var y = parapet;
      expect(glyph(x, y), 'ò', reason: 'turning south, inside');
      wall(x, y);
      for (y++; glyph(x, y) == 'R'; y++) {
        wall(x, y);
        expect(glyph(x - 1, y), '~', reason: 'the sea west, row $y');
      }
      expect(glyph(x, y), 'ó', reason: 'the point');
      wall(x, y);
      for (x++; glyph(x, y) == 'R'; x++) {
        wall(x, y);
        expect(glyph(x, y + 1), '~', reason: 'the sea south, column $x');
      }
      expect(glyph(x, y), 'ò', reason: 'back onto the road, inside');
      wall(x, y);
      final corner = x;
      expect(corner - end, greaterThanOrEqualTo(4), reason: 'room for it');
      y++;

      // The newsstand on it, with a cell of paving all the way round.
      final stand = <GridPoint>[
        for (var sy = 0; sy < harbourRows.length; sy++)
          for (var sx = 0; sx < harbourRows[sy].length; sx++)
            if (glyph(sx, sy) == 'ê') GridPoint(sx, sy),
      ];
      expect(stand, hasLength(6));
      final left = stand.map((t) => t.x).reduce((a, b) => a < b ? a : b);
      final right = stand.map((t) => t.x).reduce((a, b) => a > b ? a : b);
      final top = stand.map((t) => t.y).reduce((a, b) => a < b ? a : b);
      final bottom = stand.map((t) => t.y).reduce((a, b) => a > b ? a : b);
      expect(left, greaterThan(end + 1));
      expect(right, lessThan(corner));
      for (var ry = top - 1; ry <= bottom + 1; ry++) {
        for (var rx = left - 1; rx <= right + 1; rx++) {
          if (rx < left || rx > right || ry < top || ry > bottom) {
            expect(
              map.tileAt(at(rx, ry)).isWalkable,
              isTrue,
              reason: 'the way round it, $rx,$ry',
            );
          }
        }
      }
      var piers = 0;
      for (; glyph(corner, y) != 'B'; y++) {
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
      final world = createGameWorld();
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

    test('a rowboat moored at the second pier holds two rounds', () {
      final world = createGameWorld();
      final boat = world.pickups[boatBackpackId]!;
      expect(boat.ammo, 2);
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

    test('two-round backpacks replace the shipyard fire and wait at the '
        'rightmost old-town dead end', () {
      final world = createGameWorld();
      final shipyard = world.pickups[shipyardBackpackId]!;
      final oldTown = world.pickups[oldTownBackpackId]!;

      expect(shipyard.position, shipyardBackpackTile);
      expect(shipyard.ammo, 2);
      expect(oldTown.position, oldTownBackpackTile);
      expect(oldTown.ammo, 2);
      expect(world.campfires, isNot(contains(shipyardBackpackTile)));

      final localOldTown = GridPoint(
        oldTown.position.x - harbour.origin.x,
        oldTown.position.y - harbour.origin.y,
      );
      expect(
        harbourRows[localOldTown.y - 1][localOldTown.x],
        // A front, its damaged door shut.
        'Ħ',
        reason: 'the backpack is at the shut northern end of the alley',
      );
      expect(harbourRows[localOldTown.y + 1][localOldTown.x], 'P');
    });

    test('one fire is gated on the Duomo sagrato and one waits at the '
        'south-east end of the harbour road', () {
      final world = createGameWorld();
      expect(campfireNames[duomoCampfireTile], 'Sagrato del Duomo');
      expect(campfireNames[harbourRoadCampfireTile], 'Fine del porto');
      expect(
        world.campfires.where(harbour.bounds.contains),
        unorderedEquals(<GridPoint>[
          duomoCampfireTile,
          harbourRoadCampfireTile,
        ]),
      );

      Map<GridPoint, int> fromOutside() => world.map.floodFillDistances(
        priestGateTiles[1].step(Direction.south),
        maxDistance: harbour.width * harbour.height,
      );
      bool reachesDuomoFire(Map<GridPoint, int> reached) =>
          Direction.values.map(duomoCampfireTile.step).any(reached.containsKey);
      expect(
        reachesDuomoFire(fromOutside()),
        isFalse,
        reason: 'the closed gate keeps the first fire out of reach',
      );
      for (final tile in priestGateTiles) {
        world.map.setTile(tile, const Tile(TileKind.floor));
      }
      expect(
        reachesDuomoFire(fromOutside()),
        isTrue,
        reason: 'delivering the incense opens the way to the fire',
      );

      final localRoad = GridPoint(
        harbourRoadCampfireTile.x - harbour.origin.x,
        harbourRoadCampfireTile.y - harbour.origin.y,
      );
      expect(harbourRows[localRoad.y].indexOf('ç'), greaterThan(localRoad.x));
      expect(localRoad.y, greaterThan(harbour.height - 10));
    });

    test("the harbour road stops short of the quay, where the children's "
        'carousel stands and the last fire burns beside it', () {
      final world = createGameWorld();
      final carousel = harbour.tilesOf('ç');
      expect(carousel, hasLength(15), reason: 'five cells by three');
      for (final tile in carousel) {
        expect(world.map.tileAt(tile).kind, TileKind.obstacle);
      }
      final fire = harbourRoadCampfireTile;
      final nearest = carousel
          .map((tile) => (tile.x - fire.x).abs() + (tile.y - fire.y).abs())
          .reduce((a, b) => a < b ? a : b);
      expect(nearest, lessThanOrEqualTo(2), reason: 'the fire is beside it');
      final column = carousel.first.x - harbour.origin.x;
      final top = carousel.first.y - harbour.origin.y;
      for (var y = top - 1; y < harbourRows.length; y++) {
        expect(
          harbourRows[y][column],
          isNot('.'),
          reason: 'no tarmac between the end of the road and the quay',
        );
      }
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
      final world = createGameWorld();
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
      final world = createGameWorld();
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
      final fountain = <GridPoint>[
        for (final tile in tilesOf('!'))
          if (tile.x < duomoX) tile,
      ];
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

    test('east of the road down to the carousel two old-town alleys leave '
        'the road and meet again at a fountain, blind alleys off them', () {
      final world = createGameWorld();
      final sidewalk = harbourRows[harbourRows.length - 10].lastIndexOf('=');
      // The alleys open where the road's east sidewalk meets the paving.
      final mouths = <int>[
        for (var y = 0; y < harbourRows.length; y++)
          if (glyph(sidewalk, y) == '=' &&
              glyph(sidewalk + 1, y) == 'P' &&
              glyph(sidewalk + 1, y - 1) != 'P')
            y,
      ];
      expect(mouths, hasLength(2), reason: 'two alleys off the road');

      // Walking the paving east of the road, from one mouth the other is
      // reached without going back onto the road.
      final start = at(sidewalk + 1, mouths.first);
      final seen = <GridPoint>{start};
      final queue = <GridPoint>[start];
      while (queue.isNotEmpty) {
        final here = queue.removeLast();
        for (final direction in Direction.values) {
          final next = here.step(direction);
          final local = GridPoint(
            next.x - harbour.origin.x,
            next.y - harbour.origin.y,
          );
          if (local.x > sidewalk &&
              local.x < harbour.width &&
              !seen.contains(next) &&
              world.map.tileAt(next).isWalkable) {
            seen.add(next);
            queue.add(next);
          }
        }
      }
      expect(seen, contains(at(sidewalk + 1, mouths.last)));

      // The fountain and its flower beds are on the way round.
      bool beside(String wanted) => seen.any(
        (tile) => Direction.values.any((direction) {
          final next = tile.step(direction);
          return glyph(next.x - harbour.origin.x, next.y - harbour.origin.y) ==
              wanted;
        }),
      );
      expect(beside('!'), isTrue, reason: 'a fountain on the way');
      expect(beside('&'), isTrue, reason: 'flower beds by it');

      // Blind alleys, two cells wide: the pair at their end is shut ahead
      // and on either side, open only back the way it came.
      bool open(GridPoint tile) => world.map.tileAt(tile).isWalkable;
      var deadEnds = 0;
      for (final a in seen) {
        for (final ahead in Direction.values) {
          final side = Direction.values.firstWhere(
            (d) => d.dx == ahead.dy.abs() && d.dy == ahead.dx.abs(),
          );
          final b = a.step(side);
          if (seen.contains(b) &&
              !open(a.step(ahead)) &&
              !open(b.step(ahead)) &&
              !open(a.step(side.opposite)) &&
              !open(b.step(side)) &&
              seen.contains(a.step(ahead.opposite)) &&
              seen.contains(b.step(ahead.opposite))) {
            deadEnds++;
          }
        }
      }
      expect(deadEnds, greaterThanOrEqualTo(3));
      // The east edge of the map stays built over: no way off it.
      for (var y = 0; y < harbourRows.length; y++) {
        expect(glyph(harbour.width - 1, y), 'B');
      }
    });

    test('the Duomo stands back from the road: a two-cell alley climbs to '
        'its gate, then opens into the T of the sagrato', () {
      final world = createGameWorld();
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
      final world = createGameWorld();
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
      final world = createGameWorld();
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
}
