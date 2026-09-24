import 'dart:math' as math;

import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/place.dart';
import 'package:stepbound/core/levels/tutorial/bar_arcobaleno.dart';
import 'package:stepbound/core/levels/tutorial/barracks.dart';
import 'package:stepbound/core/levels/tutorial/church.dart';
import 'package:stepbound/core/levels/tutorial/harbour.dart';
import 'package:stepbound/core/levels/tutorial/mall.dart';
import 'package:stepbound/core/levels/tutorial/mall_north_street.dart';
import 'package:stepbound/core/levels/tutorial/north_district.dart';
import 'package:stepbound/core/levels/tutorial/station.dart';
import 'package:stepbound/core/levels/tutorial/street.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world.dart';

export 'package:stepbound/core/levels/tutorial/bar_arcobaleno.dart';
export 'package:stepbound/core/levels/tutorial/barracks.dart';
export 'package:stepbound/core/levels/tutorial/church.dart';
export 'package:stepbound/core/levels/tutorial/harbour.dart';
export 'package:stepbound/core/levels/tutorial/mall.dart';
export 'package:stepbound/core/levels/tutorial/mall_north_street.dart';
export 'package:stepbound/core/levels/tutorial/north_district.dart';
export 'package:stepbound/core/levels/tutorial/station.dart';
export 'package:stepbound/core/levels/tutorial/street.dart';

/// The glyphs of the street, the north district and the harbour (see
/// street.dart), of the barracks (barracks.dart) and of the hypermarket
/// (mall.dart).
const Legend outdoorLegend = Legend(
  walls: 'BHfKMGW#%0',
  obstacles: 'CXUvkDFTSOyJQaAnI~RNbpx*i&!^;/',
  debris: ':q',
);
const Legend barracksLegend = Legend(walls: 'xWQNSIw', obstacles: 'TCAh');
const Legend mallLegend = Legend(walls: 'xWwISQ', obstacles: 'PTKBGHL');
const Legend barLegend = Legend(walls: 'xWw', obstacles: 'KTJ', debris: ':q');

/// San Nicola (church.dart): the altar `A` and the side walls `I` are as
/// solid as the outer ones, the pews `T` and the column drums `K` are
/// waist high.
const Legend churchLegend = Legend(walls: 'xWwIA', obstacles: 'TK');

/// The three places of the station (station.dart): the railcar `M` and
/// the rubble `#` shut the way like walls, the coach on its side `m`, the
/// benches `T`, the ticket windows `K` and the canopy posts `n` can be
/// seen over.
const Legend stationLegend = Legend(walls: 'xWwM#', obstacles: 'TKmn');

/// The card shown on the way into the harbour.
const String harbourName = 'Porto e centro storico';
const String harbourCardImage = 'assets/story/scene_harbour.jpg';

/// The tutorial: the street where Mario wakes up, the inside of the
/// carabinieri barracks, the north district behind it with the two floors
/// of its hypermarket and, past the car park, the block with the station
/// and its three places, and the harbour south of all that with the Duomo,
/// the Bar Arcobaleno and the church of San Nicola. Backgrounds are baked
/// by tools/build_street_level.py, build_barracks.py, build_mall.py,
/// build_bar.py, build_church.py and build_station.py.
final List<Place> tutorialPlaces = layOutPlaces(const <PlaceSpec>[
  PlaceSpec(
    id: PlaceId.street,
    rows: streetLevelRows,
    legend: outdoorLegend,
    background: 'assets/levels/first_street.png',
  ),
  PlaceSpec(
    id: PlaceId.barracks,
    rows: barracksRows,
    legend: barracksLegend,
    background: 'assets/levels/barracks.png',
    indoor: true,
    daylight: 'EO',
  ),
  PlaceSpec(
    id: PlaceId.northDistrict,
    rows: northDistrictRows,
    legend: outdoorLegend,
    background: 'assets/levels/north_district.png',
  ),
  PlaceSpec(
    id: PlaceId.harbour,
    rows: harbourRows,
    legend: outdoorLegend,
    background: 'assets/levels/harbour.png',
    name: harbourName,
    cardImage: harbourCardImage,
  ),
  PlaceSpec(
    id: PlaceId.mallGround,
    rows: mallGroundRows,
    legend: mallLegend,
    background: 'assets/levels/mall_ground.png',
    indoor: true,
    // The entrance, the stairs, and daylight through the fire exit.
    daylight: 'EUX',
  ),
  PlaceSpec(
    id: PlaceId.mallFirst,
    rows: mallFirstRows,
    legend: mallLegend,
    background: 'assets/levels/mall_first.png',
    indoor: true,
    // The stairs, and the panel's screen.
    daylight: 'DQL',
  ),
  PlaceSpec(
    id: PlaceId.mallNorthStreet,
    rows: mallNorthStreetRows,
    legend: outdoorLegend,
    background: 'assets/levels/mall_north_street.png',
  ),
  PlaceSpec(
    id: PlaceId.barArcobaleno,
    rows: barArcobalenoRows,
    legend: barLegend,
    background: 'assets/levels/bar_arcobaleno.png',
    indoor: true,
    daylight: 'E',
  ),
  PlaceSpec(
    id: PlaceId.church,
    rows: churchRows,
    legend: churchLegend,
    background: 'assets/levels/church.png',
    indoor: true,
    // The open portal, and the sky through the holes in the roof.
    daylight: 'E^',
  ),
  // Over the platforms the roof is gone, so the station and the far side
  // are lit throughout; only the underpass is dark.
  PlaceSpec(
    id: PlaceId.station,
    rows: stationRows,
    legend: stationLegend,
    background: 'assets/levels/station.png',
  ),
  PlaceSpec(
    id: PlaceId.stationUnderpass,
    rows: stationUnderpassRows,
    legend: stationLegend,
    background: 'assets/levels/station_underpass.png',
    indoor: true,
    // Daylight falling down both flights of stairs.
    daylight: 'DU',
  ),
  PlaceSpec(
    id: PlaceId.stationFarSide,
    rows: stationFarSideRows,
    legend: stationLegend,
    background: 'assets/levels/station_far_side.png',
  ),
]);

final Map<PlaceId, Place> _placesById = <PlaceId, Place>{
  for (final place in tutorialPlaces) place.id: place,
};

Place place(PlaceId id) => _placesById[id]!;

/// The place [tile] belongs to, if any.
Place? placeAt(GridPoint tile) {
  for (final place in tutorialPlaces) {
    if (place.bounds.contains(tile)) {
      return place;
    }
  }
  return null;
}

final Place _street = place(PlaceId.street);
final Place _barracks = place(PlaceId.barracks);
final Place _north = place(PlaceId.northDistrict);
final Place _harbour = place(PlaceId.harbour);
final Place _mallGround = place(PlaceId.mallGround);
final Place _mallFirst = place(PlaceId.mallFirst);
final Place _mallNorthStreet = place(PlaceId.mallNorthStreet);
final Place _bar = place(PlaceId.barArcobaleno);
final Place _church = place(PlaceId.church);
final Place _station = place(PlaceId.station);
final Place _underpass = place(PlaceId.stationUnderpass);
final Place _farSide = place(PlaceId.stationFarSide);

/// The four places [outdoorLegend] describes, the ones tools/
/// build_street_level.py bakes: what walks the streets, what burns in them
/// and what is dropped in them is read off these and no others. It is not
/// the same as `!place.indoor` -- the station's platforms are open to the
/// sky, and so lit like a street, but their glyphs are their own.
Iterable<Place> get _streets => <Place>[
  _street,
  _north,
  _harbour,
  _mallNorthStreet,
];

/// The zombie waiting on the east arm of the crossroads.
const String tutorialZombieId = 'wanderer-0';

/// Backpack ids, see the glyph lists in street.dart and barracks.dart.
const String ammoBackpackId = 'backpack-ammo';
const String parkingBackpackId = 'backpack-parking';
const String accidentBackpackId = 'backpack-accident';
const String gunBackpackId = 'backpack-gun';
const String boatBackpackId = 'backpack-boat';

/// The backpack `9` against the east wall of San Nicola: the incense Don
/// Angelo asked for.
const String incenseBackpackId = 'backpack-incense';

/// The backpack `9` in the ballast between the two wrecks, at the dead end
/// of the station's tracks: two rounds.
const String stationBackpackId = 'backpack-station';

/// How many rounds it holds.
const int stationBackpackAmmo = 2;

/// The wanderers standing in the places the outdoor glyphs do not reach:
/// the nave of San Nicola and the station's booking hall, both `Z`.
const String indoorZombiePrefix = 'indoor-wanderer-';

/// The two wanderers guarding the fire exit in the mall's upper ground-
/// floor area.
const String mallGroundZombiePrefix = 'mall-ground-wanderer-';

/// The two wanderers roaming the station's underground corridor.
const String stationUnderpassZombiePrefix = 'station-underpass-wanderer-';

/// Walking into the crossroads makes the tutorial zombie notice the player
/// even if it is not looking that way.
const GridRect tutorialZombieTrigger = GridRect(14, 33, 23, 39);

/// The forecourt in front of the barracks: reaching it makes Mario speak.
const GridRect barracksForecourt = GridRect(13, 7, 19, 8);

/// Camps where the player can save, and what a save there is called. The
/// glyph is `S` everywhere, so the place it burns in gives it its name;
/// each of them has one.
const Map<PlaceId, String> _campNames = <PlaceId, String>{
  PlaceId.northDistrict: 'Dietro la caserma',
  PlaceId.mallNorthStreet: 'Zona nord',
};

/// Campfires, by tile, with the name shown in the save slots.
final Map<GridPoint, String> campfireNames = <GridPoint, String>{
  for (final place in _streets)
    for (final (point, glyph) in place.glyphs)
      if (glyph == 'S' && _campNames.containsKey(place.id))
        point: _campNames[place.id]!,
};

/// The flagpole planted on the forecourt, where the tricolour flies.
final GridPoint flagpoleTile = _street.tileOf('I');

enum FireKind { car, bin, window, campfire }

/// Where an animated fire burns, in tile coordinates of its tile (the left
/// or top tile for a car).
final class FireSpot {
  const FireSpot(this.tile, this.kind, {this.vertical = false});

  final GridPoint tile;
  final FireKind kind;

  /// True for a car parked north-south.
  final bool vertical;
}

List<FireSpot> _firesIn(Place place) {
  final rows = place.rows;
  final spots = <FireSpot>[];
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final glyph = rows[y][x];
      final tile = GridPoint(place.origin.x + x, place.origin.y + y);
      final carStart = glyph == 'X' && (x == 0 || rows[y][x - 1] != 'X');
      final verticalCarStart =
          glyph == 'k' && (y == 0 || rows[y - 1][x] != 'k');
      final spot = switch (glyph) {
        'F' => FireSpot(tile, FireKind.bin),
        'f' => FireSpot(tile, FireKind.window),
        'S' => FireSpot(tile, FireKind.campfire),
        _ when carStart => FireSpot(tile, FireKind.car),
        _ when verticalCarStart => FireSpot(tile, FireKind.car, vertical: true),
        _ => null,
      };
      if (spot != null) {
        spots.add(spot);
      }
    }
  }
  return spots;
}

/// Fires burning on the first street.
final List<FireSpot> streetFireSpots = _firesIn(_street);

/// Fires of every outdoor place.
final List<FireSpot> outdoorFireSpots = <FireSpot>[
  for (final place in _streets) ..._firesIn(place),
];

/// Where the carabinieri zombies come out in the barracks.
final List<GridPoint> carabiniereSpawns = _barracks.tilesOf('c');

/// Where Don Angelo waits, on the sagrato just beyond the churchyard gate.
final GridPoint priestTile = _harbour.tileOf('s');

/// The two zombies pressed against the gate, west to east: the priest asks
/// Mario to get rid of them before he will talk.
final List<GridPoint> priestZombieTiles = _harbour.tilesOf('t');

/// Their ids, `priest-zombie-0` and `priest-zombie-1`.
const String priestZombiePrefix = 'priest-zombie-';

/// The alley between the seafront road and the churchyard gate: standing
/// here is standing in front of Don Angelo.
final GridRect priestGateFront = () {
  final alley = _harbour.tilesOf('x');
  return GridRect(
    alley.first.x,
    alley.first.y + 1,
    alley.last.x,
    alley.last.y + 2,
  );
}();

/// Coming this close to the alley is close enough for Don Angelo to hail
/// Mario: the alley itself and the whole width of the seafront road in
/// front of it, sidewalk to sidewalk, so he calls out whichever side of
/// the road Mario walks down.
final GridRect priestSceneTrigger = () {
  final rows = _harbour.rows;
  final x = priestGateFront.left - _harbour.origin.x;
  // From the sidewalk under the palazzi, across the lanes, down to the
  // sidewalk along the promenade.
  var y = priestGateFront.bottom - _harbour.origin.y + 1;
  do {
    y++;
  } while (rows[y][x] != '=');
  return GridRect(
    priestGateFront.left - 2,
    priestGateFront.top,
    priestGateFront.right + 2,
    _harbour.origin.y + y,
  );
}();

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

/// Where the fire exit lands, in the car park behind the hypermarket.
final GridPoint mallNorthStreetEntry = _mallNorthStreet.tileOf('j');

/// The portal of San Nicola, standing open on the church's little square.
final GridPoint churchPortalTile = _harbour.tileOf('(');

/// The station's two doorways on the forecourt, west and east: neither
/// leads where the other does.
final List<GridPoint> stationWestDoor = _mallNorthStreet.doorRow('(');
final List<GridPoint> stationEastDoor = _mallNorthStreet.doorRow(')');

/// The far platform, where Luigi is waiting in the cab of the one train
/// still in one piece: coming up the stairs onto it plays his scene. The
/// whole platform, so there is no walking past him.
final GridRect stationPlatform = () {
  final rows = _farSide.rows;
  final top = rows.indexWhere((row) => row.contains('='));
  final bottom = rows.lastIndexWhere((row) => row.contains('='));
  return GridRect(
    _farSide.origin.x + 1,
    _farSide.origin.y + top,
    _farSide.origin.x + _farSide.width - 2,
    _farSide.origin.y + bottom,
  );
}();

/// Doors [from] one place [to] another, tile by tile in order: stepping on
/// a tile of [from] lands on the tile of [to] one step towards [facing].
Map<GridPoint, Portal> _pairedDoors(
  List<GridPoint> from,
  List<GridPoint> to,
  Direction facing,
) {
  assert(from.length == to.length, 'doors of different widths');
  return <GridPoint, Portal>{
    for (var i = 0; i < from.length; i++)
      from[i]: Portal(to: to[i].step(facing), facing: facing),
  };
}

/// Every door, both ways:
/// - the barracks' front door on the street and its back door onto the
///   north district;
/// - the road leaving the bottom of the north district, which is the one
///   entering the top of the harbour;
/// - the hypermarket's entrance from the car park, and its stairs between
///   the two floors (both flights climb into the back wall: the lower step
///   of each flight is where Mario lands);
/// - the fire exit in the back wall of the ground floor's upper area, onto
///   the car park behind the hypermarket, cut off from the rest of the
///   north district;
/// - the door of the Bar Arcobaleno, up the harbour's alley;
/// - the open portal of San Nicola, deep in the old town;
/// - the station's two doorways, each into its own corner of the booking
///   hall, and the two flights of the underpass that join the far end of
///   that hall to the far platform (every flight climbs into the back wall
///   of the place it leaves, so Mario lands on the step below it -- south,
///   but for the flight up onto the far platform, whose wall runs along
///   the bottom of the map).
Map<GridPoint, Portal> _portals() {
  final northEdge = _north.walkableRow(_north.height - 1);
  final harbourEdge = _harbour.walkableRow(0);
  final mallDoor = _north.doorRow('m');
  final entrance = _mallGround.doorRow('E');
  final up = _mallGround.doorRow('U');
  final down = _mallFirst.doorRow('D');
  return <GridPoint, Portal>{
    ..._pairedDoors(
      <GridPoint>[_street.tileOf('E')],
      <GridPoint>[_barracks.tileOf('E')],
      Direction.north,
    ),
    ..._pairedDoors(
      <GridPoint>[_barracks.tileOf('E')],
      <GridPoint>[_street.tileOf('E')],
      Direction.south,
    ),
    ..._pairedDoors(
      <GridPoint>[_barracks.tileOf('O')],
      <GridPoint>[_north.tileOf('e')],
      Direction.north,
    ),
    ..._pairedDoors(
      <GridPoint>[_north.tileOf('e')],
      <GridPoint>[_barracks.tileOf('O')],
      Direction.south,
    ),
    ..._pairedDoors(northEdge, harbourEdge, Direction.south),
    ..._pairedDoors(harbourEdge, northEdge, Direction.north),
    ..._pairedDoors(mallDoor, entrance, Direction.north),
    ..._pairedDoors(entrance, mallDoor, Direction.south),
    ..._pairedDoors(up, down, Direction.south),
    ..._pairedDoors(down, up, Direction.south),
    ..._pairedDoors(
      <GridPoint>[mallExitTile],
      <GridPoint>[mallNorthStreetEntry],
      Direction.north,
    ),
    ..._pairedDoors(
      <GridPoint>[mallNorthStreetEntry],
      <GridPoint>[mallExitTile],
      Direction.south,
    ),
    ..._pairedDoors(
      <GridPoint>[_harbour.tileOf('h')],
      <GridPoint>[_bar.tileOf('E')],
      Direction.north,
    ),
    ..._pairedDoors(
      <GridPoint>[_bar.tileOf('E')],
      <GridPoint>[_harbour.tileOf('h')],
      Direction.south,
    ),
    ..._pairedDoors(
      <GridPoint>[churchPortalTile],
      <GridPoint>[_church.tileOf('E')],
      Direction.north,
    ),
    ..._pairedDoors(
      <GridPoint>[_church.tileOf('E')],
      <GridPoint>[churchPortalTile],
      Direction.south,
    ),
    ..._pairedDoors(stationWestDoor, _station.doorRow('E'), Direction.north),
    ..._pairedDoors(_station.doorRow('E'), stationWestDoor, Direction.south),
    ..._pairedDoors(stationEastDoor, _station.doorRow('O'), Direction.north),
    ..._pairedDoors(_station.doorRow('O'), stationEastDoor, Direction.south),
    ..._pairedDoors(
      _station.doorRow('U'),
      _underpass.doorRow('D'),
      Direction.south,
    ),
    ..._pairedDoors(
      _underpass.doorRow('D'),
      _station.doorRow('U'),
      Direction.south,
    ),
    ..._pairedDoors(
      _underpass.doorRow('U'),
      _farSide.doorRow('D'),
      Direction.north,
    ),
    ..._pairedDoors(
      _farSide.doorRow('D'),
      _underpass.doorRow('U'),
      Direction.south,
    ),
  };
}

/// The level as the player finds it at the start: the map of every place,
/// Mario on the street, the zombies, the backpacks, the doors, the camp and
/// the panel.
WorldState createTutorialWorld({int seed = 20260920}) {
  final factory = EntityFactory(BalanceConfig.standard());
  final entities = <Entity>[];
  final pickups = <Pickup>[];
  final width = tutorialPlaces
      .map((place) => place.bounds.right + 1)
      .reduce(math.max);
  final height = tutorialPlaces
      .map((place) => place.bounds.bottom + 1)
      .reduce(math.max);
  final kinds = List<TileKind>.filled(width * height, TileKind.wall);
  final zombieCounts = <EntityKind, int>{};

  for (final place in tutorialPlaces) {
    for (final (point, glyph) in place.glyphs) {
      kinds[point.y * width + point.x] = place.kindOf(glyph);
    }
  }
  for (final place in _streets) {
    for (final (point, glyph) in place.glyphs) {
      switch (glyph) {
        case '@':
          // The tutorial starts unarmed and without bullets.
          entities.add(
            factory.player(
              id: 'player',
              position: point,
              health: 1,
              loadedAmmo: 0,
              hasGun: false,
            ),
          );
        case 'w' || 'z' || 'u' || 'r' || 't':
          final kind = switch (glyph) {
            'z' => EntityKind.sprinter,
            'u' => EntityKind.brute,
            'r' => EntityKind.carabiniere,
            _ => EntityKind.wanderer,
          };
          final index = zombieCounts[kind] ?? 0;
          zombieCounts[kind] = index + 1;
          final priestIndex = priestZombieTiles.indexOf(point);
          entities.add(
            factory.zombie(
              // The barracks' carabinieri, spawned later, are
              // `carabiniere-<n>`: the ones on the street keep apart, and
              // so do the two the priest wants gone.
              id: switch (glyph) {
                't' => '$priestZombiePrefix$priestIndex',
                _ when kind == EntityKind.carabiniere =>
                  'street-carabiniere-$index',
                _ => '${kind.name}-$index',
              },
              kind: kind,
              position: point,
            ),
          );
        case '1':
          pickups.add(Pickup(id: ammoBackpackId, position: point, ammo: 2));
        case '2':
          pickups.add(Pickup(id: accidentBackpackId, position: point, ammo: 4));
        case '4':
          pickups.add(Pickup(id: parkingBackpackId, position: point, ammo: 2));
        case '5':
          pickups.add(Pickup(id: boatBackpackId, position: point, ammo: 4));
      }
    }
  }
  // The places whose own glyphs the outdoor legend does not reach: their
  // one backpack is placed by hand, and `Z` is a wanderer standing in the
  // dark of them.
  pickups.addAll(<Pickup>[
    Pickup(id: gunBackpackId, position: _barracks.tileOf('3'), gun: true),
    Pickup(id: incenseBackpackId, position: _church.tileOf('9'), incense: true),
    Pickup(
      id: stationBackpackId,
      position: _station.tileOf('9'),
      ammo: stationBackpackAmmo,
    ),
  ]);
  var indoorZombies = 0;
  for (final place in <Place>[_church, _station]) {
    for (final tile in place.tilesOf('Z')) {
      entities.add(
        factory.zombie(
          id: '$indoorZombiePrefix${indoorZombies++}',
          kind: EntityKind.wanderer,
          position: tile,
        ),
      );
    }
  }
  for (final (place, prefix) in <(Place, String)>[
    (_mallGround, mallGroundZombiePrefix),
    (_underpass, stationUnderpassZombiePrefix),
  ]) {
    for (final (index, tile) in place.tilesOf('Z').indexed) {
      entities.add(
        factory.zombie(
          id: '$prefix$index',
          kind: EntityKind.wanderer,
          position: tile,
        ),
      );
    }
  }

  return WorldState(
    map: TileMap(
      width: width,
      height: height,
      tiles: <Tile>[for (final kind in kinds) Tile(kind)],
    ),
    entities: entities,
    pickups: pickups,
    alertTriggers: const <String, GridRect>{
      tutorialZombieId: tutorialZombieTrigger,
    },
    portals: _portals(),
    campfires: campfireNames.keys,
    controls: <GridPoint, GridRect>{mallPanelTile: luigiBars},
    playerId: 'player',
    random: SeededRandom(seed),
  );
}

/// The world as a save stores it: everything that can change (Mario, the
/// zombies, dead or alive, wherever they stand, the backpacks and whether
/// they were collected, the panels), but of the map only the tiles that
/// differ from the level's (the lifted shutter): the level rebuilds the
/// rest. The dark gaps between places made a full map most of a save.
Map<String, Object?> saveTutorialWorld(WorldState world) {
  final level = createTutorialWorld().map;
  final map = world.map;
  return <String, Object?>{
    ...world.toJson(includeMap: false),
    'mapChanges': <Object?>[
      for (var y = 0; y < map.height; y++)
        for (var x = 0; x < map.width; x++)
          if (level.tileAt(GridPoint(x, y)).kind !=
              map.tileAt(GridPoint(x, y)).kind)
            <String, Object?>{
              'x': x,
              'y': y,
              'kind': map.tileAt(GridPoint(x, y)).kind.name,
            },
    ],
  };
}

/// A world resumed from a [saveTutorialWorld] save: the level's map with
/// the saved changes, and everything else as it was.
WorldState restoreTutorialWorld(Map<String, Object?> json) {
  final currentLevel = createTutorialWorld();
  final map = currentLevel.map;
  for (final change
      in (json['mapChanges']! as List<Object?>).cast<Map<String, Object?>>()) {
    map.setTile(
      GridPoint(change['x']! as int, change['y']! as int),
      Tile(TileKind.values.byName(change['kind']! as String)),
    );
  }
  // Saves keep the complete pickup and entity lists. When a newer level
  // adds a backpack or a zombie, an older save therefore knows nothing
  // about it even though the current map around it has already been
  // rebuilt above. Merge only missing defaults: saved state (including
  // collected backpacks and dead zombies) wins, while newly shipped
  // inhabitants and items appear where the level puts them.
  final savedPickups = (json['pickups'] as List<Object?>? ?? const <Object?>[])
      .cast<Map<String, Object?>>();
  final savedPickupIds = <String>{
    for (final pickup in savedPickups) pickup['id']! as String,
  };
  final savedEntities =
      (json['entities'] as List<Object?>? ?? const <Object?>[])
          .cast<Map<String, Object?>>();
  final savedEntityIds = <String>{
    for (final entity in savedEntities) entity['id']! as String,
  };
  final migrated = <String, Object?>{
    ...json,
    'entities': <Object?>[
      ...savedEntities,
      for (final entity in currentLevel.entities.values)
        if (!savedEntityIds.contains(entity.id)) entity.toJson(),
    ],
    'pickups': <Object?>[
      ...savedPickups,
      for (final pickup in currentLevel.pickups.values)
        if (!savedPickupIds.contains(pickup.id)) pickup.toJson(),
    ],
  };
  return WorldState.fromJson(migrated, map: map);
}

/// A wanderer coming in through the hypermarket's gate at [position],
/// looking west down the corridor.
Entity createMallZombie(String id, GridPoint position) {
  return EntityFactory(
    BalanceConfig.standard(),
  ).zombie(id: id, kind: EntityKind.wanderer, position: position);
}

/// A carabiniere zombie coming out of the dark at [position].
Entity createCarabiniere(String id, GridPoint position) {
  return EntityFactory(BalanceConfig.standard()).zombie(
    id: id,
    kind: EntityKind.carabiniere,
    position: position,
    facing: Direction.south,
  );
}
