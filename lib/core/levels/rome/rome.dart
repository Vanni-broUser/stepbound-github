import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

export 'package:stepbound/core/levels/rome/rome_streets.dart';
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
/// `]` and Santa Maria Maggiore `"` walls, and the Column of Peace `>`
/// and the placards `` ` `` obstacles.
const Legend romeStreetLegend = Legend(
  walls: 'BHfKMGW#%0_]"',
  obstacles: 'CXUvkDFTSOyJQaAnI~RNbpx*i&!^;/+>`',
  debris: ':q',
  fire: '?',
);

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
  ),
  PlaceSpec(
    id: PlaceId.viaMarsala,
    area: AreaId.romeStreets,
    rows: viaMarsalaRows,
    legend: romeStreetLegend,
  ),
];

final Place _termini = place(PlaceId.romeTermini);
final Place _overpass = place(PlaceId.terminiOverpass);
final Place _farPlatform = place(PlaceId.terminiFarPlatform);
final Place _concourse = place(PlaceId.terminiConcourse);
final Place _piazza = place(PlaceId.piazzaCinquecento);
final Place _marsala = place(PlaceId.viaMarsala);

/// The passenger door of the train standing at Roma Termini, open onto
/// the platform.
final GridPoint terminiTrainDoorTile = _termini.tileOf('P');

/// The stairs up from the platform the train stands at, to the overpass.
final List<GridPoint> terminiStairsTiles = _termini.tilesOf('D');

/// The one flight down from the overpass to the far platform.
final List<GridPoint> terminiFarFlightTiles = _overpass.tilesOf('U');

/// The breach in the far platform's back wall, out onto Via Marsala.
final List<GridPoint> terminiBreachTiles = _farPlatform.tilesOf('J');

/// Where Rome ends for now: every tile at the map's edge where one of its
/// streets runs off it, with the way back into the street. Stepping on
/// one ends the demo.
final Map<GridPoint, Direction> romeStreetEnds = <GridPoint, Direction>{
  for (final street in <Place>[_piazza, _marsala]) ..._endsOf(street),
};

Map<GridPoint, Direction> _endsOf(Place street) => <GridPoint, Direction>{
  for (final tile in street.walkableRow(street.height - 1))
    tile: Direction.north,
  for (var y = 0; y < street.height; y++)
    for (final (x, back) in <(int, Direction)>[
      (0, Direction.east),
      (street.width - 1, Direction.west),
    ])
      if (Tile(street.kindOf(street.rows[y][x])).isWalkable)
        GridPoint(street.origin.x + x, street.origin.y + y): back,
};

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
        GridPoint(12, 12),
        GridPoint(40, 14),
        GridPoint(60, 8),
        GridPoint(34, 24),
        GridPoint(32, 33),
        GridPoint(12, 44),
        GridPoint(36, 45),
        GridPoint(52, 42),
      ],
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

/// Rome's campfires, by tile, with the name shown in the save slots.
final Map<GridPoint, String> romeCampfireNames = <GridPoint, String>{
  piazzaCampfireTile: 'Piazza dei Cinquecento',
};

/// The one sprinter of Rome, loose on the piazza.
const GridPoint piazzaSprinterSpot = GridPoint(22, 12);

/// The wanderers on the platforms of Termini, `termini-wanderer-<n>`.
const String terminiZombiePrefix = 'termini-wanderer-';

/// The fires burning in Rome's streets.
final List<FireSpot> romeFireSpots = <FireSpot>[
  for (final street in <Place>[_piazza, _marsala]) ...firesIn(street),
];

/// The doors of Rome's station, both ways: the stairs up from the
/// platform to the overpass and the one flight on down to the far
/// platform (every flight is in the back wall of the overpass and the
/// front wall of a platform), the overpass's opening onto the concourse
/// and the concourse's three doorways onto the piazza (each lands Mario a
/// step past the door, facing on), and the breach out of the far platform
/// onto Via Marsala.
Map<GridPoint, Portal> _portals() => <GridPoint, Portal>{
  ...pairedDoors(terminiStairsTiles, _overpass.tilesOf('D'), Direction.south),
  ...pairedDoors(_overpass.tilesOf('D'), terminiStairsTiles, Direction.north),
  ...pairedDoors(
    terminiFarFlightTiles,
    _farPlatform.tilesOf('D'),
    Direction.north,
  ),
  ...pairedDoors(
    _farPlatform.tilesOf('D'),
    terminiFarFlightTiles,
    Direction.south,
  ),
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
  ...pairedDoors(terminiBreachTiles, _marsala.tilesOf('}'), Direction.north),
  ...pairedDoors(_marsala.tilesOf('}'), terminiBreachTiles, Direction.south),
};

/// What Rome holds when a game starts: the dead wandering Termini and
/// the streets round it, a backpack in the rubbish, and the station's
/// doors.
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
      id: 'piazza-sprinter',
      kind: EntityKind.sprinter,
      position: _onGrid(PlaceId.piazzaCinquecento, piazzaSprinterSpot),
    ),
  ],
  pickups: <Pickup>[
    Pickup(
      id: terminiRubbishBackpackId,
      position: _onGrid(PlaceId.terminiFarPlatform, terminiRubbishBackpackSpot),
      ammo: 2,
    ),
  ],
  portals: _portals(),
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
  const GridPoint(33, _cavourEnd),
);
final GridPoint toninoTile = _onGrid(
  PlaceId.piazzaCinquecento,
  const GridPoint(34, _cavourEnd),
);

/// The last stretch of Via Cavour, the two of them in full view at the
/// bottom of it: walking into it plays the meeting.
final GridRect maranzaSceneTrigger = _rectOnGrid(
  PlaceId.piazzaCinquecento,
  const GridRect(30, _cavourEnd - 5, 37, _cavourEnd - 1),
);

/// Two steps from them and on, the whole square included: once they have
/// had their say, stepping in here gets Mario sent back up the street.
final GridRect maranzaTurf = _rectOnGrid(
  PlaceId.piazzaCinquecento,
  GridRect(0, _cavourEnd - 2, _piazza.width - 1, _piazza.height - 1),
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
