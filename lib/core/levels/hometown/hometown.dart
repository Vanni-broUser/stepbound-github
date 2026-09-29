import 'dart:math' as math;

import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

export 'package:stepbound/core/levels/hometown/airliner.dart';
export 'package:stepbound/core/levels/hometown/bar_arcobaleno.dart';
export 'package:stepbound/core/levels/hometown/bar_backroom.dart';
export 'package:stepbound/core/levels/hometown/barracks.dart';
export 'package:stepbound/core/levels/hometown/church.dart';
export 'package:stepbound/core/levels/hometown/duomo.dart';
export 'package:stepbound/core/levels/hometown/duomo_second_floor.dart';
export 'package:stepbound/core/levels/hometown/duomo_tower.dart';
export 'package:stepbound/core/levels/hometown/duomo_tower_roof.dart';
export 'package:stepbound/core/levels/hometown/duomo_upper.dart';
export 'package:stepbound/core/levels/hometown/harbour.dart';
export 'package:stepbound/core/levels/hometown/hospital.dart';
export 'package:stepbound/core/levels/hometown/mall.dart';
export 'package:stepbound/core/levels/hometown/mall_north_street.dart';
export 'package:stepbound/core/levels/hometown/north_district.dart';
export 'package:stepbound/core/levels/hometown/station.dart';
export 'package:stepbound/core/levels/hometown/street.dart';

/// The glyphs of the street, the north district and the harbour (see
/// street.dart), of the barracks (barracks.dart) and of the hypermarket
/// (mall.dart).
const Legend outdoorLegend = Legend(
  walls: 'BHfKMGW#%0_',
  obstacles: 'CXUvkDFTSOyJQaAnI~RNbpx*i&!^;/+',
  debris: ':q',
  fire: '?',
);
const Legend barracksLegend = Legend(walls: 'xWQNSIw', obstacles: 'TCAh');
const Legend mallLegend = Legend(walls: 'xWwISQ', obstacles: 'PTKBGHL');

/// The Bar Arcobaleno: the counter `K`, the tables `T`, the jukebox `J`
/// and the two pool tables `P` are all waist high, so they stop a step
/// but not a shot.
const Legend barLegend = Legend(walls: 'xWwD', obstacles: 'KTJP', debris: ':q');

/// San Nicola (church.dart): the altar `A` and the side walls `I` are as
/// solid as the outer ones, the pews `T` and the column drums `K` are
/// waist high.
const Legend churchLegend = Legend(walls: 'xWwIA', obstacles: 'TK');

/// The Duomo and the Bar Arcobaleno's storeroom share the indoor masonry
/// vocabulary, with their own furnishings as waist-high obstacles.
const Legend duomoLegend = Legend(walls: 'xWwIA', obstacles: 'PTMKFVYG12p');
const Legend barBackroomLegend = Legend(walls: 'xWwI', obstacles: 'KBGRC');
const Legend duomoUpperLegend = Legend(walls: 'xWwIL', obstacles: 'TCBKkFHnA');

/// Don Angelo's floor (duomo_second_floor.dart): the crucifix `X` hangs on
/// the wall and the windows `o` are in it; the bookcase, the kneeler, the
/// wardrobe, the bed, the desk, its chair and the statues are furniture.
const Legend duomoSecondFloorLegend = Legend(
  walls: 'xWwIXo',
  obstacles: 'QNKBTCS',
);

/// The bell tower (duomo_tower.dart): the arrow slits `o` are in the wall,
/// the railings `|`, the crates `K` and the bell `O` stand in the room.
const Legend duomoTowerLegend = Legend(walls: 'xWwIo', obstacles: '|KO');

/// The top of the tower (duomo_tower_roof.dart): the drop `x` and the nave
/// roof far below `=` are walls, while the parapet `^`, the stretch of it
/// Mario looks over `>` and the lightning rod `n` can be seen over.
const Legend duomoTowerRoofLegend = Legend(walls: 'x=', obstacles: '^>n');

/// The three places of the station (station.dart): the side walls `|`, the
/// hijacked train's cars `m` and `C` and its overturned ones `V` and `H`,
/// the railcar `M` and the rubble `#` shut the way like walls, the benches
/// `T`, the ticket windows `K` and the canopy posts `n` can be seen over,
/// the far-platform signs `l` and `r` hang against the wall, and the gap by
/// the burning car `?` is on fire.
const Legend stationLegend = Legend(
  walls: 'xWwMmCVHP#|lr',
  obstacles: 'TKn',
  fire: '?',
);

/// Inside the crashed airliner (airliner.dart) the hull is a wall all
/// round; the blocks of seats `T` and the galley trolleys `K` are waist
/// high, and the buckled panelling `:` and the broken seats `r` are walked
/// over, noisily.
const Legend airlinerLegend = Legend(
  walls: 'xWwI',
  obstacles: 'TK',
  debris: ':r',
);

/// The roofs the tail came down in: the drop `x`, the party walls `W` and
/// the tail `#` are all walls, while the parapets `^`, the low stretch `>`
/// Mario measures the gap from, the chimney stacks `T` and `k` and the
/// aerial masts `n` can be seen over, and the corner on fire `&` burns
/// from the start. The roof across the gap `%` is walked on like any
/// other, by whoever gets there.
const Legend rooftopLegend = Legend(
  walls: 'xW#',
  obstacles: 'Tnk^><',
  fire: '&',
);

/// The hospital's three floors (hospital.dart): the walls and partitions
/// are solid, and everything a ward or a waiting room is furnished with
/// stops a step but not a shot.
const Legend hospitalLegend = Legend(
  walls: 'xWwIN',
  obstacles: 'CTAhLVpsrHBnfMS',
);

/// The hospital's roof: its walls and the drop are walls, the parapet, the
/// wall knocked down low `>`, the stacks, the aerials and the camp's fire
/// can be seen over, and the gravel is noisy.
const Legend hospitalRoofLegend = Legend(walls: 'xW', obstacles: '^><TnS');

/// The name on the card shown on the way into the harbour.
const String harbourName = 'Porto e centro storico';

/// The picture the city stands for: the level's loading cover, its card on
/// the Europe map, and the card on the way into the harbour, which is what
/// it shows. Kept with the other levels' covers, in assets/story/maps.
const String hometownCoverImage = 'assets/story/maps/molfetta.jpg';

/// Molfetta, the first level: the street where Mario wakes up, the inside
/// of the carabinieri barracks, the north district behind it with the two
/// floors of its hypermarket and, past the car park, the block with the
/// station and its three places, and the harbour south of all that with the
/// Duomo, the Bar Arcobaleno and the church of San Nicola. Backgrounds are
/// baked by the bakers listed in tools/build_levels.py, except for the
/// places with no `background`: those the game paints from these same
/// rows, out of assets/levels/tiles (tools/build_tile_atlas.py).
const List<PlaceSpec> hometownPlaces = <PlaceSpec>[
  PlaceSpec(
    id: PlaceId.street,
    area: AreaId.hometownTown,
    rows: streetLevelRows,
    legend: outdoorLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.barracks,
    area: AreaId.hometownTown,
    rows: barracksRows,
    legend: barracksLegend,
    indoor: true,
    daylight: 'EO',
  ),
  PlaceSpec(
    id: PlaceId.northDistrict,
    area: AreaId.hometownTown,
    rows: northDistrictRows,
    legend: outdoorLegend,
  ),
  PlaceSpec(
    id: PlaceId.harbour,
    area: AreaId.hometownHarbour,
    rows: harbourRows,
    legend: outdoorLegend,
    name: harbourName,
    cardImage: hometownCoverImage,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.mallGround,
    area: AreaId.hometownTown,
    rows: mallGroundRows,
    legend: mallLegend,
    indoor: true,
    // The entrance, the stairs, and daylight through the fire exit.
    daylight: 'EUX',
    lamps: mallGroundSignLights,
    flickeringLamps: mallGroundFlickeringSignLights,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.mallFirst,
    area: AreaId.hometownTown,
    rows: mallFirstRows,
    legend: mallLegend,
    indoor: true,
    // The stairs, and the panel's screen.
    daylight: 'DQL',
  ),
  PlaceSpec(
    id: PlaceId.mallNorthStreet,
    area: AreaId.hometownTown,
    rows: mallNorthStreetRows,
    legend: outdoorLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.barArcobaleno,
    area: AreaId.hometownHarbour,
    rows: barArcobalenoRows,
    legend: barLegend,
    indoor: true,
    daylight: 'E',
    lamps: barArcobalenoLamps,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.church,
    area: AreaId.hometownHarbour,
    rows: churchRows,
    legend: churchLegend,
    indoor: true,
    // The open portal, and the sky through the holes in the roof.
    daylight: 'E^9',
  ),
  // Over the platforms the roof is gone, so the station and the far side
  // are lit throughout; only the underpass is dark.
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.station,
    area: AreaId.hometownTown,
    rows: stationRows,
    legend: stationLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.stationUnderpass,
    area: AreaId.hometownTown,
    rows: stationUnderpassRows,
    legend: stationLegend,
    indoor: true,
    // Daylight falling down both flights of stairs.
    daylight: 'DU',
  ),
  // Painted from its rows out of the tile atlas, backdrop and all: the
  // railcar is an object in it, and the story opens its door rather than
  // swapping a second picture of the whole place.
  PlaceSpec(
    id: PlaceId.stationFarSide,
    area: AreaId.hometownTown,
    rows: stationFarSideRows,
    legend: stationLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.airlinerCabin,
    area: AreaId.hometownTown,
    rows: airlinerCabinRows,
    legend: airlinerLegend,
    indoor: true,
    // Daylight at the tear in the belly and at the tail break.
    daylight: 'EO',
    lamps: airlinerCabinLamps,
  ),
  // The roofs are open to the sky, so they are lit throughout. Painted
  // from their rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.airlinerRoofs,
    area: AreaId.hometownTown,
    rows: airlinerRoofRows,
    legend: rooftopLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomo,
    area: AreaId.hometownHarbour,
    rows: duomoRows,
    legend: duomoLegend,
    indoor: true,
    daylight: 'E',
    torches: duomoTorches,
    // Torchlight everywhere: the nave never sinks into the dark.
    darkness: 0.55,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.barBackroom,
    area: AreaId.hometownHarbour,
    rows: barBackroomRows,
    legend: barBackroomLegend,
    indoor: true,
    daylight: 'E',
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomoUpper,
    area: AreaId.hometownHarbour,
    rows: duomoUpperRows,
    legend: duomoUpperLegend,
    indoor: true,
    // The community lives up here: every lamp is lit, no darkness at all.
    lit: true,
    daylight: 'D',
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomoSecondFloor,
    area: AreaId.hometownHarbour,
    rows: duomoSecondFloorRows,
    legend: duomoSecondFloorLegend,
    indoor: true,
    daylight: 'o',
    darkness: 0.7,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomoTower,
    area: AreaId.hometownHarbour,
    rows: duomoTowerRows,
    legend: duomoTowerLegend,
    indoor: true,
    daylight: 'o',
    darkness: 0.75,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomoBells,
    area: AreaId.hometownHarbour,
    rows: duomoBellsRows,
    legend: duomoTowerLegend,
    indoor: true,
    // The bell chamber is open to the wind on the east side.
    daylight: 'o',
    darkness: 0.6,
  ),
  // Open to the sky. Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.duomoTowerRoof,
    area: AreaId.hometownHarbour,
    rows: duomoTowerRoofRows,
    legend: duomoTowerRoofLegend,
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.hospitalFirstFloor,
    area: AreaId.hometownTown,
    rows: hospitalFirstFloorRows,
    legend: hospitalLegend,
    indoor: true,
    // The emergency lights still on here and there: dim, not black.
    darkness: 0.8,
    name: 'Ospedale',
    // Daylight through the glass doors.
    daylight: 'E',
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.hospitalSecondFloor,
    area: AreaId.hometownTown,
    rows: hospitalSecondFloorRows,
    legend: hospitalLegend,
    indoor: true,
    // The emergency lights still on here and there: dim, not black.
    darkness: 0.8,
    name: 'Ospedale',
  ),
  // Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.hospitalThirdFloor,
    area: AreaId.hometownTown,
    rows: hospitalThirdFloorRows,
    legend: hospitalLegend,
    indoor: true,
    // The emergency lights still on here and there: dim, not black.
    darkness: 0.8,
    name: 'Ospedale',
  ),
  // Open to the sky. Painted from its rows out of the tile atlas.
  PlaceSpec(
    id: PlaceId.hospitalRoof,
    area: AreaId.hometownTown,
    rows: hospitalRoofRows,
    legend: hospitalRoofLegend,
    name: 'Tetto dell’ospedale',
  ),
];

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
final Place _airlinerCabin = place(PlaceId.airlinerCabin);
final Place _airlinerRoofs = place(PlaceId.airlinerRoofs);
final Place _duomo = place(PlaceId.duomo);
final Place _barBackroom = place(PlaceId.barBackroom);
final Place _duomoUpper = place(PlaceId.duomoUpper);
final Place _duomoSecond = place(PlaceId.duomoSecondFloor);
final Place _duomoTower = place(PlaceId.duomoTower);
final Place _duomoBells = place(PlaceId.duomoBells);
final Place _duomoRoof = place(PlaceId.duomoTowerRoof);
final Place _hospitalFirst = place(PlaceId.hospitalFirstFloor);
final Place _hospitalSecond = place(PlaceId.hospitalSecondFloor);
final Place _hospitalThird = place(PlaceId.hospitalThirdFloor);
final Place _hospitalRoof = place(PlaceId.hospitalRoof);

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

/// The wanderer on the road north, `9`, a few steps past where the
/// dead-end street opens: it is in the way to the barracks, and the street
/// is where there is room to draw it and go round it. Its own id, so that
/// it does not take the tutorial zombie's for being further up the map.
const String barracksRoadZombieId = 'barracks-road-wanderer';

/// The other `9`, four rows up the road north from [barracksRoadZombieId]
/// and to the east of it, closer to the barracks and looking south: going
/// round the first, Mario walks into it.
const String barracksRoadUpperZombieId = 'barracks-road-upper-wanderer';

/// Backpack ids, see the glyph lists in street.dart and barracks.dart.
const String ammoBackpackId = 'backpack-ammo';
const String parkingBackpackId = 'backpack-parking';
const String accidentBackpackId = 'backpack-accident';
const String alleyBackpackId = 'backpack-alley';
const String gunBackpackId = 'backpack-gun';
const String boatBackpackId = 'backpack-boat';
const String shipyardBackpackId = 'backpack-shipyard';
const String oldTownBackpackId = 'backpack-old-town';
const String mallNorthBackpackId = 'backpack-mall-north';

/// The two new harbour backpacks, named separately so saves keep tracking
/// each one even though both hold the same two rounds.
final GridPoint shipyardBackpackTile = _harbour.tileOf('6');
final GridPoint oldTownBackpackTile = _harbour.tileOf('7');

/// The backpack at the old campfire site on the shopping street north of
/// the mall, and the two rounds inside it.
const int mallNorthBackpackAmmo = 2;
final GridPoint mallNorthBackpackTile = _mallNorthStreet.tileOf('8');

/// The backpack `9` against the east wall of San Nicola: the incense Don
/// Angelo asked for.
const String incenseBackpackId = 'backpack-incense';
const String episcopalRingPickupId = 'episcopal-ring';

/// The backpack with a molotov in the park behind the hypermarket, and
/// how many it holds.
const String molotovBackpackId = 'molotov-backpack';
const int molotovBackpackCount = 2;
const String cultistRobePickupId = 'cultist-robe';

/// The service door in the top-right corner of the Bar Arcobaleno. It is
/// scenery until Don Angelo gives Mario its key; it then becomes the portal
/// to the storeroom.
final GridPoint barLockedDoorTile = _bar.tileOf('D');
final GridPoint barBackroomDoorTile = _barBackroom.tileOf('E');

/// People and the guarded door upstairs inside the Duomo: the door
/// [duomoStairEntryTile] is in the back wall, straight behind the cultist
/// who stands in front of it.
final GridPoint duomoPriestTile = _duomo.tileOf('p');
final GridPoint duomoStairCultistTile = _duomo.tileOf('1');
final GridPoint duomoWelcomingCultistTile = _duomo.tileOf('2');
final GridPoint duomoStairCultistMovedTile = _duomo.tileOf('3');
final GridPoint duomoStairEntryTile = _duomo.tileOf('U');
final GridPoint duomoUpperStairTile = _duomoUpper.tileOf('D');
final GridPoint duomoUpperLockedDoorTile = _duomoUpper.tileOf('L');
final GridPoint duomoUpperRobeTile = _duomoUpper.tileOf('R');

/// The way up from the door the key opens to the top of the bell tower:
/// on each floor the stairs `D` Mario comes up by and the doorway `U` he
/// goes on up through, and on the roof the hatch he comes out of.
final GridPoint duomoSecondFloorStairTile = _duomoSecond.tileOf('D');
final GridPoint duomoSecondFloorUpTile = _duomoSecond.tileOf('U');
final GridPoint duomoTowerStairTile = _duomoTower.tileOf('D');
final GridPoint duomoTowerUpTile = _duomoTower.tileOf('U');
final GridPoint duomoBellsStairTile = _duomoBells.tileOf('D');
final GridPoint duomoBellsUpTile = _duomoBells.tileOf('U');
final GridPoint duomoRoofHatchTile = _duomoRoof.tileOf('D');

/// The stretch of the tower's parapet that faces the other tower: looking
/// over it tells Mario what it would take to get across.
final GridPoint duomoTowerLookoutTile = _duomoRoof.tileOf('>');

/// The stretch of the other tower's parapet straight across from
/// [duomoTowerLookoutTile], seven cells east over the nave: where the
/// grappling hook brings Mario back from. The picture of the towers is
/// one painting, so it is found from the lookout, not by a glyph.
final GridPoint duomoFarTowerEdgeTile = GridPoint(
  duomoTowerLookoutTile.x + 7,
  duomoTowerLookoutTile.y,
);

/// The backpack on the roof of the other tower, in sight from this one and
/// out of reach without the grappling hook: a round for a rocket launcher.
final GridPoint duomoFarTowerBackpackTile = _duomoRoof.tileOf('9');
const String duomoFarTowerBackpackId = 'backpack-duomo-tower';

/// Where the cultist up on the other tower comes out, in its far corner,
/// the first time the hook lands Mario there: nothing of it shows from
/// this tower.
final GridPoint duomoFarTowerCultistTile = GridPoint(
  duomoFarTowerEdgeTile.x + 6,
  duomoFarTowerEdgeTile.y - 2,
);
const String duomoFarTowerCultistId = 'duomo-tower-cultist';

/// The cultist on the other tower, turned towards where Mario lands.
Entity createDuomoTowerCultist() =>
    EntityFactory(BalanceConfig.standard()).zombie(
      id: duomoFarTowerCultistId,
      kind: EntityKind.cultist,
      position: duomoFarTowerCultistTile,
    );

/// What the mass leaves behind in the nave, once the community has eaten
/// of the crucified zombie and turned on Don Angelo: the four mutated
/// cultists `c` across the aisle between the first two blocks of pews,
/// his body `d` behind them and, beside it, the backpack `9` with the key
/// of the upper floor. None of it is there before the mass: the zombies
/// are raised by the Duomo's script, the body is put where it lies and the
/// backpack starts inactive.
final List<GridPoint> duomoCultistSpawns = _duomo.tilesOf('c');

/// The crucified zombie over the altar, on the shared grid: it hangs from
/// the moment the mass is over, and is scenery, so it has no glyph and no
/// entity of its own (see [duomoCrucifixSpot]).
final GridPoint duomoCrucifixTile = GridPoint(
  _duomo.origin.x + duomoCrucifixSpot.x,
  _duomo.origin.y + duomoCrucifixSpot.y,
);
final GridPoint duomoPriestCorpseTile = _duomo.tileOf('d');
final GridPoint duomoKeyTile = _duomo.tileOf('9');

/// Their ids, `duomo-cultist-0` to `duomo-cultist-3`.
const String duomoCultistPrefix = 'duomo-cultist-';
const String duomoKeyPickupId = 'duomo-key';

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

/// The hospital's glass doors at the top of its stairs, in the north
/// district, and the same doors seen from inside the waiting room.
final List<GridPoint> hospitalDoors = _north.doorRow(r'$');
final List<GridPoint> hospitalEntrance = _hospitalFirst.doorRow('E');

/// The hospital's stairs, bottom to top: on each floor the flight `U` up
/// out of its back wall and, on the floor above, the stairs `D` in the
/// front wall it comes out on; from the third floor, the hatch `D` in the
/// roof.
final List<(GridPoint, GridPoint)> hospitalFlights = <(GridPoint, GridPoint)>[
  (_hospitalFirst.tileOf('U'), _hospitalSecond.tileOf('D')),
  (_hospitalSecond.tileOf('U'), _hospitalThird.tileOf('D')),
  (_hospitalThird.tileOf('U'), _hospitalRoof.tileOf('D')),
];

/// The camp on the hospital's roof, out of the horde's reach.
final GridPoint hospitalRoofCampfireTile = _hospitalRoof.tileOf('S');

/// The stretch of the roof's east wall knocked down low, facing the next
/// block across the gap: looking over it, Mario measures the gap.
final GridPoint hospitalRoofLookoutTile = _hospitalRoof.tileOf('>');

/// The next block's wall broken open straight across from
/// [hospitalRoofLookoutTile]: the way back with the grappling hook.
final GridPoint hospitalNextRoofEdgeTile = _hospitalRoof.tileOf('<');

/// The wanderers left in the hospital, floor by floor, `hospital-wanderer-<n>`.
const String hospitalZombiePrefix = 'hospital-wanderer-';

/// The two wanderers roaming the station's underground corridor.
const String stationUnderpassZombiePrefix = 'station-underpass-wanderer-';

/// The two wanderers left in the cabin of the crashed airliner.
const String airlinerZombiePrefix = 'airliner-wanderer-';

/// The mutilated zombies `M` lying in the cabin of the crashed airliner.
const String airlinerMutilatedPrefix = 'airliner-mutilated-';

/// The flight bag `9` in the airliner's cabin: enough rounds for the
/// mutilated zombie lying in the way out, whatever Mario came in with.
const String airlinerBackpackId = 'backpack-airliner';

/// How many rounds it holds.
const int airlinerBackpackAmmo = 2;

/// The backpack in the south-east corner of the first roof after the
/// airliner, and the two rounds it holds.
const String rooftopBackpackId = 'backpack-airliner-roof';
const int rooftopBackpackAmmo = 2;
final GridPoint rooftopBackpackTile = _airlinerRoofs.tileOf('9');

/// The zombies on fire `Y` that walked out of the burning corner of the
/// roofs past the airliner, `rooftop-burning-<n>`.
const String rooftopBurningZombiePrefix = 'rooftop-burning-';

/// The first of them.
const String rooftopBurningZombieId = '${rooftopBurningZombiePrefix}0';

/// The drunk zombies `U` staggering about the Bar Arcobaleno.
const String barDrunkZombiePrefix = 'bar-drunk-';

/// The first of them, in reading order of the rows.
const String barDrunkZombieId = '${barDrunkZombiePrefix}0';

/// Walking into the crossroads makes the tutorial zombie notice the player
/// even if it is not looking that way: from the west zebra crossing to a
/// few steps down the east arm, between the two sidewalks.
final GridRect tutorialZombieTrigger = () {
  final crossing = _street.tilesOf('V').first;
  return GridRect(crossing.x - 1, crossing.y, crossing.x + 9, crossing.y + 6);
}();

/// The forecourt in front of the barracks, from the flagpole west along
/// the sidewalk and the row of road under it: reaching it makes Mario
/// speak.
final GridRect barracksForecourt = GridRect(
  flagpoleTile.x - 6,
  flagpoleTile.y,
  flagpoleTile.x,
  flagpoleTile.y + 1,
);

/// The two harbour fires, in row order: first on the gated Duomo sagrato,
/// then at the south-east end of the harbour road.
final GridPoint duomoCampfireTile = _harbour.tilesOf('S').first;
final GridPoint harbourRoadCampfireTile = _harbour.tilesOf('S').last;

/// The north-zone campfire, now beside the rubbish in the car park.
final GridPoint mallNorthCampfireTile = _mallNorthStreet.tileOf('S');

/// Camps in places that still have one each, and what a save there is
/// called. The harbour has two explicitly named fires below.
const Map<PlaceId, String> _campNames = <PlaceId, String>{
  PlaceId.northDistrict: 'Dietro la caserma',
  PlaceId.mallNorthStreet: 'Zona nord',
};

/// Molfetta's campfires, by tile, with the name shown in the save slots.
final Map<GridPoint, String> hometownCampfireNames = <GridPoint, String>{
  for (final place in _streets)
    for (final (point, glyph) in place.glyphs)
      if (glyph == 'S' && _campNames.containsKey(place.id))
        point: _campNames[place.id]!,
  duomoCampfireTile: 'Sagrato del Duomo',
  harbourRoadCampfireTile: 'Fine del porto',
  hospitalRoofCampfireTile: 'Tetto dell’ospedale',
};

/// The flagpole planted on the forecourt, where the tricolour flies.
final GridPoint flagpoleTile = _street.tileOf('I');

/// Fires burning on the first street.
final List<FireSpot> streetFireSpots = firesIn(_street);

/// The flames along the overturned car `H` burning at the west end of the
/// station's tracks, one every two cells from its west end.
final List<FireSpot> stationWreckFireSpots = () {
  final car = _station.tilesOf('H');
  final west = car.map((tile) => tile.x).reduce(math.min);
  final east = car.map((tile) => tile.x).reduce(math.max);
  final middle = car.map((tile) => tile.y).reduce(math.min) + 1;
  return <FireSpot>[
    for (var x = west; x < east; x += 2)
      FireSpot(GridPoint(x, middle), FireKind.car),
  ];
}();

/// Fires of every outdoor place, and those on the station's burning car.
final GridPoint northDistrictBackExitTile = _north.tileOf('e');
final GridPoint extinguishedNorthDistrictBinTile = _north
    .tilesOf('F')
    .reduce(
      (nearest, candidate) =>
          candidate.manhattanDistanceTo(northDistrictBackExitTile) <
              nearest.manhattanDistanceTo(northDistrictBackExitTile)
          ? candidate
          : nearest,
    );

final List<FireSpot> hometownFireSpots = <FireSpot>[
  for (final place in _streets)
    for (final spot in firesIn(place))
      if (spot.tile != extinguishedNorthDistrictBinTile) spot,
  ...stationWreckFireSpots,
  ...firesIn(_hospitalRoof),
];

/// Where the carabinieri zombies come out in the barracks.
final List<GridPoint> carabiniereSpawns = _barracks.tilesOf('c');

/// Where Don Angelo waits, on the sagrato just beyond the churchyard gate.
final GridPoint priestTile = _harbour.tileOf('s');

/// The three wrought-iron gate tiles across the alley. The extended priest
/// scene turns them into floor, leaving the open leaves drawn at the sides.
final List<GridPoint> priestGateTiles = _harbour.tilesOf('x');
final GridRect priestGate = GridRect(
  priestGateTiles.first.x,
  priestGateTiles.first.y,
  priestGateTiles.last.x,
  priestGateTiles.last.y,
);

/// The Duomo's open portal is directly north of Don Angelo's original spot.
/// The gate, not this doorway, keeps Mario out until the incense is delivered.
final GridPoint duomoPortalTile = GridPoint(priestTile.x, priestTile.y - 2);

/// The two zombies pressed against the gate, west to east: the priest asks
/// Mario to get rid of them before he will talk.
final List<GridPoint> priestZombieTiles = _harbour.tilesOf('t');

/// Their ids, `priest-zombie-0` and `priest-zombie-1`.
const String priestZombiePrefix = 'priest-zombie-';

/// The alley between the seafront road and the churchyard gate: standing
/// here is standing in front of Don Angelo.
final GridRect priestGateFront = () {
  final alley = priestGateTiles;
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

/// Where the fire exit lands: its own doorway, in the back wall of the
/// hypermarket behind the car park.
final GridPoint mallNorthStreetEntry = _mallNorthStreet.tileOf('j');

/// On the park's path, a few steps in front of the carabiniere standing
/// on it (zombies start looking west): to reach the molotov, Mario walks
/// up to him.
final GridPoint molotovBackpackTile = (() {
  final carabiniere = _mallNorthStreet.tileOf('r');
  return GridPoint(carabiniere.x - 4, carabiniere.y);
})();

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

/// The passenger door in the train on the far platform. Its tile starts as
/// a wall and is made walkable by the game as soon as Luigi is rescued.
final GridPoint stationTrainDoorTile = _farSide.tileOf('P');

/// The tear in the belly of the airliner, in the lane the wreck left open
/// at the crossroads behind the hypermarket: two tiles wide, like the
/// aisle it opens on.
final List<GridPoint> airlinerTear = _mallNorthStreet.doorRow('[');

/// The two breaks in the hull, seen from inside: the tear `E` back out
/// onto the road, and the tail break `O` out onto the roofs.
final List<GridPoint> airlinerCabinTear = _airlinerCabin.doorRow('E');
final List<GridPoint> airlinerTailBreak = _airlinerCabin.doorRow('O');

/// Where the tail break lands, in the roofline it came to rest in.
final List<GridPoint> airlinerRoofBreak = _airlinerRoofs.doorRow('D');

/// The low stretch of parapet at the south edge of the lower terrace,
/// where the next block stands just across the gap: without the grappling
/// hook, looking at it is all Mario can do about it.
final GridPoint rooftopGapTile = _airlinerRoofs.tileOf('>');

/// The next block's wall broken open straight across from
/// [rooftopGapTile]: the way back with the grappling hook.
final GridPoint rooftopFarEdgeTile = _airlinerRoofs.tileOf('<');

/// The open stairwell `S` going down eastward into the block across the
/// gap past the airliner, three steps deep: got onto from its head, the
/// west end, and down step by step to the last, the door to a place that
/// has no map yet.
final List<GridPoint> rooftopFarStairs = _airlinerRoofs.tilesOf('S');

/// The last steps of [rooftopFarStairs], at its east end.
final List<GridPoint> rooftopFarStairsFoot = _lastSteps(
  rooftopFarStairs,
  Direction.east,
);

/// The open stairwell `v` going down southward into the block east of the
/// hospital's roof, two steps deep: its last step is the door to a place
/// that has no map yet.
final List<GridPoint> hospitalNextRoofStairs = _hospitalRoof.tilesOf('v');

/// The last steps of [hospitalNextRoofStairs], at its south end.
final List<GridPoint> hospitalNextRoofStairsFoot = _lastSteps(
  hospitalNextRoofStairs,
  Direction.south,
);

/// The steps of [flight] furthest along [down].
List<GridPoint> _lastSteps(List<GridPoint> flight, Direction down) {
  int depth(GridPoint step) => step.x * down.dx + step.y * down.dy;
  final last = flight.map(depth).reduce((a, b) => a > b ? a : b);
  return <GridPoint>[
    for (final step in flight)
      if (depth(step) == last) step,
  ];
}

/// Molfetta's doors to places not drawn yet (see `workInProgressDoors`).
final Set<GridPoint> hometownWorkInProgressDoors = <GridPoint>{
  ...rooftopFarStairsFoot,
  ...hospitalNextRoofStairsFoot,
};

/// Molfetta's flights of stairs out in the open, each step with the way
/// up it (see `WorldState.stairs`): the hypermarket's, up from the ground
/// floor and down from the first, climbed into the back wall, and the two
/// stairwells on the roofs across the gaps.
final Map<GridPoint, Direction> hometownStairs = <GridPoint, Direction>{
  for (final step in _mallGround.tilesOf('U')) step: Direction.north,
  for (final step in _mallFirst.tilesOf('D')) step: Direction.north,
  for (final step in rooftopFarStairs) step: Direction.east,
  for (final step in hospitalNextRoofStairs) step: Direction.south,
};

/// Where the grappling hook crosses in Molfetta: the three gaps between
/// roofs, each both ways, from the edge Mario looks over to the one facing
/// it and back again. Each lands him just inside the other edge, looking
/// on the way he swung.
final Map<GridPoint, Portal> hometownGrapples = <GridPoint, Portal>{
  ..._bothWays(rooftopGapTile, rooftopFarEdgeTile, Direction.south),
  ..._bothWays(duomoTowerLookoutTile, duomoFarTowerEdgeTile, Direction.east),
  ..._bothWays(
    hospitalRoofLookoutTile,
    hospitalNextRoofEdgeTile,
    Direction.east,
  ),
};

/// The three terraces the hook crosses to in Molfetta -- past the
/// airliner, the Duomo's towers, the hospital's roof -- by the tiles it
/// lands Mario on, either way across.
final Map<GridPoint, String> hometownGrappleCrossings = <GridPoint, String>{
  for (final (name, near, far) in <(String, GridPoint, GridPoint)>[
    ('airliner', rooftopGapTile, rooftopFarEdgeTile),
    ('duomo', duomoTowerLookoutTile, duomoFarTowerEdgeTile),
    ('hospital', hospitalRoofLookoutTile, hospitalNextRoofEdgeTile),
  ])
    for (final edge in <GridPoint>[near, far]) hometownGrapples[edge]!.to: name,
};

Map<GridPoint, Portal> _bothWays(
  GridPoint near,
  GridPoint far,
  Direction across,
) => <GridPoint, Portal>{
  near: Portal(to: far.step(across), facing: across),
  far: Portal(to: near.step(across.opposite), facing: across.opposite),
};

/// The east end of the fuel burning across the middle lane of the
/// shopping street, west of the campfire behind the hypermarket: the gap in
/// the pile-up that looks like a way through. Looking at it says what it
/// would take.
final GridPoint shoppingStreetFireTile = _mallNorthStreet
    .tilesOf('?')
    .reduce((a, b) => a.x > b.x ? a : b);

/// The east end of the fire in the one gap between the station's burning
/// car and the car still upright, on the platform side: the only way onto
/// the tracks, and looking at it says what it would take.
final GridPoint stationTrackFireTile = _station
    .tilesOf('?')
    .reduce((a, b) => a.y > b.y || (a.y == b.y && a.x > b.x) ? a : b);

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
/// - its locked service door into the storeroom;
/// - the open portal of San Nicola, deep in the old town;
/// - the Duomo's open portal behind its story-gated churchyard;
/// - inside it, the guarded door up to the first floor, the locked door on
///   up to the second, and on up the bell tower's two flights to the hatch
///   out onto its roof (every door and flight is in the back wall of the
///   floor it leaves and lands Mario on the step above the stairs in the
///   front wall of the next; the hatch is in the roof's floor);
/// - the station's two doorways, each into its own corner of the booking
///   hall, and the two flights of the underpass that join the far end of
///   that hall to the far platform (every flight climbs into the back wall
///   of the place it leaves, so Mario lands on the step below it -- south,
///   but for the flight up onto the far platform, whose wall runs along
///   the bottom of the map);
/// - the tear in the belly of the crashed airliner, off the lane it left
///   open at the crossroads behind the hypermarket, and the break in its
///   tail at the far end of the cabin, out onto the roofs it stopped in
///   (both breaks are in a roof, so either way Mario lands below the one
///   he steps through);
/// - the hospital's glass doors at the top of its stairs, and inside it
///   the flights up from each floor to the next (in the back wall of the
///   floor below, onto the stairs in the front wall of the one above).
Map<GridPoint, Portal> _portals() {
  final northEdge = _north.walkableRow(_north.height - 1);
  final harbourEdge = _harbour.walkableRow(0);
  final mallDoor = _north.doorRow('m');
  final entrance = _mallGround.doorRow('E');
  final up = _mallGround.doorRow('U');
  final down = _mallFirst.doorRow('D');
  return <GridPoint, Portal>{
    ...pairedDoors(
      <GridPoint>[_street.tileOf('E')],
      <GridPoint>[_barracks.tileOf('E')],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[_barracks.tileOf('E')],
      <GridPoint>[_street.tileOf('E')],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[_barracks.tileOf('O')],
      <GridPoint>[_north.tileOf('e')],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[_north.tileOf('e')],
      <GridPoint>[_barracks.tileOf('O')],
      Direction.south,
    ),
    ...pairedDoors(northEdge, harbourEdge, Direction.south),
    ...pairedDoors(harbourEdge, northEdge, Direction.north),
    ...pairedDoors(mallDoor, entrance, Direction.north),
    ...pairedDoors(entrance, mallDoor, Direction.south),
    ...pairedDoors(up, down, Direction.south),
    ...pairedDoors(down, up, Direction.south),
    // Out of the fire exit Mario stands in its doorway, not out on the
    // tarmac of the car park: pushing on south from there goes back in.
    mallExitTile: Portal(to: mallNorthStreetEntry, facing: Direction.north),
    ...pairedDoors(
      <GridPoint>[mallNorthStreetEntry],
      <GridPoint>[mallExitTile],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[_harbour.tileOf('h')],
      <GridPoint>[_bar.tileOf('E')],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[_bar.tileOf('E')],
      <GridPoint>[_harbour.tileOf('h')],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[barLockedDoorTile],
      <GridPoint>[barBackroomDoorTile],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[barBackroomDoorTile],
      <GridPoint>[barLockedDoorTile],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[churchPortalTile],
      <GridPoint>[_church.tileOf('E')],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[_church.tileOf('E')],
      <GridPoint>[churchPortalTile],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[duomoPortalTile],
      <GridPoint>[_duomo.tileOf('E')],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[_duomo.tileOf('E')],
      <GridPoint>[duomoPortalTile],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[duomoStairEntryTile],
      <GridPoint>[duomoUpperStairTile],
      Direction.north,
    ),
    ...pairedDoors(
      <GridPoint>[duomoUpperStairTile],
      <GridPoint>[duomoStairEntryTile],
      Direction.south,
    ),
    for (final (below, above) in <(GridPoint, GridPoint)>[
      (duomoUpperLockedDoorTile, duomoSecondFloorStairTile),
      (duomoSecondFloorUpTile, duomoTowerStairTile),
      (duomoTowerUpTile, duomoBellsStairTile),
      (duomoBellsUpTile, duomoRoofHatchTile),
    ]) ...<GridPoint, Portal>{
      ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
      ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
    },
    ...pairedDoors(stationWestDoor, _station.doorRow('E'), Direction.north),
    ...pairedDoors(_station.doorRow('E'), stationWestDoor, Direction.south),
    ...pairedDoors(stationEastDoor, _station.doorRow('O'), Direction.north),
    ...pairedDoors(_station.doorRow('O'), stationEastDoor, Direction.south),
    ...pairedDoors(
      _station.doorRow('U'),
      _underpass.doorRow('D'),
      Direction.south,
    ),
    ...pairedDoors(
      _underpass.doorRow('D'),
      _station.doorRow('U'),
      Direction.north,
    ),
    ...pairedDoors(
      _underpass.doorRow('U'),
      _farSide.doorRow('D'),
      Direction.north,
    ),
    ...pairedDoors(
      _farSide.doorRow('D'),
      _underpass.doorRow('U'),
      Direction.south,
    ),
    ...pairedDoors(airlinerTear, airlinerCabinTear, Direction.north),
    ...pairedDoors(airlinerCabinTear, airlinerTear, Direction.south),
    // The tail break is in the belly: Mario climbs down out of it south onto
    // the roofs, and back up into the cabin north.
    ...pairedDoors(airlinerTailBreak, airlinerRoofBreak, Direction.south),
    ...pairedDoors(airlinerRoofBreak, airlinerTailBreak, Direction.north),
    ...pairedDoors(hospitalDoors, hospitalEntrance, Direction.north),
    ...pairedDoors(hospitalEntrance, hospitalDoors, Direction.south),
    for (final (below, above) in hospitalFlights) ...<GridPoint, Portal>{
      ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
      ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
    },
  };
}

/// What Molfetta holds when a game starts: Mario on the street, its
/// zombies and backpacks, its doors, the tutorial zombie's trigger, the
/// hypermarket's panel and what can be looked at.
LevelContents hometownContents(EntityFactory factory) {
  final entities = <Entity>[];
  final pickups = <Pickup>[];
  final zombieCounts = <EntityKind, int>{};
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
        case '9':
          // The upper of the two is the one further up the road.
          final upper = point.y < _street.tilesOf('9').last.y;
          entities.add(
            factory.zombie(
              id: upper ? barracksRoadUpperZombieId : barracksRoadZombieId,
              kind: EntityKind.wanderer,
              position: point,
              facing: upper ? Direction.south : Direction.west,
            ),
          );
        case '1':
          pickups.add(Pickup(id: ammoBackpackId, position: point, ammo: 4));
        case '2':
          pickups.add(Pickup(id: accidentBackpackId, position: point, ammo: 2));
        case '3':
          pickups.add(Pickup(id: alleyBackpackId, position: point, ammo: 2));
        case '4':
          pickups.add(Pickup(id: parkingBackpackId, position: point, ammo: 2));
        case '5':
          pickups.add(Pickup(id: boatBackpackId, position: point, ammo: 2));
        case '6':
          pickups.add(Pickup(id: shipyardBackpackId, position: point, ammo: 2));
        case '7':
          pickups.add(Pickup(id: oldTownBackpackId, position: point, ammo: 2));
        case '8':
          pickups.add(
            Pickup(
              id: mallNorthBackpackId,
              position: point,
              ammo: mallNorthBackpackAmmo,
            ),
          );
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
      id: episcopalRingPickupId,
      position: _barBackroom.tileOf('8'),
      episcopalRing: true,
    ),
    Pickup(
      id: molotovBackpackId,
      position: molotovBackpackTile,
      molotovs: molotovBackpackCount,
    ),
    Pickup(
      id: cultistRobePickupId,
      position: duomoUpperRobeTile,
      cultistRobe: true,
    ),
    // Beside Don Angelo's body: there is nothing to find in the nave until
    // the mass has ended, so it lies hidden until the script reveals it.
    Pickup(
      id: duomoKeyPickupId,
      position: duomoKeyTile,
      duomoKey: true,
      active: false,
    ),
    // On the roof of the other tower: seen from this one, reached with
    // the grappling hook.
    Pickup(
      id: duomoFarTowerBackpackId,
      position: duomoFarTowerBackpackTile,
      rockets: 1,
    ),
    Pickup(
      id: stationBackpackId,
      position: _station.tileOf('9'),
      ammo: stationBackpackAmmo,
    ),
    Pickup(
      id: airlinerBackpackId,
      position: _airlinerCabin.tileOf('9'),
      ammo: airlinerBackpackAmmo,
    ),
    Pickup(
      id: rooftopBackpackId,
      position: rooftopBackpackTile,
      ammo: rooftopBackpackAmmo,
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
    (_airlinerCabin, airlinerZombiePrefix),
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
  var hospitalZombies = 0;
  for (final floor in <Place>[
    _hospitalFirst,
    _hospitalSecond,
    _hospitalThird,
  ]) {
    for (final tile in floor.tilesOf('Z')) {
      entities.add(
        factory.zombie(
          id: '$hospitalZombiePrefix${hospitalZombies++}',
          kind: EntityKind.wanderer,
          position: tile,
        ),
      );
    }
  }
  // Lying on the floor, each one looks towards the middle of the cabin,
  // where the aisle runs.
  final cabinMiddle = _airlinerCabin.origin.y + airlinerCabinRows.length ~/ 2;
  for (final (index, tile) in _airlinerCabin.tilesOf('M').indexed) {
    entities.add(
      factory.zombie(
        id: '$airlinerMutilatedPrefix$index',
        kind: EntityKind.mutilated,
        position: tile,
        facing: tile.y < cabinMiddle ? Direction.south : Direction.north,
      ),
    );
  }
  // Out of the fire in the north-west corner, they look east, away from it.
  for (final (index, tile) in _airlinerRoofs.tilesOf('Y').indexed) {
    entities.add(
      factory.zombie(
        id: '$rooftopBurningZombiePrefix$index',
        kind: EntityKind.burning,
        position: tile,
        facing: Direction.east,
      ),
    );
  }
  for (final (index, tile) in _bar.tilesOf('U').indexed) {
    entities.add(
      factory.zombie(
        id: '$barDrunkZombiePrefix$index',
        kind: EntityKind.drunk,
        position: tile,
      ),
    );
  }
  return LevelContents(
    entities: entities,
    pickups: pickups,
    portals: _portals(),
    alertTriggers: <String, GridRect>{tutorialZombieId: tutorialZombieTrigger},
    controls: <GridPoint, GridRect>{mallPanelTile: luigiBars},
    lookouts: <GridPoint>[
      rooftopGapTile,
      duomoTowerLookoutTile,
      hospitalRoofLookoutTile,
      shoppingStreetFireTile,
      stationTrackFireTile,
    ],
    grapples: hometownGrapples,
    stairs: hometownStairs,
  );
}

/// The zombies Molfetta's story raises on the way, besides those there
/// from the start: the barracks' carabinieri, the horde at the
/// hypermarket's gate and the mutated cultists of the Duomo.
final List<EntityKind> hometownRaisedZombies = <EntityKind>[
  for (final _ in carabiniereSpawns) EntityKind.carabiniere,
  for (final _ in mallHordeSpawns) EntityKind.wanderer,
  for (final _ in duomoCultistSpawns) EntityKind.cultist,
];

/// A wanderer coming in through the hypermarket's gate at [position],
/// looking west down the corridor.
Entity createMallZombie(String id, GridPoint position) {
  return EntityFactory(
    BalanceConfig.standard(),
  ).zombie(id: id, kind: EntityKind.wanderer, position: position);
}

/// One of the mutated cultists of the Duomo, raised where the mass left
/// him: he looks out of the aisle, away from Don Angelo's body -- east at
/// the east end of the pews, west at the west end.
Entity createDuomoCultist(String id, GridPoint position) {
  return EntityFactory(BalanceConfig.standard()).zombie(
    id: id,
    kind: EntityKind.cultist,
    position: position,
    facing: position.x < duomoPriestCorpseTile.x
        ? Direction.west
        : Direction.east,
  );
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
