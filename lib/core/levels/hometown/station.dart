// The ASCII maps are one row per line, however wide the place is.

/// The three places of the station at the top of the block behind the
/// hypermarket (see mall_north_street.dart, where its front stands with
/// its two open doorways). They are drawn as rooms on a dark background
/// like the barracks, but only the underpass is really indoors: over the
/// platforms the roof is gone, so they are lit throughout.
///
/// The two doorways lead to two different corners of the building, and
/// what lies between them leaves no way from one to the other: a hijacked
/// train that came in too fast. Its coach `m` is still standing on the far
/// track, but the car behind it `V` broke away at the coupling, turned over
/// and ploughed on wheels up across the platform and through the back wall
/// of the booking hall, down to its front wall, a heap of rubble `#` along
/// its flanks.
///
/// Only the hall and the platform are rooms, walled on both sides `|`: the
/// tracks run on past them, off both edges of the map, and the cars on
/// them with it, so it is only the wrecks that keep Mario from following.
///
/// West doorway `E`: the booking hall, then the platform through the gap
/// in its back wall. Along the near track, west of the overturned car,
/// the rest of the train shuts the platform off from the tracks: a car `C`
/// still upright, and past a gap the car that came off before it, `H`,
/// over on its side and burning, running on off the west edge. The gap
/// between them, at the west end of the platform, is on fire `?`: the
/// only way onto the tracks, and looking at it says what it would take
/// (see `stationTrackFireTile`). The backpack `9`, two rounds in it, is at
/// the other end of the platform, against the rubble.
///
/// East doorway `O`: the other end of the hall, cut off from the rest by
/// the overturned car. A gap in the back wall reaches the platform, where
/// only a little rubble remains and a railcar `M` stands derailed across
/// the near track beyond it. The stairs `U` down to the underpass are sunk
/// in the floor a few cells in from the front wall, where they show: a
/// flight two cells wide and two deep, got onto only from the north, its
/// last step the way down; the floor goes on below it, shut off from it by
/// the end of the well. The tactile path `p` runs up from the doorway and
/// along to the head of the flight.
///
/// Common glyphs: `x` darkness, `W` back wall, `w` front wall, `|` the side
/// walls, `m` the coach and `C` the car still upright, `V` and `H` the
/// overturned cars, `M` the railcar and `#` the rubble are walls; `T` a
/// bench, `K` a ticket window, `n` a canopy post are obstacles you can see
/// over; `?` burns and cannot be walked through; `.` the hall floor, `=`
/// the platform, `,` ballast, `-` the rails, `:` litter (noisy), `b`
/// blood, `p` the tactile path, `*` a working lamp, `+` a flickering one,
/// `Z` a wanderer. Two wanderers roam the underpass too.
// station-rows-start
const List<String> stationRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  ',,,,,,,,,,,,,,,,,,,,,,,,mmmmmmmmmmmmmmmmmmm',
  '------------------------mmmmmmmmmmmmmmmmmmm',
  ',,,,,,,,,,,,,,,,,,,,,,,,mmmmmmmmmmmmmmmmmmm',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  'xxx|==================:#VVV##==========|xxx',
  'xxx|==nn=====T=====nn=9#VVV#===========|xxx',
  'xxx|=================:=#VVV============|xxx',
  'xxx|WWWWWWWW....WWWWWWWWVVVWWWW....WWWW|xxx',
  'xxx|.Z.:......Z......:..VVV............|xxx',
  'xxx|..T....K.........:..VVV..:.ppppp...|xxx',
  'xxx|.....b......:......#VVV#b..p...UU..|xxx',
  'xxx|..:.............:.##VVV##..p...UU..|xxx',
  'xxx|........:.........##VVV##T.p.....:.|xxx',
  'xxx|wwwwwwwwEEwwwwwwwwwwwwwwwwwOOwwwwww|xxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// station-rows-end

/// The underpass under the tracks: a tiled corridor two cells deep, dark
/// but for the few lamps still burning, the stairs `D` back up into the
/// booking hall at one end and the stairs `U` up to the far platform at
/// the other.
// underpass-rows-start
const List<String> stationUnderpassRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  '|WWWWWWWWWWWWWWWWWWWWWWWWWWWW|',
  '|WDDWWWWWWWWWWWWWWWWWWWWWWUUW|',
  '|...:......*..Z....:...Z..:..|',
  '|.b........:...+..........b..|',
  '|..:...*.........:.....*.....|',
  '|wwwwwwwwwwwwwwwwwwwwwwwwwwww|',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// underpass-rows-end

/// The far side of the station, up the second flight `D`, two steps deep
/// through the wall south of the platform: one long
/// platform under what is left of its canopy and a railcar `M` that is
/// filthy but whole, filling the strip between the wall and the platform.
/// `P` is its passenger door: still part of the wall until Luigi has
/// been rescued, then the game opens it onto the train interior. Only the
/// platform is walled at the sides `|`; the tracks run on past it. The
/// repeated `l` and `r` cells carry the two damaged Molfetta station signs.
// far-platform-rows-start
const List<String> stationFarSideRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWllllllllWWWWWWWWWWWWrrrrrrrrWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  'xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  'xMMMMMPMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  '|==================================|',
  '|==nn======T=========nn=====T======|',
  '|=:=========================:======|',
  '|==================================|',
  '|WWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWW|',
  'xxxxxxxxxxxxxxxxxDDxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// far-platform-rows-end
