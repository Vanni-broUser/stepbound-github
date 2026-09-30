import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// Inside the Elettronica on the road east of the monument's square
/// (monument_square.dart), the one shop in town still open: an L upside
/// down. In through the door `E` at the west end of the shop floor, along
/// it eastwards past the televisions, the white goods, the displays of
/// phones and laptops and the till, then down the east side through the
/// doorway into the storeroom, and at the bottom of it the back door `D`,
/// shut. It is bolted on this side: Mario opens it from inside, and it
/// lets him out in front of the same shop's other door, on the street
/// behind the barracks by the camp (north_district.dart).
///
/// Glyphs:
/// - `x` darkness, `W` the back wall (two courses), `w` the front wall,
///   `I` a partition, `D` the back door while it is shut: walls.
/// - `E` the way in from the square: a door. `d` the doorway into the
///   storeroom: floor.
/// - `.` the shop's tiled floor.
/// - `V` a television on its stand, `F` a fridge or a washing machine,
///   `T` a display of phones and laptops, `R` the till counter, `S` the
///   storeroom's shelving, `k` a pile of boxes: obstacles.
/// - `:` smashed boxes and packaging (noisy), `b` blood, `c` a body, `*`
///   a ceiling lamp, `+` a flickering one, `Z` a wanderer.
// electronics-shop-rows-start
const List<String> electronicsShopRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'x.VV.VV..VV.VV...FF.FF.x',
  'x.......*......*.......x',
  'x....TT...TT........b..x',
  'xRR.....c....:...TT....x',
  'x...:..................x',
  'xwwEwwwwwwwwwwwI.......x',
  'xxxxxxxxxxxxxxxI...:.*.x',
  'xxxxxxxxxxxxxxxI.......x',
  'xxxxxxxxxxxxxxxIIIIdIIIx',
  'xxxxxxxxxxxxxxxIS.....Sx',
  'xxxxxxxxxxxxxxxIS..+..Sx',
  'xxxxxxxxxxxxxxxIS.kk...x',
  'xxxxxxxxxxxxxxxI.Z....Sx',
  'xxxxxxxxxxxxxxxIS..:..Sx',
  'xxxxxxxxxxxxxxxIS...k..x',
  'xxxxxxxxxxxxxxxI..k..b.x',
  'xxxxxxxxxxxxxxxwwwwDwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxx',
];
// electronics-shop-rows-end

/// The Elettronica: its walls, and the back door while it is still
/// bolted, are solid; the televisions, the white goods, the displays, the
/// till, the shelving and the boxes stop a step but not a shot.
const Legend electronicsShopLegend = Legend(
  walls: 'xWwID',
  obstacles: 'VFTRSk',
);

/// How dark the Elettronica is between its lamps: its lights still on over
/// the shop floor, one flickering in the storeroom.
const double electronicsShopDarkness = 0.6;

final Place _electronicsShop = place(PlaceId.electronicsShop);
final Place _north = place(PlaceId.northDistrict);

/// The way in from the shop's open door on the road east of the square
/// ([monumentSquareShopDoor], monument_square.dart).
final GridPoint electronicsShopEntrance = _electronicsShop.tileOf('E');

/// The shop's back door, bolted on the inside, and the door of the same
/// shop by the camp behind the barracks, its shutter down: Mario opens
/// both from inside, and then they are the way through from one to the
/// other.
final GridPoint electronicsShopBackDoor = _electronicsShop.tileOf('D');
final GridPoint northDistrictShopDoor = _north.tileOf('¦');

/// The wanderers `Z` in the Elettronica, `electronics-wanderer-<n>`.
const String electronicsShopZombiePrefix = 'electronics-wanderer-';
final List<GridPoint> electronicsShopZombieTiles = _electronicsShop.tilesOf(
  'Z',
);

/// The shop's door on the square and its back door behind the barracks,
/// both ways.
final Map<GridPoint, Portal> electronicsShopPortals = <GridPoint, Portal>{
  ...pairedDoors(
    <GridPoint>[monumentSquareShopDoor],
    <GridPoint>[electronicsShopEntrance],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[electronicsShopEntrance],
    <GridPoint>[monumentSquareShopDoor],
    Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[electronicsShopBackDoor],
    <GridPoint>[northDistrictShopDoor],
    Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[northDistrictShopDoor],
    <GridPoint>[electronicsShopBackDoor],
    Direction.north,
  ),
};
