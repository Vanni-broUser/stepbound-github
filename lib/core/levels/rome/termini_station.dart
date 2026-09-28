// The ASCII maps are one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The rest of Roma Termini, past the platform the train pulls in at
/// (termini.dart): the overpass its stairs climb to, the far platform one
/// flight of the overpass still goes down to, and the concourse at the
/// head of the tracks. Unlike Molfetta's station, which goes under the
/// tracks, Termini crosses over them: from the platforms the stairs go up.
library;

/// The overpass over the tracks: a wide hall, wider than Molfetta's
/// underpass, lit by the few strip lights still burning. In its back wall
/// `W` eight flights go down to the platforms below, two cells each, and
/// six of them go nowhere any more: four choked with the rubble of the
/// fallen roof `#`, which has spilled out onto the floor in front of
/// them, and two shut off with site barriers `H`. The two still open are
/// `D`, back down to the platform the train stands at, and `U`, down to
/// the far platform. Between the flights hang the timetables `Q`, their
/// boards smashed, and against the wall stand the ticket machines `K`,
/// screens broken and panels forced. A row of pillars `I` holds up the
/// roof; benches `T`, a heap of fallen ceiling `#`, litter `:`, blood `b`
/// and the lamps `*` (steady) and `+` (flickering) lie about the floor
/// `.`. In the front wall `w` a wide opening `E` goes on to the concourse.
/// `x` darkness, `|` the side walls.
// termini-overpass-rows-start
const List<String> terminiOverpassRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  '|WWWWWWWWWWWWQQQQQWWWWWWWWWWWWWWWWWWWWWWWQQQQQWWWWWWWWWWWWWWWWW|',
  '|WWW##WWWWWHHQQQQQDDWWWWW##WWWWWHHWWWWW##QQQQQUUWWWWW##WWWWWWWW|',
  '|..###:KK............KK.###:.......KK.###:.......KK.###:.......|',
  '|...:#....:..............:#............:#............:#.....b..|',
  '|...................:.......TT..........................#......|',
  '|....:.............+..................:.....##.................|',
  '|.......I......b..I.........I.........I.........I.....:........|',
  '|.......I.........I.........I....:....I.......+.I.........:....|',
  '|.....*..........:......###....................................|',
  '|...........TT..........###.....*.......b...........TT.........|',
  '|..............................:...............:..........*....|',
  '|wwwwwwwwwwwwwwwwwwwwwwwwwwwwwEEEEwwwwwwwwwwwwwwwwwwwwwwwwwwwww|',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// termini-overpass-rows-end

/// The far platform, down the one open flight of the overpass `D` in its
/// front wall. The same station as the platform the train pulls in at,
/// but the tracks run on well past both ends of the platform `=`, which
/// stops at a step down onto the ballast `,` and the rails `-`. A train
/// was left standing on the far track `m`, all along the platform. West,
/// a few dozen steps down the line, a mountain of rubbish `;` has been
/// dumped over every track, with the rubbish it spilled `:` round it.
/// Its edge is ragged, every row reaching its own way down the line, and
/// clumps of it lie loose beyond it; in a hollow between the heap and one
/// of them a backpack with two rounds was left on the rails (see
/// `terminiRubbishBackpackSpot`). East the line runs on until a train
/// that came off the rails `V`, its cars slewed across every track, closes
/// it; just short of it a breach `J` has been knocked through the back
/// wall `W`, out onto the street behind the station. `n` canopy posts, `T` benches, `w` the front wall.
// termini-far-platform-rows-start
const List<String> terminiFarPlatformRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWJJWWWWWWWWWWWWWWWWWW',
  ';;;;;;;;;,,,:,,,,,,,,,,,,,mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm,,,,,,,,,,,,,,,,,,,VVVVVVVVVV',
  ';;;;;;-:--;---------------mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm--------:---------VVVVVVVVVVV',
  ';;;;;;;;;;;;,:;,,,,,,,,,,,mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm,,,,,,,,,,,,,,,,,VVVVVVVVVVVV',
  ';;;;;;;;,:,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,:,,,,,,,,,,VVVVVVVVVVVVV',
  ';;;;;;;;;;;;;;--;:------------------------------------------------------------------------VVVVVVVVVVVVVV',
  ';;;;;;;,,;:,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,VVVVVVVVVVVVVV',
  ';;;;;;;;;;;,:;,,,,,,,,,,,,,,,,,,,,=====================:==============,,,,,,,,,,,,,,,,:,,VVVVVVVVVVVVVVV',
  ';;;;;-:---------------------------====nn==================nn==========-------------------VVVVVVVVVVVVVVV',
  ';;;;;;;;;;;;;,,;,,,,,,,,,,,,,,,,,,==========TT==================TT=:==,,,,,,,:,,,,,,,,,,,,VVVVVVVVVVVVVV',
  ';;;;;;;;,,,;,,,:,,,,,,,,,,,,,,,,,,=======:============================,,,,,,,,,,,,,,,,,,,,,VVVVVVVVVVVVV',
  'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwDDwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// termini-far-platform-rows-end

/// The concourse at the head of the tracks, where the overpass comes out
/// through the opening `E` in its back wall `W`. A great hall of polished
/// stone, the shops `S` along its back wall shuttered or looted, the
/// ticket machines `K` in two banks, the great departures board `Q` hung
/// over the middle of the hall with half its slats gone, two rows of
/// pillars `I`, the information kiosk `i`, benches `T`, luggage trolleys
/// `y` left where they were dropped, fallen ceiling `#`, litter `:` and
/// blood `b`. Three doorways `O` in the glass front `w` go out onto the
/// piazza. `x` darkness, `|` the side walls.
// termini-concourse-rows-start
const List<String> terminiConcourseRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  '|WWSSSSSSWWSSSSSSWWWWWWWWWWWWWWWWWWWWWWSSSSSSWWSSSSSSWWWW|',
  '|WWSSSSSSWWSSSSSSWWWWWWWWWWEEEEWWWWWWWWSSSSSSWWSSSSSSWWWW|',
  '|........................................................|',
  '|....KKKK.............................###........KKKK....|',
  '|.............................b..........................|',
  '|.......:...........QQQQQQQQQQQQQQQQQQ...................|',
  '|...................QQQQQQQQQQQQQQQQQQ.........:.........|',
  '|.........y..............................................|',
  '|.............b..................:..........y............|',
  '|.....I........I.......:I........I........I........I.....|',
  '|.....I........I........I.iiiiii.I........I........I.....|',
  '|...............##........iiiiii......:..............:...|',
  '|..y............##.......................b...............|',
  '|...........TTT...........................TTT............|',
  '|..................:...............y.....................|',
  '|...:............y..........:......................#.....|',
  '|............................................:...........|',
  '|........................................................|',
  '|wwwwwwwwwOOwwwwwwwwwwwwwwwwOOwwwwwwwwwwwwwwwwOOwwwwwwwww|',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// termini-concourse-rows-end
