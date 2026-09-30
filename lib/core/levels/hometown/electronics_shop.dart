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
