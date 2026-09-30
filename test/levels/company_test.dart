import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final company = place(PlaceId.companyGround);
  final street = place(PlaceId.industryStreet);

  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  /// Steps Mario from [at] onto the door [door] next to it, and returns
  /// where the door takes him.
  GridPoint through(WorldState world, GridPoint at, GridPoint door) {
    world.player.component<PositionComponent>().position = at;
    final direction = Direction.values.firstWhere(
      (direction) => at.step(direction) == door,
    );
    final events = const TurnScheduler().advance(world, MoveAction(direction));
    expect(events.whereType<TeleportedEvent>(), hasLength(1), reason: '$door');
    return mario(world);
  }

  /// Every walkable tile of the company reached from [from].
  Map<GridPoint, int> reachedFrom(WorldState world, GridPoint from) =>
      world.map.floodFillDistances(from, maxDistance: 5000);

  test('the gate, rolled up, takes Mario from the street into the west '
      'wing and back out, all four tiles of it', () {
    final world = createGameWorld();
    expect(industryStreetGate, hasLength(4));
    expect(companyGate, hasLength(4));
    for (final (index, gate) in industryStreetGate.indexed) {
      final inside = through(world, gate.step(Direction.south), gate);
      expect(inside, companyGate[index].step(Direction.north));
      expect(placeAt(inside), company);
      expect(companyWestWing.contains(inside), isTrue);
      final outside = through(world, inside, companyGate[index]);
      expect(outside, gate.step(Direction.south));
      expect(placeAt(outside), street);
    }
  });

  test('the whole west wing is walked from the gate, the east wing is '
      'not: the glass is between them, and the heap across the corridor '
      'closes the top of the U', () {
    final world = createGameWorld();
    final inside = companyGate.first.step(Direction.north);
    final reached = reachedFrom(world, inside);
    final east = reachedFrom(world, companyStairs.last.step(Direction.south));
    for (final (tile, _) in company.glyphs) {
      if (!world.map.tileAt(tile).isWalkable ||
          world.portals.containsKey(tile) ||
          workInProgressDoors.contains(tile)) {
        continue;
      }
      if (companyWestWing.contains(tile)) {
        expect(reached.containsKey(tile), isTrue, reason: '$tile shut off');
      } else {
        expect(reached.containsKey(tile), isFalse, reason: '$tile reached');
        expect(east.containsKey(tile), isTrue, reason: '$tile shut off');
      }
    }
    // The corridor runs over both wings, and the heap is in the middle of
    // it, where the glass wall begins.
    final glass = company.tilesOf('G');
    final heap = company.tilesOf('r');
    expect(heap.any((tile) => tile.x < glass.first.x), isTrue);
    expect(heap.any((tile) => tile.x > glass.first.x), isTrue);
    expect(
      reached.containsKey(companyStairs.first.step(Direction.south)),
      isTrue,
    );
    expect(
      reached.containsKey(companyStairs.last.step(Direction.south)),
      isFalse,
    );
  });

  test('from the gate the east wing is right there across the glass', () {
    // The view is 24 tiles across: the gate stands close enough to the
    // glass for the east wing to be in it as Mario walks in.
    final glass = company.tilesOf('G').first.x;
    for (final gate in companyGate) {
      expect(glass - gate.x, inInclusiveRange(1, 6));
    }
    expect(chiaraTile.x - companyGate.first.x, lessThan(12));
  });

  test('the way round: up the west side to the top floor, across it, and '
      'down the east side into the east wing, where Chiara is', () {
    final world = createGameWorld();
    for (final entity in world.entities.values) {
      if (entity.kind != EntityKind.player) {
        entity.component<HealthComponent>().current = 0;
      }
    }
    final first = place(PlaceId.companyFirst);
    final second = place(PlaceId.companySecond);
    expect(companyFlights, hasLength(4));
    for (final (below, above) in companyFlights) {
      expect(workInProgressDoors, isNot(contains(below)));
      final up = through(world, below.step(Direction.south), below);
      expect(up, above.step(Direction.north));
      final down = through(world, up, above);
      expect(down, below.step(Direction.south));
    }
    GridPoint landing(GridPoint flight) => flight.step(
      placeAt(flight) == company || companyFlights.any((f) => f.$1 == flight)
          ? Direction.south
          : Direction.north,
    );
    // On the first floor the two halves never meet: the heap is in the
    // doorway between them.
    final (westUp, westFirst) = companyFlights[0];
    final (eastUp, eastFirst) = companyFlights[1];
    final (firstWestUp, secondWest) = companyFlights[2];
    final (firstEastUp, secondEast) = companyFlights[3];
    expect(placeAt(westFirst), first);
    expect(placeAt(secondWest), second);
    final westHalf = reachedFrom(world, landing(westFirst));
    expect(westHalf.containsKey(landing(firstWestUp)), isTrue);
    expect(westHalf.containsKey(landing(eastFirst)), isFalse);
    expect(westHalf.containsKey(landing(firstEastUp)), isFalse);
    final eastHalf = reachedFrom(world, landing(eastFirst));
    expect(eastHalf.containsKey(landing(firstEastUp)), isTrue);
    // The top floor joins them.
    expect(
      reachedFrom(world, landing(secondWest)).containsKey(landing(secondEast)),
      isTrue,
    );
    // And the east flight comes down by Chiara.
    expect(companyEastWing.contains(landing(eastUp)), isTrue);
    expect(companyWestWing.contains(landing(westUp)), isTrue);
    final byChiara = reachedFrom(world, landing(eastUp));
    expect(
      Direction.values.any(
        (side) => byChiara.containsKey(chiaraTile.step(side)),
      ),
      isTrue,
    );
  });

  test('the operators sit at their desks, each on a cord to it, none in '
      'the west wing of the ground floor, two in the east one out of sight '
      'from it', () {
    final world = createGameWorld();
    final callers = world.entities.values
        .where((entity) => entity.kind == EntityKind.callCenter)
        .toList();
    expect(callers, isNotEmpty);
    for (final caller in callers) {
      expect(caller.id, startsWith(companyCallerPrefix));
      final at = caller.component<PositionComponent>().position;
      final tether = caller.component<TetherComponent>();
      expect(at.manhattanDistanceTo(tether.anchor), 1, reason: caller.id);
      expect(tether.length, companyCordLength);
      expect(world.map.tileAt(tether.anchor).isWalkable, isFalse);
      expect(companyWestWing.contains(at), isFalse, reason: caller.id);
    }
    final ground = callers
        .where(
          (caller) =>
              placeAt(caller.component<PositionComponent>().position) ==
              company,
        )
        .toList();
    expect(ground, hasLength(2));
    // From the west wing the view reaches twelve tiles past Mario at most,
    // and Mario gets no closer to the glass than the tile before it.
    final glass = company.tilesOf('G').first.x;
    for (final caller in ground) {
      final at = caller.component<PositionComponent>().position;
      expect(companyEastWing.contains(at), isTrue);
      expect(at.x - (glass - 1), greaterThan(12), reason: caller.id);
    }
    expect(
      world.entities.values.where(
        (entity) =>
            entity.kind == EntityKind.wanderer &&
            placeAt(entity.component<PositionComponent>().position) == company,
      ),
      isEmpty,
    );
  });

  test('a backpack with two rounds against a wall of the top floor', () {
    final world = createGameWorld();
    final backpack = world.pickups[companyBackpackId]!;
    expect(backpack.ammo, 2);
    expect(placeAt(backpack.position), place(PlaceId.companySecond));
    expect(
      world.map.tileAt(backpack.position.step(Direction.west)).isWalkable,
      isFalse,
    );
  });
}
