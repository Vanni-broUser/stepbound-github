// The ASCII maps are one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// Rome's streets round Termini, with the glyphs of Molfetta's (see
/// street.dart), but not its buildings: here the palazzi `H` are Roman,
/// ochre and red under their tiled roofs `B`. On top of those glyphs: `]`
/// the front of Termini, a wall, and `{` its doorways, and `}` a breach
/// in the wall `%` round the tracks, both floor; `"` Santa Maria
/// Maggiore, a wall, and `>` the columns on its square, seen over; `°`
/// the sampietrini across that square, floor; `§`
/// the Baths of Diocletian, a wall, `¶` the portal in them, and `¤` the
/// brown sign with their name, seen over. Where a
/// street runs off the edge of the map, the game goes no further for now.
library;

import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/place.dart';

/// Piazza dei Cinquecento, out of the concourse: the long front of
/// Termini `]` across the top, its three doorways `{` open, palazzi either
/// side of it, a souvenir shop in the western ones; the paving `P` in
/// front of it with its bus shelters `n` and its trees `A`, and a
/// campfire `S` in line with the trees, two cells west of the one before
/// the east doorway, then the four lanes
/// of the road, which runs off the map east. West it runs on past more
/// palazzi, their little shops shut, up to the Baths of Diocletian `§`:
/// their brick front along the north side, a wing of them across the end
/// of the road. Across it Via
/// Cavour goes south between the blocks, straight, cars left parked along
/// both kerbs, a sheet strung across it with the end of the world painted
/// on it, down to Piazza di Santa Maria Maggiore: the basilica `"` on the
/// north side of the square, right against the street so its bell tower
/// is seen all the way down, half fallen, its rubble spilt over the
/// pavement (`"` too), the Column of Peace `>` in front of it and a
/// placard `` ` `` stuck up on the square; palazzi either side of it, and
/// across the street a bar and a trattoria, their tables `Q` and chairs
/// `q` still out on the square, and an accountants' office, all shut up,
/// a palazzo with no shop between each of them and the next. The square
/// ends a palazzo past the accountants, a few more café tables and chairs
/// out in its south-east corner. A road runs off it west and one east,
/// as far each way, and two south between the blocks like Via Cavour:
/// the map ends there, and west of the square it is an L, nothing ` `
/// past the corner. Via Cavour's line goes on across the square in
/// sampietrini `°`, framed in travertine, and turns at right angles into
/// the two roads south. Across the line from the Column of Peace, as far
/// from it, stands a second column `>`, its saint still up.
///
/// East of Termini the road goes on past the end of the piazza, between
/// the palazzi, to a roadblock where the carabinieri and the police made
/// their stand and lost: their cars right across it from pavement to
/// pavement, nosed a cell forward or back of one another, carabinieri `m`
/// and police `s` on their roofs, `u` and `w` still on their wheels, every
/// one of them on fire, a tank `t` stopped in front of them, the
/// carabinieri come back as the dead `r` round it and a backpack `9` by the tank. In the middle
/// lane there is a gap with no car in it, only fuel burning `?`: it looks
/// like the way through, and looking at it says what it would take. Past
/// the roadblock the road runs off the map.
// piazza-cinquecento-rows-start
const List<String> piazzaCinquecentoRows = <String>[
  '§§§§§§§§§§§§§§§§§§§BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBB',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBB',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBB',
  '§§§§§§§§§¶§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]{{]]]]]]]]]]]]]{{]]]]]]]]]]]]]{{]]]]HHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBB',
  '§§§§============¤============================================================================================================BBBBBBBBBBBBBBBB',
  '§§§§PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHH',
  '§§§§PPPPPPPPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPP:PPPnnPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHH',
  '§§§§PPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHH',
  '§§§§PPPPAPPPPPPPAPPPPPPPAPPPPPPPAPPPPPPPAPPPPPPAPPPPPPPPPPPAPPPPPPPPPPPPPPPAPPPPPPPSPAPPPPPPPPPPPPPAPPPPPPPPPPPPPAPPPPPPAPPPPHHHHHHHHHHHHHHHH',
  '§§§§===============================================================================================================================mm========',
  '§§§§=.............................CC........................................................UU.........................UU...:..r..ww.........',
  '§§§§=....d............XX.............................CC.................:....................................d............9..r..rmm....:.....',
  '§§§§=-----------------------------------------------------------------------------------------------------------------------------??---------',
  '§§§§=.........UU........................:......................d......XX...............................CC..................ttttr...ss........',
  '§§§§=.......................d....................................................................:.........................tttt..ruu.........',
  '§§§§========================================================================VVVVVV===============================================ss==========',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|.d.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...FBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB""""""""""""""""""""""":..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=v.|.:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""/..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|D.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|:..=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBB=====================""""""====°°°°°°======================================BBBBBBBBBBBBBBBBBBBBB',
  '                        HHHHHHHHHHHHHHHHHHHHHPPPPPPPPPPPPPPPPPPP:PP"""PPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHHHHHHH',
  '                        HHHHHHHHHHHHHHHHHHHHHPPPPPPPPPPPP:PPPPPPPPPPPPP:PPPP°°°°°°PPPqQqqQPPPPqQqqQqqQqPPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHHHHHHH',
  '                        HHHHHHHHHHHHHHHHHHHHHPPPP```PPPPPPPPPPPPPPPPPPPPP:PP°°°°°°PPPPPPPPqPPPPPPPPPPPPqPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHHHHHHH',
  '                        HHHHHHHHHHHHHHHHHHHHHPPPPPPPPPPPPPPPPPP>PPPPPPPPPPPPd°°°°°PPPqQqPqPPPP>PQqPPQqPPPPPPPPPPPPPPPPPPHHHHHHHHHHHHHHHHHHHHH',
  '                        =====================PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP°°°°°°P:PPPPPXXPPPPPPPPPPPPPPPPPPPPPPPPPPPPP=====================',
  '                        ........d...........=PPPPPPPP:PPPPPPPPPPPPPPPPPPPDPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPdPPPPPPPPPPP=...CC...............',
  '                        ..:.................=PPPPPPPPPPPPPPPPPPPP:PPPPPPPPPP°°°°°°PPPPPPPPPPPPP:PPPPPPPPPPPUUPPPPPPPPPPP=........:...........',
  '                        --------------------=PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP=--------------------',
  '                        ....................=PPPPPPPPPPPPPP°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°PPPPPPPPPPPPPPPPPPPPP=................d...',
  '                        ...CC...............=PPPPPPPPPPPPPP°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°PPPPPPPPPPPPPDPPPPPPP=............CC......',
  '                        ....................=PPPPPPP:PPPPPP°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°PPPPPPPPPPPPPPPPPPPPP=....................',
  '                        =====================PPPPPPPPPPPPPP°°°°°°°°°°°°°°°°°°°°°°°°°°°°°:°°°°°°°°°°PPPPPPPPPPPPPPPPPPPPP=====================',
  '                        BBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPPP°°°°°°PPPPPP:PqQqPPqQqPPPPPBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPP°°°°°°PPPPPdPPPPPPPPPPPPPPPPPPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBPPP:PPPPPPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPPP°°°°°°PPPPPPqQqPPqQqPPqQqPPBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPP°°°°°°PPPPPPPPPPPPPPPPPPPPPPPPPPPP°°°°°°PPPPPPPPPPqPPPPPPPPPPBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBB==============°°°°°°============================°°°°°°=====================BBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBB=d.|.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                        BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBB=..|.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// piazza-cinquecento-rows-end

/// Where the camera stops short of the piazza's edges, so it never shows
/// what is off the map ` ` west of Via Cavour and the square below: in the
/// west of the piazza in front of Termini, at the roofs under it; from Via
/// Cavour down, at the square's west end, as if the map began there. Each
/// zone begins where its edge is still out of view, so the camera slides
/// to it unseen. test/camera_zones_test.dart holds them to it.
const List<CameraZone> piazzaCinquecentoCameraZones = <CameraZone>[
  CameraZone(area: GridRect(0, 0, 55, 16), limits: GridRect(0, 0, 140, 19)),
  CameraZone(area: GridRect(0, 17, 140, 63), limits: GridRect(24, 0, 140, 63)),
];

/// Via Marsala, the street behind the station, reached through the breach
/// `}` in the wall `%` round the tracks: the fronts of its palazzi across
/// the road, their shops shut like everywhere else (the pizza by the
/// slice, a second souvenir shop), and between them the
/// bank `£`, a wall: shut, vandalised, LA BANCA È L'EMBLEMA sprayed across
/// it. The palazzo just past it has its portone `«` open, a door. West the
/// road is closed by a pile-up of burning cars from house front to house
/// front, as behind the hypermarket in Molfetta: in the middle lane there
/// is a gap with no car in it, only fuel burning `?`, and looking at it says
/// what it would take; past it the road runs on off the map. East the
/// street simply ends against the palazzi, past a strip of pavement down
/// the end of it: their roofs come down the edge of the map from those
/// over the street, as at the ends of Molfetta's streets. The wall along
/// the bottom is the last of it: the station is past it, not more houses.
// via-marsala-rows-start
const List<String> viaMarsalaRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHHHHHHHH££££££££££££HHHHHHHHHHHHHHHHHHHHHHBBBB',
  'HHHHHHHHHHHHHHHHHHHHHH££££££££££££HHHHHHHHHHHHHHHHHHHHHHBBBB',
  'HHHHHHHHHHHHHHHHHHHHHH££££££££££££HHHHHHHHHHHHHHHHHHHHHHBBBB',
  'HHHHHHHHHHHHHHHHHHHHHH££££££££££££H«HHHHHHHHHHHHHHHHHHHHBBBB',
  'CC===============================:======================BBBB',
  '.XX.................:...................XX.............=BBBB',
  '???----------------------------------------------------=BBBB',
  '?XX.........CC.........................................=BBBB',
  '.XX..........................................:....UU...=BBBB',
  'CC======:=================F=============================BBBB',
  '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%}}%%%%%%%%%%%%%%%%%%%%%%%%%%%%',
];
// via-marsala-rows-end
