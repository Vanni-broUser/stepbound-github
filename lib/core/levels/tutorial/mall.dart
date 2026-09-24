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
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWXWWx',
  'x.....:..............:........b........:..Z...Zx',
  'x.........PP......*......T..........PP.....*...x',
  'x....T........:.............KK..........b......x',
  'x.......*........BBB.............*...........T.x',
  'x..........:...........P...........:.....T.....x',
  'x...T.....................*...KK...........*...x',
  'x............PP.........:.......BBB..........P.x',
  'x.....*............T........:.........*........x',
  'xw..wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xx..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xx+.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xx..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xW..WWWWWWWWWWWWWWWWWWUUUWWWWWWWWWWWWWWWWWWWWWWx',
  'xW..WWWWWWWWWWWWWWWWWWUUUWWWWWWWWWWWWWWWWWWWWWWx',
  'x........:..........*............:......b......x',
  'x......T.......PP............TT.......P........x',
  'x....*......:.............*..............*.....x',
  'x.........b.......KK.......BBB.....KK..........x',
  'x.....:.......*.................T......:.......x',
  'x.......PP...........*.........P..........T....x',
  'x...T............:.......BBB.........*.........x',
  'x..........*.......PP.........:.........T......x',
  'x......:.....T...............*......:........*.x',
  'xwwwwwwwwwwwwwwwwwwwwwEEEwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
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
