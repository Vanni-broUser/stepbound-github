/// Inside the hypermarket, two floors in the barracks' style (rooms on a
/// dark background):
/// - `x` darkness, `W` shopfronts along the back wall, `w` front wall (on
///   the first floor, the railing over the atrium), `I` shop partition, `S`
///   shelves at the back of a shop, `Q` the anti-theft control panel:
///   walls.
/// - `E` entrance from the car park, `U` stairs up, `D` stairs down: doors.
///   On the ground floor, the hall opens west onto a long corridor lined
///   with a second row of shops; at its far end `X` is the fire exit onto
///   the car park behind the building.
/// - `P` planter, `T` abandoned trolley, `K` kiosk, `BBB` bench, `G` gate
///   post, `H` the shutter's bars, `L` Luigi behind them: obstacles.
/// - `.` floor, `o` floor of a shop, `d` floor of the service area beyond
///   the gate, `g` the gate standing open, `:` litter (noisy), `b` blood,
///   `*` ceiling lamp, `+` flickering lamp, `c` where the zombies come in
///   through the gate.
// mall-ground-rows-start
const List<String> mallGroundRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWxxWWWWWWWWWWWWWWWWWWWWWWWUUUWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWxxWWWWWWWWWWWWWWWWWWWWWWWUUUWWx',
  'x........................xx....:......*.........:.....bx',
  'x........T...............xx..PP....TT......PP.........:x',
  'x.....*............*.....xx......*.......:.......*.....x',
  'x.............b..........xx.KK.......BBB.......KK......x',
  'x................................:...........b.........x',
  'X................:...........PP.......*...T......PP....x',
  'x.............................:...................:....x',
  'x...........*............xx..........BBB.....*.........x',
  'x....................T...xx....*..........:.......P....x',
  'x...:....................xx.T.........................Tx',
  'x........................xx.......:.....*..............x',
  'xwwwwwwwwwwwwwwwwwwwwwwwwxxwwwwwwwwwwwwwEEEwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// mall-ground-rows-end

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
