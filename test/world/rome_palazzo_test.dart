import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// The palazzo beside the bank on Via Marsala: up from its hall floor by
/// floor to its terrace, and across the drop to the bank's roof with the
/// grappling hook.
void main() {
  final ground = place(PlaceId.romePalazzoGround);
  final first = place(PlaceId.romePalazzoFirst);
  final second = place(PlaceId.romePalazzoSecond);
  final roof = place(PlaceId.romePalazzoRoof);

  /// Steps onto [threshold] from beside it, going [facing], and says where
  /// Mario comes out.
  GridPoint travel(WorldState world, GridPoint threshold, Direction facing) {
    world.player.component<PositionComponent>().position = threshold.step(
      facing.opposite,
    );
    final events = const TurnScheduler().advance(world, MoveAction(facing));
    expect(events.whereType<TeleportedEvent>(), hasLength(1));
    return world.player.component<PositionComponent>().position;
  }

  Map<GridPoint, int> reachable(WorldState world, GridPoint start, Place p) =>
      world.map.floodFillDistances(start, maxDistance: p.width * p.height);

  test('up the stairs floor by floor from the hall to the terrace, and '
      'back down', () {
    final world = createGameWorld();
    var at = travel(world, marsalaPortoneTile, Direction.north);
    expect(ground.bounds.contains(at), isTrue);
    for (final (from, to) in <(Place, Place)>[
      (ground, first),
      (first, second),
      (second, roof),
    ]) {
      final up = from.tileOf('U');
      expect(reachable(world, at, from), contains(up.step(Direction.south)));
      at = travel(world, up, Direction.north);
      expect(to.bounds.contains(at), isTrue, reason: '${to.id}');
      expect(world.map.tileAt(at).isWalkable, isTrue);
    }
    expect(at, romeTerraceDoor.step(Direction.south));
    final down = travel(world, romeTerraceDoor, Direction.north);
    expect(second.bounds.contains(down), isTrue);
    final hall = travel(world, first.tileOf('D'), Direction.south);
    expect(ground.bounds.contains(hall), isTrue);
    final street = travel(world, romePalazzoPortone, Direction.south);
    expect(placeAt(street)!.id, PlaceId.viaMarsala);
  });

  test('every floor has two flats, each laid out its own way', () {
    for (final floor in <Place>[first, second]) {
      expect(floor.tilesOf('P'), hasLength(2), reason: '${floor.id}');
    }
    expect(first.rows, isNot(second.rows));
    // Smaller than Molfetta's palazzo.
    final molfetta = place(PlaceId.palazzoFirstFloor);
    expect(
      first.width * first.height,
      lessThan(molfetta.width * molfetta.height),
    );
  });

  test('the bank roof is across the drop: looked at from the terrace it '
      'is near enough for the hook, which takes Mario there and back', () {
    final world = createGameWorld();
    final terrace = reachable(
      world,
      romeTerraceDoor.step(Direction.south),
      roof,
    );
    final standing = romeTerraceLookoutTile.step(Direction.east);
    expect(terrace, contains(standing));
    expect(terrace, isNot(contains(bankRoofEdgeTile.step(Direction.west))));
    expect(world.lookouts, contains(romeTerraceLookoutTile));

    final mario = world.player.component<PositionComponent>()
      ..position = standing
      ..facing = Direction.west;
    var events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<LookedOutEvent>(), hasLength(1), reason: 'no hook');
    expect(mario.position, standing);

    world.player.component<AmmoComponent>().grapplingHook = true;
    events = const TurnScheduler().advance(world, const InteractAction());
    expect(mario.position, bankRoofEdgeTile.step(Direction.west));
    mario.facing = Direction.east;
    const TurnScheduler().advance(world, const InteractAction());
    expect(mario.position, standing, reason: 'and back');
  });

  test('on the bank roof the stairs go down into its offices, got onto '
      'only from their head, and on down to the open vault', () {
    final world = createGameWorld();
    expect(bankRoofStairs, hasLength(4));
    for (final foot in bankRoofStairsFoot) {
      expect(workInProgressDoors, isNot(contains(foot)));
      final below = foot.step(Direction.south);
      expect(world.canStep(below, foot), isFalse);
    }
    final head = bankRoofStairs.first;
    expect(world.canStep(head.step(Direction.north), head), isTrue);

    final offices = place(PlaceId.bankOffices);
    final vault = place(PlaceId.bankVault);
    final inside = travel(world, bankRoofStairsFoot.first, Direction.south);
    expect(offices.bounds.contains(inside), isTrue);
    final back = travel(world, bankOfficesStairsUp.first, Direction.north);
    expect(back, bankRoofStairsFoot.first.step(Direction.north));

    final downstairs = travel(
      world,
      bankOfficesStairsDown.first,
      Direction.south,
    );
    expect(vault.bounds.contains(downstairs), isTrue);
    final reached = reachable(world, downstairs, vault);
    expect(
      reached,
      contains(bankIngotTile.step(Direction.west)),
      reason: 'through the open door of the vault, up to the backpack',
    );
    final upstairs = travel(world, bankVaultStairsUp.first, Direction.north);
    expect(offices.bounds.contains(upstairs), isTrue);
  });

  test('the backpack in the vault holds the gold ingot', () {
    final world = createGameWorld();
    final backpack = world.pickups[bankIngotBackpackId]!;
    expect(backpack.goldIngot, isTrue);
    expect(backpack.position, bankIngotTile);
    world.player.component<PositionComponent>()
      ..position = bankIngotTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<PickedUpEvent>().single.goldIngot, isTrue);
  });

  test('the big dead wait on every floor under the roof', () {
    final world = createGameWorld();
    final brutes = world.entities.values.where(
      (entity) => entity.kind == EntityKind.brute,
    );
    for (final floor in <Place>[ground, first, second]) {
      expect(
        brutes.where(
          (brute) => floor.bounds.contains(
            brute.component<PositionComponent>().position,
          ),
        ),
        hasLength(1),
        reason: '${floor.id}',
      );
    }
    for (final brute in brutes) {
      expect(
        world.map
            .tileAt(brute.component<PositionComponent>().position)
            .isWalkable,
        isTrue,
      );
    }
  });
}
