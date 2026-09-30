import 'package:stepbound/core/entities/components.dart';
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
export 'package:stepbound/core/levels/hometown/company.dart';
export 'package:stepbound/core/levels/hometown/duomo.dart';
export 'package:stepbound/core/levels/hometown/duomo_second_floor.dart';
export 'package:stepbound/core/levels/hometown/duomo_tower.dart';
export 'package:stepbound/core/levels/hometown/duomo_tower_roof.dart';
export 'package:stepbound/core/levels/hometown/duomo_upper.dart';
export 'package:stepbound/core/levels/hometown/east_block.dart';
export 'package:stepbound/core/levels/hometown/electronics_shop.dart';
export 'package:stepbound/core/levels/hometown/harbour.dart';
export 'package:stepbound/core/levels/hometown/hospital.dart';
export 'package:stepbound/core/levels/hometown/industry_street.dart';
export 'package:stepbound/core/levels/hometown/mall.dart';
export 'package:stepbound/core/levels/hometown/mall_north_street.dart';
export 'package:stepbound/core/levels/hometown/monument_square.dart';
export 'package:stepbound/core/levels/hometown/north_district.dart';
export 'package:stepbound/core/levels/hometown/palazzo.dart';
export 'package:stepbound/core/levels/hometown/station.dart';
export 'package:stepbound/core/levels/hometown/street.dart';

/// The picture the city stands for: the level's loading cover, its card on
/// the Europe map, and the card on the way into the harbour, which is what
/// it shows. Kept with the other levels' covers, in assets/story/maps.
const String hometownCoverImage = 'assets/story/maps/molfetta.jpg';

/// Molfetta, the first level: the street where Mario wakes up, the inside
/// of the carabinieri barracks, the north district behind it with the two
/// floors of its hypermarket and, past the car park, the block with the
/// station and its three places, and the harbour south of all that with the
/// Duomo, the Bar Arcobaleno and the church of San Nicola. Every place is
/// painted by the game from these same rows, out of assets/levels/tiles
/// (tools/build_tile_atlas.py).
///
/// Each building keeps its own module in this folder: its rows, its
/// legend, its named tiles, its stairs and its doors. This file lists the
/// places, in the order they are laid out on the shared grid (a save
/// records tiles by their coordinates, so the order is not to be changed),
/// and puts the level's contents together.
const List<PlaceSpec> hometownPlaces = <PlaceSpec>[
  PlaceSpec(
    id: PlaceId.street,
    area: AreaId.hometownTown,
    rows: streetLevelRows,
    legend: outdoorLegend,
  ),
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
  PlaceSpec(
    id: PlaceId.barArcobaleno,
    area: AreaId.hometownHarbour,
    rows: barArcobalenoRows,
    legend: barLegend,
    indoor: true,
    daylight: 'E',
    lamps: barArcobalenoLamps,
  ),
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
  PlaceSpec(
    id: PlaceId.station,
    area: AreaId.hometownTown,
    rows: stationRows,
    legend: stationLegend,
  ),
  PlaceSpec(
    id: PlaceId.stationUnderpass,
    area: AreaId.hometownTown,
    rows: stationUnderpassRows,
    legend: stationLegend,
    indoor: true,
    // Daylight falling down both flights of stairs.
    daylight: 'DU',
  ),
  // The railcar is an object in the far side's picture, and the story
  // opens its door rather than swapping a second picture of the whole
  // place.
  PlaceSpec(
    id: PlaceId.stationFarSide,
    area: AreaId.hometownTown,
    rows: stationFarSideRows,
    legend: stationLegend,
  ),
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
  // The roofs are open to the sky, so they are lit throughout.
  PlaceSpec(
    id: PlaceId.airlinerRoofs,
    area: AreaId.hometownTown,
    rows: airlinerRoofRows,
    legend: rooftopLegend,
  ),
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
  PlaceSpec(
    id: PlaceId.barBackroom,
    area: AreaId.hometownHarbour,
    rows: barBackroomRows,
    legend: barBackroomLegend,
    indoor: true,
    daylight: 'E',
  ),
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
  PlaceSpec(
    id: PlaceId.duomoSecondFloor,
    area: AreaId.hometownHarbour,
    rows: duomoSecondFloorRows,
    legend: duomoSecondFloorLegend,
    indoor: true,
    daylight: 'o',
    darkness: 0.7,
  ),
  PlaceSpec(
    id: PlaceId.duomoTower,
    area: AreaId.hometownHarbour,
    rows: duomoTowerRows,
    legend: duomoTowerLegend,
    indoor: true,
    daylight: 'o',
    darkness: 0.75,
  ),
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
  // Open to the sky.
  PlaceSpec(
    id: PlaceId.duomoTowerRoof,
    area: AreaId.hometownHarbour,
    rows: duomoTowerRoofRows,
    legend: duomoTowerRoofLegend,
  ),
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
  // Open to the sky.
  PlaceSpec(
    id: PlaceId.hospitalRoof,
    area: AreaId.hometownTown,
    rows: hospitalRoofRows,
    legend: hospitalRoofLegend,
    name: 'Tetto dell’ospedale',
  ),
  // The stairwell of the palazzo has every light on; its flats are dim,
  // not black, a lamp still working here and there and some of them going
  // on and off.
  PlaceSpec(
    id: PlaceId.palazzoThirdFloor,
    area: AreaId.hometownTown,
    rows: palazzoThirdFloorRows,
    legend: palazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    litAreas: <GridRect>[palazzoStairwell],
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.palazzoSecondFloor,
    area: AreaId.hometownTown,
    rows: palazzoSecondFloorRows,
    legend: palazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    litAreas: <GridRect>[palazzoStairwell],
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.palazzoFirstFloor,
    area: AreaId.hometownTown,
    rows: palazzoFirstFloorRows,
    legend: palazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    litAreas: <GridRect>[palazzoStairwell],
    name: 'Palazzo',
  ),
  // The entrance hall: its lights on, and daylight through the portone.
  PlaceSpec(
    id: PlaceId.palazzoGroundFloor,
    area: AreaId.hometownTown,
    rows: palazzoGroundFloorRows,
    legend: palazzoLegend,
    indoor: true,
    lit: true,
    daylight: 'E',
    name: 'Palazzo',
  ),
  // Behind the third floor's locked door: dim like the other flats.
  PlaceSpec(
    id: PlaceId.palazzoLockedFlat,
    area: AreaId.hometownTown,
    rows: palazzoLockedFlatRows,
    legend: palazzoLegend,
    indoor: true,
    darkness: palazzoFlatDarkness,
    name: 'Palazzo',
  ),
  PlaceSpec(
    id: PlaceId.industryStreet,
    area: AreaId.hometownTown,
    rows: industryStreetRows,
    legend: outdoorLegend,
  ),
  // A lamp still on here and there over the open plan, and daylight in
  // through the gate.
  PlaceSpec(
    id: PlaceId.companyGround,
    area: AreaId.hometownTown,
    rows: companyRows,
    legend: companyLegend,
    indoor: true,
    darkness: companyDarkness,
    daylight: 'E',
    // The desk lamp still on at Chiara's workstation: she is the first
    // thing seen across the glass.
    lamps: <GridPoint>[GridPoint(29, 8)],
    name: 'Azienda',
  ),
  // The floors above: the same call centre, the lamps still on here and
  // there.
  PlaceSpec(
    id: PlaceId.companyFirst,
    area: AreaId.hometownTown,
    rows: companyFirstRows,
    legend: companyLegend,
    indoor: true,
    darkness: companyDarkness,
    name: 'Azienda',
  ),
  PlaceSpec(
    id: PlaceId.companySecond,
    area: AreaId.hometownTown,
    rows: companySecondRows,
    legend: companyLegend,
    indoor: true,
    darkness: companyDarkness,
    name: 'Azienda',
  ),
  PlaceSpec(
    id: PlaceId.monumentSquare,
    area: AreaId.hometownTown,
    rows: monumentSquareRows,
    legend: outdoorLegend,
  ),
  // Its lamps `*` still on, daylight in through the door from the square.
  PlaceSpec(
    id: PlaceId.electronicsShop,
    area: AreaId.hometownTown,
    rows: electronicsShopRows,
    legend: electronicsShopLegend,
    indoor: true,
    darkness: electronicsShopDarkness,
    daylight: 'E',
    name: 'Elettronica',
  ),
  // The block east of the hospital's roof: its stairwell and the corridor
  // across each floor have every light on; its flats and offices are
  // nearly black, a lamp flickering here and there.
  PlaceSpec(
    id: PlaceId.eastBlockTopFloor,
    area: AreaId.hometownTown,
    rows: eastBlockTopFloorRows,
    legend: eastBlockLegend,
    indoor: true,
    darkness: eastBlockDarkness,
    litAreas: <GridRect>[eastBlockStairwell, eastBlockCorridor],
    name: eastBlockName,
  ),
  PlaceSpec(
    id: PlaceId.eastBlockLowerFloor,
    area: AreaId.hometownTown,
    rows: eastBlockLowerFloorRows,
    legend: eastBlockLegend,
    indoor: true,
    darkness: eastBlockDarkness,
    litAreas: <GridRect>[eastBlockStairwell, eastBlockCorridor],
    name: eastBlockName,
  ),
];

/// The places [outdoorLegend] describes: what walks the streets, what
/// burns in them and what is dropped in them is read off these and no
/// others. It is not the same as `!place.indoor` -- the station's
/// platforms are open to the sky, and so lit like a street, but their
/// glyphs are their own.
Iterable<Place> get _streets => <Place>[
  place(PlaceId.street),
  place(PlaceId.northDistrict),
  place(PlaceId.harbour),
  place(PlaceId.mallNorthStreet),
  place(PlaceId.industryStreet),
  place(PlaceId.monumentSquare),
];

/// The wanderers standing in the places the outdoor glyphs do not reach:
/// the nave of San Nicola and the station's booking hall, both `Z`.
const String indoorZombiePrefix = 'indoor-wanderer-';

/// Camps in places that still have one each, and what a save there is
/// called. The harbour has two explicitly named fires below.
const Map<PlaceId, String> _campNames = <PlaceId, String>{
  PlaceId.northDistrict: 'Dietro la caserma',
  PlaceId.mallNorthStreet: 'Zona nord',
  PlaceId.industryStreet: 'Davanti all’azienda',
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

/// Fires of every outdoor place but the bin put out behind the barracks,
/// those on the station's burning car and the camp on the hospital's roof.
final List<FireSpot> hometownFireSpots = <FireSpot>[
  for (final place in _streets)
    for (final spot in firesIn(place))
      if (spot.tile != extinguishedNorthDistrictBinTile) spot,
  ...stationWreckFireSpots,
  ...hospitalRoofFireSpots,
];

/// Molfetta's doors to places not drawn yet (see `workInProgressDoors`):
/// none, now that the block east of the hospital's roof has its floors.
final Set<GridPoint> hometownWorkInProgressDoors = <GridPoint>{};

/// Molfetta's flights of stairs out in the open, each step with the way
/// up it (see `WorldState.stairs`): the hypermarket's, the stairwells on
/// the roofs across the gaps and the station's.
final Map<GridPoint, Direction> hometownStairs = <GridPoint, Direction>{
  ...mallStairs,
  ...rooftopStairs,
  ...hospitalStairs,
  ...stationStairs,
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

/// Every door of Molfetta, both ways: each building's, from its module.
Map<GridPoint, Portal> _portals() => <GridPoint, Portal>{
  ...barracksPortals,
  ...harbourPortals,
  ...mallPortals,
  ...barPortals,
  ...churchPortals,
  ...duomoPortals,
  ...stationPortals,
  ...airlinerPortals,
  ...hospitalPortals,
  ...eastBlockPortals,
  ...palazzoPortals,
  ...companyPortals,
  ...monumentSquarePortals,
  ...electronicsShopPortals,
};

/// What Molfetta holds when a game starts: Mario on the street, its
/// zombies and backpacks, its doors, the tutorial zombie's trigger, the
/// hypermarket's panel and what can be looked at.
LevelContents hometownContents(EntityFactory factory) {
  final entities = <Entity>[];
  final pickups = <Pickup>[];
  final zombieCounts = <EntityKind, int>{};
  var forecourtZombies = 0;
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
          final milling = hospitalForecourt.contains(point);
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
              facing: milling
                  ? hospitalForecourtFacings[forecourtZombies++ %
                        hospitalForecourtFacings.length]
                  : Direction.west,
            ),
          );
        case '♪':
          entities.add(
            factory.zombie(
              id: caparezzaZombieId,
              kind: EntityKind.wanderer,
              position: point,
            ),
          );
        case '9':
          // The upper of the two is the one further up the road.
          final upper = point.y < barracksRoadZombieTiles.last.y;
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
        case 'µ':
          pickups.add(
            Pickup(
              id: pharmacyBackpackId,
              position: point,
              ammo: pharmacyBackpackAmmo,
            ),
          );
      }
    }
  }
  entities
    ..add(
      factory.zombie(
        id: hospitalForecourtSprinterId,
        kind: EntityKind.sprinter,
        position: hospitalForecourtSprinterTile,
        facing: Direction.east,
      ),
    )
    // Shut in the flat behind the palazzo's locked door, turned to it
    // (west, the way a zombie faces unless told).
    ..add(
      factory.zombie(
        id: palazzoSprinterId,
        kind: EntityKind.sprinter,
        position: palazzoSprinterTile,
      ),
    );
  // The places whose own glyphs the outdoor legend does not reach: their
  // one backpack is placed by hand, at the tile its module names.
  pickups.addAll(<Pickup>[
    Pickup(id: gunBackpackId, position: gunBackpackTile, gun: true),
    Pickup(id: incenseBackpackId, position: incenseBackpackTile, incense: true),
    Pickup(
      id: episcopalRingPickupId,
      position: episcopalRingTile,
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
      rockets: duomoFarTowerBackpackRockets,
    ),
    Pickup(
      id: stationBackpackId,
      position: stationBackpackTile,
      ammo: stationBackpackAmmo,
    ),
    Pickup(
      id: airlinerBackpackId,
      position: airlinerBackpackTile,
      ammo: airlinerBackpackAmmo,
    ),
    Pickup(
      id: rooftopBackpackId,
      position: rooftopBackpackTile,
      ammo: rooftopBackpackAmmo,
    ),
    Pickup(id: palazzoBackpackId, position: palazzoBackpackTile, ammo: 2),
    Pickup(id: palazzoKeyPickupId, position: palazzoKeyTile, palazzoKey: true),
    Pickup(
      id: palazzoMolotovBackpackId,
      position: palazzoMolotovBackpackTile,
      molotovs: 2,
    ),
    Pickup(id: companyBackpackId, position: companyBackpackTile, ammo: 2),
    // In the offices at the bottom of the block east of the hospital's
    // roof: the rounds for it are found elsewhere, one on the Duomo's
    // other tower.
    Pickup(
      id: rocketLauncherPickupId,
      position: rocketLauncherTile,
      rocketLauncher: true,
    ),
  ]);
  // `Z` is a wanderer standing in the dark of a building, numbered in
  // reading order of its module's rows.
  for (final (tiles, prefix) in <(List<GridPoint>, String)>[
    (
      <GridPoint>[...churchZombieTiles, ...stationHallZombieTiles],
      indoorZombiePrefix,
    ),
    (mallGroundZombieTiles, mallGroundZombiePrefix),
    (stationUnderpassZombieTiles, stationUnderpassZombiePrefix),
    (airlinerZombieTiles, airlinerZombiePrefix),
    (hospitalZombieTiles, hospitalZombiePrefix),
  ]) {
    entities.addAll(_wanderers(factory, tiles, prefix));
  }
  // The call-centre operators, each on the cord of its handset: its back
  // to the desk, turned to the room, it sees who comes down the aisle in
  // front of it.
  for (final (index, (tile, desk)) in companyCallers.indexed) {
    entities.add(
      factory.zombie(
        id: '$companyCallerPrefix$index',
        kind: EntityKind.callCenter,
        position: tile,
        facing: Direction.values.firstWhere(
          (direction) => tile.step(direction.opposite) == desk,
        ),
        tether: TetherComponent(anchor: desk, length: companyCordLength),
      ),
    );
  }
  for (final (tiles, prefix) in <(List<GridPoint>, String)>[
    (electronicsShopZombieTiles, electronicsShopZombiePrefix),
    (palazzoZombieTiles, palazzoZombiePrefix),
    (eastBlockZombieTiles, eastBlockZombiePrefix),
  ]) {
    entities.addAll(_wanderers(factory, tiles, prefix));
  }
  // Lying on the floor, each one looks towards the middle of the cabin,
  // where the aisle runs.
  for (final (index, tile) in airlinerMutilatedTiles.indexed) {
    entities.add(
      factory.zombie(
        id: '$airlinerMutilatedPrefix$index',
        kind: EntityKind.mutilated,
        position: tile,
        facing: tile.y < airlinerCabinAisleRow
            ? Direction.south
            : Direction.north,
      ),
    );
  }
  // Out of the fire in the north-west corner, they look east, away from it.
  for (final (index, tile) in rooftopBurningZombieTiles.indexed) {
    entities.add(
      factory.zombie(
        id: '$rooftopBurningZombiePrefix$index',
        kind: EntityKind.burning,
        position: tile,
        facing: Direction.east,
      ),
    );
  }
  for (final (index, tile) in barDrunkZombieTiles.indexed) {
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
      northDistrictFireTile,
      stationTrackFireTile,
      ...oldTownDamagedDoorTiles,
      // Chiara at her desk, to talk to once she has been reached.
      chiaraTile,
    ],
    grapples: hometownGrapples,
    stairs: hometownStairs,
  );
}

/// A wanderer on each of [tiles], `<prefix><n>` in the order given.
List<Entity> _wanderers(
  EntityFactory factory,
  List<GridPoint> tiles,
  String prefix,
) => <Entity>[
  for (final (index, tile) in tiles.indexed)
    factory.zombie(
      id: '$prefix$index',
      kind: EntityKind.wanderer,
      position: tile,
    ),
];

/// The zombies Molfetta's story raises on the way, besides those there
/// from the start: the barracks' carabinieri, the horde at the
/// hypermarket's gate and the mutated cultists of the Duomo.
final List<EntityKind> hometownRaisedZombies = <EntityKind>[
  for (final _ in carabiniereSpawns) EntityKind.carabiniere,
  for (final _ in mallHordeSpawns) EntityKind.wanderer,
  for (final _ in duomoCultistSpawns) EntityKind.cultist,
];
