import 'package:stepbound/core/grid/grid_point.dart';

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
