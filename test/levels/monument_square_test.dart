import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final square = place(PlaceId.monumentSquare);
  final shop = place(PlaceId.electronicsShop);
  final world = createGameWorld();

  test('the road south off the street of the company comes into the top '
      'of the square, lane for lane, and back', () {
    expect(industryStreetSouthEdge, hasLength(monumentSquareNorthEdge.length));
    for (final (i, edge) in industryStreetSouthEdge.indexed) {
      final down = world.portals[edge]!;
      expect(down.to, monumentSquareNorthEdge[i].step(Direction.south));
      expect(down.facing, Direction.south);
      final up = world.portals[monumentSquareNorthEdge[i]]!;
      expect(up.to, edge.step(Direction.north));
    }
  });

  test('the monument stands on its island, three cells by three, and is '
      'walked round', () {
    expect(monumentTiles, hasLength(9));
    for (final tile in monumentTiles) {
      expect(world.map.tileAt(tile).isWalkable, isFalse);
    }
    final reached = world.map.floodFillDistances(
      monumentSquareNorthEdge.first,
      maxDistance: 5000,
    );
    for (final side in Direction.values) {
      final beside = monumentTiles
          .map((tile) => tile.step(side))
          .where((tile) => !monumentTiles.contains(tile));
      expect(beside.any(reached.containsKey), isTrue, reason: '$side');
    }
  });

  test('the west road ends against the palazzi, the east one against a '
      'pile-up before the edge of the map: no way out of the square goes '
      'nowhere', () {
    final reachable = world.map.floodFillDistances(
      monumentSquareShopDoor.step(Direction.south),
      maxDistance: square.width * square.height,
    );
    final ends = workInProgressEnds.keys.where(square.bounds.contains);
    for (final end in ends) {
      expect(end.x, square.bounds.right, reason: '$end');
      expect(reachable.containsKey(end), isFalse, reason: '$end');
    }
  });

  test('the Elettronica is open: its door on the square leads in, and out '
      'again onto the road', () {
    expect(world.map.tileAt(monumentSquareShopDoor).isWalkable, isTrue);
    expect(
      world.portals[monumentSquareShopDoor]!.to,
      electronicsShopEntrance.step(Direction.north),
    );
    expect(
      world.portals[electronicsShopEntrance]!.to,
      monumentSquareShopDoor.step(Direction.south),
    );
  });

  test('inside, an L upside down: along the shop floor east, then down '
      'the storeroom to the back door, bolted', () {
    final inside = electronicsShopEntrance.step(Direction.north);
    final reached = world.map.floodFillDistances(inside, maxDistance: 5000);
    final beforeTheDoor = electronicsShopBackDoor.step(Direction.north);
    expect(reached.containsKey(beforeTheDoor), isTrue);
    expect(beforeTheDoor.x, greaterThan(inside.x));
    expect(beforeTheDoor.y, greaterThan(inside.y));
    expect(world.map.tileAt(electronicsShopBackDoor).isWalkable, isFalse);
    expect(shop.bounds.contains(electronicsShopBackDoor), isTrue);
  });

  test('the back door and the shutter behind the barracks are the two ends '
      'of one way through, both shut at the start', () {
    expect(world.map.tileAt(northDistrictShopDoor).isWalkable, isFalse);
    expect(
      place(PlaceId.northDistrict).bounds.contains(northDistrictShopDoor),
      isTrue,
    );
    expect(
      northDistrictShopDoor.manhattanDistanceTo(
        hometownCampfireNames.keys.firstWhere(
          place(PlaceId.northDistrict).bounds.contains,
        ),
      ),
      lessThan(6),
      reason: 'by the camp',
    );
    expect(
      world.portals[electronicsShopBackDoor]!.to,
      northDistrictShopDoor.step(Direction.south),
    );
    expect(
      world.portals[northDistrictShopDoor]!.to,
      electronicsShopBackDoor.step(Direction.north),
    );
  });
  test('in front of the Farmacia, on the pavement, a backpack with two '
      'rounds', () {
    final backpack = world.pickups[pharmacyBackpackId]!;
    expect(backpack.position, pharmacyBackpackTile);
    expect(backpack.ammo, 2);
    expect(square.bounds.contains(pharmacyBackpackTile), isTrue);
    expect(world.map.tileAt(pharmacyBackpackTile).isWalkable, isTrue);
    expect(
      world.map
          .floodFillDistances(monumentSquareNorthEdge.first, maxDistance: 5000)
          .containsKey(pharmacyBackpackTile),
      isTrue,
    );
  });
}
