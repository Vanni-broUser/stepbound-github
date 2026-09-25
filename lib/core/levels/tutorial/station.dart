// The ASCII maps are one row per line, however wide the place is.

/// The three places of the station at the top of the block behind the
/// hypermarket (see mall_north_street.dart, where its front stands with
/// its two open doorways). They are drawn as rooms on a dark background
/// like the barracks, but only the underpass is really indoors: over the
/// platforms the roof is gone, so they are lit throughout.
///
/// The two doorways lead to two different corners of the building, and
/// what came down between them -- the booking hall's roof and, on the
/// track side, the train itself -- leaves no way from one to the other.
///
/// West doorway `E`: the booking hall, then the platform through the gap
/// in its back wall, and the tracks beyond. Following them east gets
/// nowhere: a railcar `M` stands derailed across the near track and the
/// coach behind it `m` has gone over on its side, torn open, lying across
/// the far one. The backpack `9`, two rounds in it, is in the pocket of
/// ballast between the two wrecks.
///
/// East doorway `O`: the other end of the hall, cut off from the rest by
/// the rubble `#`, with the stairs `U` down to the underpass in its back
/// wall. That side's platform is buried under the same fall.
///
/// Common glyphs: `x` darkness, `W` back wall, `w` front wall, `M` the
/// railcar and `#` the rubble are walls; `m` the coach on its side, `T` a
/// bench, `K` a ticket window, `n` a canopy post are obstacles you can see
/// over; `.` the hall floor, `=` the platform, `,` ballast, `-` the rails,
/// `:` litter (noisy), `b` blood, `*` a working lamp, `+` a flickering
/// one, `Z` a wanderer. Two wanderers roam the underpass too.
// station-rows-start
const List<String> stationRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,mmmmmmmmmx',
  'x----------------------,,-mmmmmmmmmx',
  'x,,,,,,,,,,,,,,,,,,,,,,9,,mmmmmmmmmx',
  'x,,,,,,,,,,,,,,,,,,,,,,,MMMMMMMMMMMx',
  'x-----------------------MMMMMMMMMMMx',
  'x,,:,,,,,,,,,,,,,,,,,,,,MMMMMMMMMMMx',
  'x==================:====###########x',
  'x==nn=====T=====nn==:===###########x',
  'x===================:===###########x',
  'xWWWWWWWW....WWWWWWW####WWWWUUWWWWWx',
  'x...:......Z......:.####...........x',
  'x..T....K.........:.####..:...T....x',
  'x.....b......:......####.b.........x',
  'x..:.....Z.......:..####....:....K.x',
  'x........:..........####..........:x',
  'xwwwwwwwwEEwwwwwwwwwwwwwwwwwOOwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// station-rows-end

/// The underpass under the tracks: a tiled corridor two cells deep, dark
/// but for the few lamps still burning, the stairs `D` back up into the
/// booking hall at one end and the stairs `U` up to the far platform at
/// the other.
// underpass-rows-start
const List<String> stationUnderpassRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWDDWWWWWWWWWWWWWWWWWWWWWWUUWx',
  'x...:......*..Z....:...Z..:..x',
  'x.b........:...+..........b..x',
  'x..:...*.........:.....*.....x',
  'xwwwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// underpass-rows-end

/// The far side of the station, up the second flight `D`: one long
/// platform under what is left of its canopy and, standing on the near
/// track, a railcar `M` that is filthy but whole, both tracks running past
/// it. `P` is its passenger door: still part of the wall until Luigi has
/// been rescued, then the game opens it onto the train interior.
// far-platform-rows-start
const List<String> stationFarSideRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x----------------------------------x',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x,,,MMMMMMMMMMMMMMMMMMMMMMMMMMM,,,,x',
  'x---MMMMMMMMMMMMMMMMMMMMMMMMMMM----x',
  'x,,,MMMMMMMMMMMMMMMMMMMMMMMPMMM,,,,x',
  'x==================================x',
  'x==nn======T=========nn=====T======x',
  'x=:=========================:======x',
  'x==================================x',
  'xWWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWWx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// far-platform-rows-end
