import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// Inside the hypermarket, two floors in the barracks' style (rooms on a
/// dark background):
/// - `x` darkness, `W` shopfronts along the back wall, `w` front wall (on
///   the first floor, the railing over the atrium), `I` shop partition, `S`
///   shelves at the back of a shop, `Q` the anti-theft control panel:
///   walls.
/// - `E` entrance from the car park, `U` stairs up, `D` stairs down: doors.
///   The ground floor is two areas one above the other, joined by a
///   two-cell passage down their west side: the hall below, with the
///   entrance in its front wall and the stairs at the centre of its back
///   wall, and above it a second row of shops whose back wall holds `X`,
///   the fire exit onto the car park behind the building. Two wanderers
///   stand close to that exit.
/// - `P` planter, `T` abandoned trolley, `K` kiosk, `BBB` bench, `G` gate
///   post, `H` the shutter's bars, `L` Luigi behind them: obstacles.
/// - `.` floor, `o` floor of a shop, `d` floor of the service area beyond
///   the gate, `g` the gate standing open, `:` litter (noisy), `b` blood,
///   `*` ceiling lamp, `+` flickering lamp, `c` where the zombies come in
///   through the gate.
// mall-ground-rows-start
const List<String> mallGroundRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWXWWx',
  'x.....:................:..Z...Zx',
  'x.........PP........PP.....*...x',
  'x....T........:.........b......x',
  'x.......*........*...........T.x',
  'x..........:.......:.....T.....x',
  'x...T..........KK..........*...x',
  'x............PP.BBB..........P.x',
  'x.....*...............*........x',
  'xw..wwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xx.*xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xx+.xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xx*.xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xW..WWWWWWWWWWWWWWWWWWUUUWWWWWWx',
  'xW..WWWWWWWWWWWWWWWWWWUUUWWWWWWx',
  'x........:..........*..........x',
  'x......T.......PP............TTx',
  'x....*......:.............*....x',
  'x.........b.......KK.......BBB.x',
  'x.....:.......*................x',
  'x.......PP...........*.........x',
  'x...T............:.......BBB...x',
  'x..........*.......PP.........:x',
  'x......:.....T...............*.x',
  'xwwwwwwwwwwwwwwwwwwwwwEEEwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// mall-ground-rows-end

/// The lamps over the ground floor's shop signs, one at the middle of
/// each shopfront, on the top course of its wall.
const List<GridPoint> mallGroundSignLights = <GridPoint>[
  // The upper area: TABACCHI, GIOCATTOLI, LIBRERIA, FIORI. OTTICA stays
  // dark.
  GridPoint(3, 1),
  GridPoint(15, 1),
  GridPoint(21, 1),
  GridPoint(26, 1),
  // The hall: PROFUMERIA. SCARPE and BAR stay dark.
  GridPoint(18, 15),
];

/// The failing light over ELETTRONICA's sign.
const List<GridPoint> mallGroundFlickeringSignLights = <GridPoint>[
  GridPoint(6, 15),
];

// mall-first-rows-start
const List<String> mallFirstRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxISSSSSIxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxIoooooIxxxxxxxxxxxxxxxxxx',
  'xWDDDWWWWWWIooLooIWWWWWWWWWWWWWWWWWx',
  'xWDDDWWWWWWIHHHHHIWWWWWWWWWWWWWWQWWx',
  'x......:............*......Gdddddddx',
  'x..P....*.............T....gddcddcdx',
  'x.........BBB.....KK.......gdcdddddx',
  'x...*..........P........:..gddd+cddx',
  'x.....T.......*.....bBBB...gddcddcdx',
  'x..........*.............P.gdcdddddx',
  'x..KK............:.........gdddcdddx',
  'x..................*.......Gdddddddx',
  'xwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// mall-first-rows-end

/// The hypermarket's glyphs: its walls, the shutters and the panel's
/// housing are solid, the shelves, the tills, the trolleys and the bars
/// of Luigi's shutter can be seen over.
const Legend mallLegend = Legend(walls: 'xWwISQ', obstacles: 'PTKBGHL');

final Place _mallGround = place(PlaceId.mallGround);
final Place _mallFirst = place(PlaceId.mallFirst);
final Place _north = place(PlaceId.northDistrict);

/// Where Luigi is stuck, behind the shutter of a shop on the first floor.
final GridPoint luigiTile = _mallFirst.tileOf('L');

/// The shutter's bars, which the control panel lifts.
final GridRect luigiBars = () {
  final bars = _mallFirst.tilesOf('H');
  return GridRect(bars.first.x, bars.first.y, bars.last.x, bars.last.y);
}();

/// How many rows along the railing Luigi's shouting does not reach: the
/// far edge of the corridor, and the only way past his shop without his
/// scene playing. Two of eight, so that slipping by takes knowing about
/// it rather than luck.
const int luigiDodgeRows = 2;

/// Walking up to the shutter starts Luigi's scene: the corridor in front
/// of the shop, all of it but the [luigiDodgeRows] hugging the railing
/// over the atrium.
final GridRect luigiSceneTrigger = () {
  final railing = _mallFirst.rows.lastIndexWhere((row) => row.contains('w'));
  final lastFloorRow = _mallFirst.origin.y + railing - 1;
  return GridRect(
    luigiBars.left - 1,
    luigiBars.bottom + 1,
    luigiBars.right + 1,
    lastFloorRow - luigiDodgeRows,
  );
}();

/// The anti-theft control panel beyond the gate.
final GridPoint mallPanelTile = _mallFirst.tileOf('Q');

/// Where the zombies come in through the gate after Luigi's warning.
final List<GridPoint> mallHordeSpawns = _mallFirst.tilesOf('c');

/// The stairs down, where Luigi heads once he trusts Mario and leaves the
/// shop: down to the ground floor and out through its fire exit, off
/// screen.
final GridPoint luigiStairsDown = _mallFirst.doorRow('D').first;

/// The path Luigi walks once he leaves the shop: down through the open
/// shutter, along the corridor, then down the stairs and out of sight.
final List<GridPoint> luigiExitPath = <GridPoint>[
  GridPoint(luigiTile.x, luigiSceneTrigger.top),
  GridPoint(luigiStairsDown.x, luigiSceneTrigger.top),
  luigiStairsDown,
];

/// The fire exit in the back wall of the ground floor's upper area, past
/// its second row of shops and straight above the stairs: the only way in
/// or out of the car park behind the hypermarket.
final GridPoint mallExitTile = _mallGround.tileOf('X');

/// The two wanderers guarding the fire exit in the mall's upper ground-
/// floor area, `Z`.
const String mallGroundZombiePrefix = 'mall-ground-wanderer-';
final List<GridPoint> mallGroundZombieTiles = _mallGround.tilesOf('Z');

/// A wanderer coming in through the hypermarket's gate at [position],
/// looking west down the corridor.
Entity createMallZombie(String id, GridPoint position) {
  return EntityFactory(
    BalanceConfig.standard(),
  ).zombie(id: id, kind: EntityKind.wanderer, position: position);
}

/// The hypermarket's stairs, up from the ground floor and down from the
/// first, each step with the way up it (see `WorldState.stairs`): both
/// flights climb into the back wall.
final Map<GridPoint, Direction> mallStairs = <GridPoint, Direction>{
  for (final step in _mallGround.tilesOf('U')) step: Direction.north,
  for (final step in _mallFirst.tilesOf('D')) step: Direction.north,
};

/// The hypermarket's entrance from the car park, its stairs between the
/// two floors (both flights climb into the back wall: the lower step of
/// each flight is where Mario lands) and the fire exit in the back wall of
/// the ground floor's upper area, onto the car park behind the
/// hypermarket, cut off from the rest of the north district.
final Map<GridPoint, Portal> mallPortals = () {
  final mallDoor = _north.doorRow('m');
  final entrance = _mallGround.doorRow('E');
  final up = _mallGround.doorRow('U');
  final down = _mallFirst.doorRow('D');
  return <GridPoint, Portal>{
    ...pairedDoors(mallDoor, entrance, Direction.north),
    ...pairedDoors(entrance, mallDoor, Direction.south),
    ...pairedDoors(up, down, Direction.south),
    ...pairedDoors(down, up, Direction.south),
    // Out of the fire exit Mario stands in its doorway, not out on the
    // tarmac of the car park: pushing on south from there goes back in.
    mallExitTile: Portal(to: mallNorthStreetEntry, facing: Direction.north),
    ...pairedDoors(
      <GridPoint>[mallNorthStreetEntry],
      <GridPoint>[mallExitTile],
      Direction.south,
    ),
  };
}();
