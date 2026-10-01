import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

export 'package:stepbound/core/levels/rome/bank.dart';
export 'package:stepbound/core/levels/rome/rome_palazzo.dart';
export 'package:stepbound/core/levels/rome/rome_streets.dart';
export 'package:stepbound/core/levels/rome/terme.dart';
export 'package:stepbound/core/levels/rome/termini.dart';
export 'package:stepbound/core/levels/rome/termini_station.dart';

/// Roma Termini (termini.dart) keeps to the far platform's glyphs, but
/// its train's door `P` is open from the start: the train is Mario's own.
/// The name board high on the wall `Q` is wall, the one on its posts at
/// the platform's edge `o` can be seen over.
const Legend terminiLegend = Legend(walls: 'xWMQ|', obstacles: 'Tno');

/// The overpass: the choked flights `#`, the barred ones `H`, the
/// timetables `Q` and the pillars `I` are wall; the ticket machines `K`
/// and the benches `T` can be seen over.
const Legend terminiOverpassLegend = Legend(walls: 'xW|w#HQI', obstacles: 'KT');

/// The far platform: the train left on the far track `m`, the rubbish
/// `;` and the derailed train `V` are walls.
const Legend terminiFarPlatformLegend = Legend(
  walls: 'xWwmV;',
  obstacles: 'Tn',
);

/// The concourse: its shops `S`, the departures board `Q`, the pillars
/// `I`, the kiosk `i` and the fallen ceiling `#` are wall; the ticket
/// machines `K`, benches `T` and trolleys `y` can be seen over.
const Legend terminiConcourseLegend = Legend(
  walls: 'xW|wSQIi#',
  obstacles: 'KTy',
);

/// Rome's streets: Molfetta's outdoor legend, with the front of Termini
/// `]`, Santa Maria Maggiore `"` and the Baths of Diocletian `§` walls,
/// and the Column of Peace `>`, the placards `` ` ``, the Baths' brown
/// sign `¤`, the carabinieri and police cars (`m` and `s` on their roofs,
/// `u` and `w` on their wheels) and the tank `t` obstacles.
const Legend romeStreetLegend = Legend(
  walls: 'BHfKMGW#%0_]"§£',
  obstacles: 'CXUvkDFTSOyJQaAnI~RNbpx*i&!^;/+>`¤mstuw',
  debris: ':q',
  fire: '?',
);

/// The palazzo beside the bank on Via Marsala (rome_palazzo.dart): its
/// walls, partitions and letterboxes are solid, what furnishes a flat stops
/// a step but not a shot, as in Molfetta's palazzo.
const Legend romePalazzoLegend = Legend(
  walls: 'xWwILM',
  obstacles: 'SaVThBnAlKOFHQRpr',
);

/// Inside the bank on Via Marsala (bank.dart): its walls, the vault's and
/// the safe-deposit boxes are solid; the glass walls, the furniture, the
/// shelves and the vault's door stop a step but not a shot; the papers and
/// the ceiling tiles on the floor crunch.
const Legend bankLegend = Legend(walls: 'xWwIQB', obstacles: 'GTKhlSCPpLor');

/// Its roof and the bank's: the drop and the tiled roofs all round are
/// walls, and so is the stairwell's little house; the parapets, the broken
/// stretches of them and what stands on the roofs can be seen over; the
/// gravel and the rubble crunch.
const Legend romeRoofLegend = Legend(
  walls: 'xRH',
  obstacles: '^<>TnlapskoS',
  debris: ':,',
);

/// The palazzo's stairwell on every floor, from its back wall to its front
/// wall, lit throughout (see `PlaceSpec.litAreas`).
const GridRect romePalazzoStairwell = GridRect(12, 1, 17, 13);

/// Inside the Baths of Diocletian (terme.dart): the walls, the columns `O`
/// and the high altar `A` shut the way and the sight; the pews `T` and the
/// column drum `K` can be seen over.
const Legend termeLegend = Legend(walls: 'xWIwOA', obstacles: 'TK');

/// Rome, the second level: Roma Termini and the two streets round it, on
/// the same grid as Molfetta. The train is the one place the two levels
/// share, and there is no road between them.
const List<PlaceSpec> romePlaces = <PlaceSpec>[
  PlaceSpec(
    id: PlaceId.romeTermini,
    area: AreaId.romeTermini,
    rows: terminiRows,
    legend: terminiLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.terminiOverpass,
    area: AreaId.romeTermini,
    rows: terminiOverpassRows,
    legend: terminiOverpassLegend,
    indoor: true,
    darkness: 0.8,
    // Daylight up the two open flights, and from the concourse.
    daylight: 'DUE',
  ),
  // Open to the sky over the tracks, so lit throughout.
  PlaceSpec(
    id: PlaceId.terminiFarPlatform,
    area: AreaId.romeTermini,
    rows: terminiFarPlatformRows,
    legend: terminiFarPlatformLegend,
  ),
  // The concourse's glass front and roof let the day in: it is lit.
  PlaceSpec(
    id: PlaceId.terminiConcourse,
    area: AreaId.romeTermini,
    rows: terminiConcourseRows,
    legend: terminiConcourseLegend,
    indoor: true,
    lit: true,
  ),
  PlaceSpec(
    id: PlaceId.piazzaCinquecento,
    area: AreaId.romeStreets,
    rows: piazzaCinquecentoRows,
    legend: romeStreetLegend,
    cameraZones: piazzaCinquecentoCameraZones,
  ),
  PlaceSpec(
    id: PlaceId.viaMarsala,
    area: AreaId.romeStreets,
    rows: viaMarsalaRows,
    legend: romeStreetLegend,
  ),
  // The palazzo on Via Marsala: its hall lit, with daylight through the
  // portone; its landings lit, its flats dim. Painted from their rows out
  // of the tile atlas, and so is its roof, open to the sky.
  PlaceSpec(
    id: PlaceId.romePalazzoGround,
    area: AreaId.romeStreets,
    rows: romePalazzoGroundFloorRows,
    legend: romePalazzoLegend,
    indoor: true,
    lit: true,
    daylight: 'E',
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.romePalazzoFirst,
    area: AreaId.romeStreets,
    rows: romePalazzoFirstFloorRows,
    legend: romePalazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    litAreas: <GridRect>[romePalazzoStairwell],
    // Light from the landing through the flats' doors, kicked in.
    openDoors: 'P',
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.romePalazzoSecond,
    area: AreaId.romeStreets,
    rows: romePalazzoSecondFloorRows,
    legend: romePalazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    litAreas: <GridRect>[romePalazzoStairwell],
    // Light from the landing through the flats' doors, kicked in.
    openDoors: 'P',
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.romePalazzoRoof,
    area: AreaId.romeStreets,
    rows: romePalazzoRoofRows,
    legend: romeRoofLegend,
    name: 'Tetti di via Marsala',
  ),
  // The bank: dark but for the lamps still on, and the daylight down the
  // stairs from its roof.
  PlaceSpec(
    id: PlaceId.bankOffices,
    area: AreaId.romeStreets,
    rows: bankOfficesRows,
    legend: bankLegend,
    indoor: true,
    darkness: 0.78,
    daylight: 'U',
    name: 'Banca',
  ),
  PlaceSpec(
    id: PlaceId.bankVault,
    area: AreaId.romeStreets,
    rows: bankVaultRows,
    legend: bankLegend,
    indoor: true,
    darkness: 0.76,
    name: 'Caveau della banca',
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.termeDiocleziano,
    area: AreaId.romeStreets,
    rows: termeRows,
    legend: termeLegend,
    indoor: true,
    // The open portal, and the thermal windows high in the walls.
    daylight: 'E^',
  ),
];

final Place _termini = place(PlaceId.romeTermini);
final Place _overpass = place(PlaceId.terminiOverpass);
final Place _farPlatform = place(PlaceId.terminiFarPlatform);
final Place _concourse = place(PlaceId.terminiConcourse);
final Place _piazza = place(PlaceId.piazzaCinquecento);
final Place _marsala = place(PlaceId.viaMarsala);
final Place _terme = place(PlaceId.termeDiocleziano);
final Place _palazzoGround = place(PlaceId.romePalazzoGround);
final Place _palazzoFirst = place(PlaceId.romePalazzoFirst);
final Place _palazzoSecond = place(PlaceId.romePalazzoSecond);
final Place _palazzoRoof = place(PlaceId.romePalazzoRoof);
final Place _bankOffices = place(PlaceId.bankOffices);
final Place _bankVault = place(PlaceId.bankVault);

/// The backpack with the grappling hook, left before the high altar of
/// Santa Maria degli Angeli, in the great hall of the Baths.
final GridPoint grapplingHookTile = _onGrid(
  PlaceId.termeDiocleziano,
  const GridPoint(20, 5),
);
const String grapplingHookPickupId = 'grappling-hook';

/// The backpacks a small light blinks over for as long as they lie there,
/// so they can be found in the dark: the grappling hook's, in the far end
/// of the Baths' great hall, which none of its windows reaches.
const Set<String> beaconPickupIds = <String>{grapplingHookPickupId};

/// The portal of Santa Maria degli Angeli, in the front of the Baths of
/// Diocletian where the road past Termini ends: the way inside.
final GridPoint termePortalTile = _piazza.tileOf('¶');

/// The passenger door of the train standing at Roma Termini, open onto
/// the platform.
final GridPoint terminiTrainDoorTile = _termini.tileOf('P');

/// The flight up from the platform the train stands at, to the overpass:
/// got onto from the north, two steps deep.
final List<GridPoint> terminiStairsTiles = _termini.tilesOf('D');

/// The last steps of [terminiStairsTiles]: the door up to the overpass.
final List<GridPoint> terminiStairsFoot = lastSteps(
  terminiStairsTiles,
  Direction.south,
);

/// The flight up from the far platform to the overpass, like the other.
final List<GridPoint> terminiFarStairs = _farPlatform.tilesOf('D');

/// The last steps of [terminiFarStairs]: the door up to the overpass.
final List<GridPoint> terminiFarStairsFoot = lastSteps(
  terminiFarStairs,
  Direction.south,
);

/// Rome's flights of stairs, each with the way onto it: only from its
/// head, as in Molfetta (see `WorldState.canStep`).
final Map<GridPoint, Direction> romeStairs = <GridPoint, Direction>{
  for (final step in terminiStairsTiles) step: Direction.south,
  for (final step in terminiFarStairs) step: Direction.south,
  for (final step in bankRoofStairs) step: Direction.south,
};

/// The one flight down from the overpass to the far platform.
final List<GridPoint> terminiFarFlightTiles = _overpass.tilesOf('U');

/// The breach in the far platform's back wall, out onto Via Marsala.
final List<GridPoint> terminiBreachTiles = _farPlatform.tilesOf('J');

/// The wanderers of Rome, in each place's own tile coordinates: the art
/// has no glyph for them.
const Map<PlaceId, List<GridPoint>> romeZombieSpots =
    <PlaceId, List<GridPoint>>{
      PlaceId.romeTermini: terminiZombieSpots,
      PlaceId.terminiOverpass: <GridPoint>[
        GridPoint(10, 6),
        GridPoint(36, 9),
        GridPoint(55, 5),
      ],
      PlaceId.terminiFarPlatform: <GridPoint>[
        GridPoint(20, 7),
        GridPoint(60, 7),
        GridPoint(78, 5),
        GridPoint(87, 10),
      ],
      PlaceId.terminiConcourse: <GridPoint>[
        GridPoint(15, 5),
        GridPoint(40, 10),
        GridPoint(22, 17),
        GridPoint(48, 15),
      ],
      PlaceId.piazzaCinquecento: <GridPoint>[
        // On the road west to the Baths of Diocletian.
        GridPoint(12, 11),
        GridPoint(30, 14),
        GridPoint(57, 12),
        GridPoint(85, 14),
        GridPoint(105, 8),
        GridPoint(79, 24),
        GridPoint(77, 33),
        GridPoint(57, 44),
        GridPoint(81, 45),
        GridPoint(97, 42),
        // Further down the square, and in the four roads off it.
        GridPoint(104, 53),
        GridPoint(37, 48),
        GridPoint(131, 46),
        GridPoint(62, 63),
        GridPoint(96, 60),
        // On the pavement across the top, halfway between the Baths of
        // Diocletian and the front of Termini: last, so that the ones
        // before it keep their ids in the saves.
        GridPoint(36, 7),
      ],
      PlaceId.termeDiocleziano: <GridPoint>[
        GridPoint(10, 8),
        GridPoint(25, 5),
        GridPoint(33, 11),
        GridPoint(21, 16),
      ],
      PlaceId.romePalazzoGround: <GridPoint>[GridPoint(4, 6)],
      PlaceId.romePalazzoFirst: <GridPoint>[GridPoint(9, 4), GridPoint(20, 4)],
      PlaceId.romePalazzoSecond: <GridPoint>[GridPoint(3, 4)],
      PlaceId.romePalazzoRoof: <GridPoint>[GridPoint(32, 10), GridPoint(10, 7)],
      PlaceId.bankOffices: <GridPoint>[
        GridPoint(5, 6),
        GridPoint(12, 10),
        GridPoint(24, 5),
      ],
      PlaceId.bankVault: <GridPoint>[GridPoint(6, 8)],
      PlaceId.viaMarsala: <GridPoint>[
        GridPoint(15, 9),
        GridPoint(38, 7),
        GridPoint(52, 6),
      ],
    };

/// The backpack left in a hollow of the rubbish over the far platform's
/// tracks, west, with two rounds in it.
const String terminiRubbishBackpackId = 'termini-rubbish-backpack';

/// Where it lies, in the far platform's own tile coordinates: on the
/// rails, between the heap and a clump fallen off it.
const GridPoint terminiRubbishBackpackSpot = GridPoint(5, 10);

/// The campfire on Piazza dei Cinquecento, in front of Termini.
final GridPoint piazzaCampfireTile = _piazza.tileOf('S');

/// The campfire on the terrace of the palazzo beside the bank, on Via
/// Marsala, towards its south-east corner.
final GridPoint terraceCampfireTile = _palazzoRoof.tileOf('S');

/// Rome's campfires, by tile, with the name shown in the save slots.
final Map<GridPoint, String> romeCampfireNames = <GridPoint, String>{
  piazzaCampfireTile: 'Piazza dei Cinquecento',
  terraceCampfireTile: 'Terrazza di via Marsala',
};

/// The one sprinter of Rome, loose on the piazza.
const GridPoint piazzaSprinterSpot = GridPoint(67, 12);

/// The brute standing in the way out of the far platform: on the tracks
/// just short of the breach onto Via Marsala, the back way out of Termini,
/// in the far platform's own tile coordinates. Rome's first, and the
/// game's.
const String terminiBruteId = 'termini-brute';
const GridPoint terminiBruteSpot = GridPoint(84, 4);

/// The backpack left on the ballast against the back wall, a few steps
/// east of the breach onto Via Marsala and of the brute standing in front
/// of it, with two rounds in it: picking it up means getting past him. In
/// the far platform's own tile coordinates.
const String terminiBreachBackpackId = 'termini-breach-backpack';
const GridPoint terminiBreachBackpackSpot = GridPoint(88, 3);

/// The wanderers on the platforms of Termini, `termini-wanderer-<n>`.
const String terminiZombiePrefix = 'termini-wanderer-';

/// The glyphs of the roadblock's cars: carabinieri and police, on their
/// roofs and on their wheels.
const String roadblockCarGlyphs = 'msuw';

/// The roadblock east of Termini on the piazza's road: the carabinieri
/// and police cars across it, every one of them burning, from
/// pavement to pavement, one flame on the first cell of each.
final List<FireSpot> roadblockFireSpots = <FireSpot>[
  for (final glyph in roadblockCarGlyphs.split(''))
    for (final tile in _piazza.tilesOf(glyph))
      if (_piazza.rows[tile.y - _piazza.origin.y][tile.x -
              _piazza.origin.x -
              1] !=
          glyph)
        FireSpot(tile, FireKind.car),
];

/// The gap in the roadblock, in the middle lane between two of the
/// burning cars: no car in it, only their fuel alight `?`. It is the way
/// through that is not one; its west end is where Mario looks at it.
final GridPoint roadblockFireTile = _piazza
    .tilesOf('?')
    .reduce((a, b) => a.x < b.x ? a : b);

/// The east end of the fuel burning across the middle lane of Via
/// Marsala's pile-up, west: the gap that looks like a way through. Looking
/// at it says what it would take.
final GridPoint marsalaFireTile = _marsala
    .tilesOf('?')
    .reduce((a, b) => a.x > b.x || (a.x == b.x && a.y < b.y) ? a : b);

/// The portone of the palazzo beside the bank on Via Marsala, open, and
/// the same portone from inside its hall.
final GridPoint marsalaPortoneTile = _marsala.tileOf('«');
final GridPoint romePalazzoPortone = _palazzoGround.tileOf('E');

/// The palazzo's stairs, bottom to top: on each floor the flight `U` up
/// and the one `D` down on the floor above.
final List<(GridPoint, GridPoint)> romePalazzoFlights =
    <(GridPoint, GridPoint)>[
      (_palazzoGround.tileOf('U'), _palazzoFirst.tileOf('D')),
      (_palazzoFirst.tileOf('U'), _palazzoSecond.tileOf('D')),
    ];

/// The top of the stairwell, on the second floor, and the door of its
/// little house on the terrace it comes out of.
final GridPoint romePalazzoRoofStairs = _palazzoSecond.tileOf('U');
final GridPoint romeTerraceDoor = _palazzoRoof.tileOf('D');

/// The stretch of the terrace's parapet knocked down low, over the drop
/// to the bank's roof: where Mario measures the gap, and swings across it
/// with the grappling hook.
final GridPoint romeTerraceLookoutTile = _palazzoRoof.tileOf('<');

/// The bank's parapet, broken, straight across from
/// [romeTerraceLookoutTile]: the way back with the hook.
final GridPoint bankRoofEdgeTile = _palazzoRoof.tileOf('>');

/// The stairs `v` going down into the bank from its roof, two steps deep:
/// the last is the door down into its offices.
final List<GridPoint> bankRoofStairs = _palazzoRoof.tilesOf('v');
final List<GridPoint> bankRoofStairsFoot = lastSteps(
  bankRoofStairs,
  Direction.south,
);

/// Where the grappling hook crosses in Rome: from the terrace to the
/// bank's roof and back, each landing Mario just inside the other edge.
final Map<GridPoint, Portal> romeGrapples = <GridPoint, Portal>{
  romeTerraceLookoutTile: Portal(
    to: bankRoofEdgeTile.step(Direction.west),
    facing: Direction.west,
  ),
  bankRoofEdgeTile: Portal(
    to: romeTerraceLookoutTile.step(Direction.east),
    facing: Direction.east,
  ),
};

/// The bank's stairs: up from its offices to the roof, and down from them
/// to the vault, and up from the vault again.
final List<GridPoint> bankOfficesStairsUp = _bankOffices.doorRow('U');
final List<GridPoint> bankOfficesStairsDown = _bankOffices.doorRow('D');
final List<GridPoint> bankVaultStairsUp = _bankVault.doorRow('U');

/// The backpack left in the middle of the open vault, and the gold ingot
/// in it: what Tonino and Marcello will take to let Mario by.
const String bankIngotBackpackId = 'bank-vault-ingot';
final GridPoint bankIngotTile = _bankVault.tileOf('9');

/// Rome's doors to places not drawn yet: none, for now.
final Set<GridPoint> romeWorkInProgressDoors = <GridPoint>{};

/// The big dead of the buildings on Via Marsala, in each place's own
/// tiles: one to each of the palazzo's floors under the roof, two in the
/// bank's offices and two in its vault, one of them by the ingot.
const Map<PlaceId, List<GridPoint>> romeBrutes = <PlaceId, List<GridPoint>>{
  PlaceId.romePalazzoGround: <GridPoint>[GridPoint(20, 6)],
  PlaceId.romePalazzoFirst: <GridPoint>[GridPoint(23, 11)],
  PlaceId.romePalazzoSecond: <GridPoint>[GridPoint(23, 9)],
  PlaceId.bankOffices: <GridPoint>[GridPoint(6, 10), GridPoint(25, 4)],
  PlaceId.bankVault: <GridPoint>[GridPoint(22, 5), GridPoint(8, 5)],
};

/// The carabinieri come back as the dead round the roadblock `r`, and the
/// backpack `9` one of them dropped by the tank.
final List<GridPoint> roadblockCarabiniereTiles = _piazza.tilesOf('r');
const String roadblockCarabinierePrefix = 'roadblock-carabiniere-';
const String roadblockBackpackId = 'roadblock-backpack';
final GridPoint roadblockBackpackTile = _piazza.tileOf('9');

/// The fires burning in Rome's streets, and the campfire on the terrace.
final List<FireSpot> romeFireSpots = <FireSpot>[
  for (final street in <Place>[_piazza, _marsala, _palazzoRoof])
    ...firesIn(street),
  ...roadblockFireSpots,
];

/// The doors of Rome's station, both ways: the stairs up from the
/// platform to the overpass and the one flight on down to the far
/// platform (every flight is in the back wall of the overpass, and climbs
/// through the front wall of a platform and one cell past it), the
/// overpass's opening onto the concourse
/// and the concourse's three doorways onto the piazza (each lands Mario a
/// step past the door, facing on), and the breach out of the far platform
/// onto Via Marsala, and the portal of the Baths of Diocletian.
Map<GridPoint, Portal> _portals() => <GridPoint, Portal>{
  // Up the last step of each flight onto the overpass, and back down onto
  // the step above it, facing down the flight.
  ...pairedDoors(terminiStairsFoot, _overpass.tilesOf('D'), Direction.south),
  ...backOntoFlight(_overpass.tilesOf('D'), terminiStairsFoot),
  ...backOntoFlight(terminiFarFlightTiles, terminiFarStairsFoot),
  ...pairedDoors(terminiFarStairsFoot, terminiFarFlightTiles, Direction.south),
  ...pairedDoors(
    _overpass.tilesOf('E'),
    _concourse.tilesOf('E'),
    Direction.south,
  ),
  ...pairedDoors(
    _concourse.tilesOf('E'),
    _overpass.tilesOf('E'),
    Direction.north,
  ),
  ...pairedDoors(
    _concourse.tilesOf('O'),
    _piazza.tilesOf('{'),
    Direction.south,
  ),
  ...pairedDoors(
    _piazza.tilesOf('{'),
    _concourse.tilesOf('O'),
    Direction.north,
  ),
  // Through the portone of the palazzo on Via Marsala and back, up its
  // stairs floor by floor, and from the top of them onto its terrace.
  ...pairedDoors(
    <GridPoint>[marsalaPortoneTile],
    <GridPoint>[romePalazzoPortone],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[romePalazzoPortone],
    <GridPoint>[marsalaPortoneTile],
    Direction.south,
  ),
  for (final (below, above) in romePalazzoFlights) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
  // Down from the bank's roof into its offices and back up onto the step
  // above the last, and on down to the vault.
  ...pairedDoors(bankRoofStairsFoot, bankOfficesStairsUp, Direction.south),
  ...backOntoFlight(bankOfficesStairsUp, bankRoofStairsFoot),
  ...pairedDoors(bankOfficesStairsDown, bankVaultStairsUp, Direction.south),
  ...pairedDoors(bankVaultStairsUp, bankOfficesStairsDown, Direction.north),
  romePalazzoRoofStairs: Portal(
    to: romeTerraceDoor.step(Direction.south),
    facing: Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[romeTerraceDoor],
    <GridPoint>[romePalazzoRoofStairs],
    Direction.south,
  ),
  ...pairedDoors(terminiBreachTiles, _marsala.tilesOf('}'), Direction.north),
  ...pairedDoors(_marsala.tilesOf('}'), terminiBreachTiles, Direction.south),
  ...pairedDoors(
    <GridPoint>[termePortalTile],
    _terme.tilesOf('E'),
    Direction.north,
  ),
  ...pairedDoors(_terme.tilesOf('E'), <GridPoint>[
    termePortalTile,
  ], Direction.south),
};

/// What Rome holds when a game starts: the dead wandering Termini and
/// the streets round it, the carabinieri at the roadblock east of the
/// piazza, a backpack in the rubbish, one by the breach onto Via Marsala,
/// one by the tank and the grappling
/// hook in the Baths of Diocletian, the station's doors, and the fire in
/// the roadblock's gap to look at.
LevelContents romeContents(EntityFactory factory) => LevelContents(
  entities: <Entity>[
    for (final MapEntry(key: id, value: spots) in romeZombieSpots.entries)
      for (final (index, spot) in spots.indexed)
        factory.zombie(
          id: id == PlaceId.romeTermini
              ? '$terminiZombiePrefix$index'
              : '${id.name}-wanderer-$index',
          kind: EntityKind.wanderer,
          position: _onGrid(id, spot),
        ),
    factory.zombie(
      id: terminiBruteId,
      kind: EntityKind.brute,
      position: _onGrid(PlaceId.terminiFarPlatform, terminiBruteSpot),
    ),
    factory.zombie(
      id: 'piazza-sprinter',
      kind: EntityKind.sprinter,
      position: _onGrid(PlaceId.piazzaCinquecento, piazzaSprinterSpot),
    ),
    for (final MapEntry(key: id, value: spots) in romeBrutes.entries)
      for (final (index, spot) in spots.indexed)
        factory.zombie(
          id: '${id.name}-brute-$index',
          kind: EntityKind.brute,
          position: _onGrid(id, spot),
        ),
    for (final (index, tile) in roadblockCarabiniereTiles.indexed)
      factory.zombie(
        id: '$roadblockCarabinierePrefix$index',
        kind: EntityKind.carabiniere,
        position: tile,
      ),
  ],
  pickups: <Pickup>[
    Pickup(
      id: terminiRubbishBackpackId,
      position: _onGrid(PlaceId.terminiFarPlatform, terminiRubbishBackpackSpot),
      ammo: 2,
    ),
    Pickup(
      id: terminiBreachBackpackId,
      position: _onGrid(PlaceId.terminiFarPlatform, terminiBreachBackpackSpot),
      ammo: 2,
    ),
    Pickup(id: roadblockBackpackId, position: roadblockBackpackTile, ammo: 2),
    Pickup(id: bankIngotBackpackId, position: bankIngotTile, goldIngot: true),
    Pickup(
      id: grapplingHookPickupId,
      position: grapplingHookTile,
      grapplingHook: true,
    ),
  ],
  portals: _portals(),
  stairs: romeStairs,
  grapples: romeGrapples,
  lookouts: <GridPoint>[
    roadblockFireTile,
    marsalaFireTile,
    romeTerraceLookoutTile,
    // Tonino and Marcello, to talk to once they have had the ingot.
    toninoTile,
    marcelloTile,
  ],
);

GridPoint _onGrid(PlaceId id, GridPoint spot) {
  final origin = place(id).origin;
  return GridPoint(origin.x + spot.x, origin.y + spot.y);
}

/// Where Via Cavour comes out on Piazza di Santa Maria Maggiore, in the
/// piazza's own tile coordinates: the pavement of the square's north side,
/// the row past the last one the street runs between the blocks.
const int _cavourEnd = 39;

/// Marcello er Criminale, the Lazio lad, and Tonino Cacio e Pepe, the Roma
/// one, side by side on the square right where Via Cavour comes out,
/// facing up it towards Termini: nobody gets onto the square past them.
final GridPoint marcelloTile = _onGrid(
  PlaceId.piazzaCinquecento,
  const GridPoint(78, _cavourEnd),
);
final GridPoint toninoTile = _onGrid(
  PlaceId.piazzaCinquecento,
  const GridPoint(79, _cavourEnd),
);

/// Where Tonino and Marcello have their say, every time in the same
/// place: the last stretch of Via Cavour, the two of them in full view at
/// the bottom of it, and the whole square past them. Walking into it plays
/// the meeting; once they have met Mario, the gold ingot is handed over
/// there and then, and without it a step in here gets him sent back up
/// the street.
bool onMaranzaTurf(GridPoint tile) =>
    _maranzaStreet.contains(tile) || _maranzaSquare.contains(tile);

final GridRect _maranzaStreet = _rectOnGrid(
  PlaceId.piazzaCinquecento,
  const GridRect(75, _cavourEnd - 5, 82, _cavourEnd - 1),
);
final GridRect _maranzaSquare = _rectOnGrid(
  PlaceId.piazzaCinquecento,
  GridRect(0, _cavourEnd, _piazza.width - 1, _piazza.height - 1),
);

GridRect _rectOnGrid(PlaceId id, GridRect rect) {
  final origin = place(id).origin;
  return GridRect(
    origin.x + rect.left,
    origin.y + rect.top,
    origin.x + rect.right,
    origin.y + rect.bottom,
  );
}
