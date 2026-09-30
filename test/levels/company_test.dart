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

  test('both flights up go to the floor that is not drawn yet', () {
    expect(companyStairs, hasLength(2));
    for (final stairs in companyStairs) {
      expect(workInProgressDoors, contains(stairs));
    }
    expect(
      companyWestWing.contains(companyStairs.first.step(Direction.south)),
      isTrue,
    );
    expect(
      companyEastWing.contains(companyStairs.last.step(Direction.south)),
      isTrue,
    );
  });
}
