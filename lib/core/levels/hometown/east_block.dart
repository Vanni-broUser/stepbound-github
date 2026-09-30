import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// The block east of the hospital's roof, across the gap the grappling
/// hook takes Mario over: the open stairwell on its roof goes down into
/// its top floor. Flats and offices on every floor, the stairs `U` up and
/// `D` down in the middle of it, on the landing they all share, and a
/// corridor across the floor from wall to wall: the way up climbs into
/// the back wall of the floor below and comes out of the front wall of
/// the floor above (the hospital's rule). The stairwell and the corridor
/// are lit; the flats and the offices are dark but for a lamp flickering
/// here and there and the screens still on.
///
/// Two floors: the top one and the one below it, where the stairs on down
/// are buried under the ceiling that came down over them. Nobody gets
/// further down: that floor is the end of the block, and in its offices
/// lies the backpack with the rocket launcher.
///
/// Glyphs of both floors:
/// - `x` darkness, `W` the back wall (two courses), `w` the front wall,
///   `I` a partition, `G` the glass wall of the manager's office: walls.
/// - `U` the stairs up, `D` the stairs down: doors. `P` a door onto the
///   corridor, kicked in, and `d` a doorway between two rooms: floor.
/// - Floors: `.` parquet (living rooms, bedrooms), `,` the kitchen's
///   tiles, `_` the bathroom's, `=` the marble of the stairwell and the
///   corridor, `~` the offices' carpet tiles.
/// - In the flats: `S` a sofa, `a` an armchair, `V` a TV cabinet and `T`
///   a table (two cells each), `h` a chair, `B` a bed (two cells, head to
///   the north), `n` a bedside table, `A` a wardrobe, `l` a bookcase, `K`
///   kitchen units, `O` the cooker, `F` the fridge, `H` a washbasin, `Q`
///   the toilet, `R` the bathtub (two cells), `p` a potted palm, `r` a
///   heap where the ceiling came down: obstacles.
/// - In the offices: `o` a workstation facing the corridor, its screen
///   towards the room, `y` one facing away, `|` and `-` the cubicles'
///   panels, `g` an office chair, `t` the meeting table, `C` a filing
///   cabinet, `j` the photocopier, `m` a vending machine, `u` the water
///   cooler: obstacles.
/// - `:` plaster down off the ceiling (noisy), `b` blood, `c` a body,
///   `*` ceiling lamp, `+` flickering lamp, `Z` a wanderer, `9` the
///   backpack with the rocket launcher.
///
/// The top floor, where the stairs from the roof come down: a flat west
/// of the corridor on either side of it, an office east of it on either
/// side.
// east-block-top-rows-start
const List<String> eastBlockTopFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWx',
  'xl.VV.....aIKKOKF,,Ip=====IC~-------~~-------x',
  'x..........I,,,+,,,I======I~~o|o|o|o~~o|o|o|ox',
  'x..SSS.....d,,,,,,,I=*====I~~g|g|g|g~~g|g|g|gx',
  'x.....hTTh.I,hTTh,,I======I~~~tt~+~~~~~~~~~~~x',
  'xc......:..I,,,Z,,,I======I~~~~~~~~~~c~~~~Z~~x',
  'xIIIIIIPIIIIIIIIIIII======IIIIIIIIIPIIIIIIIIIx',
  'x===*========b=====*==========*=====:====*===x',
  'x========Z=============:==========Z==========x',
  'xIIIIIIIIIIIPIIIIIII======IIIIIIIIPIIIIIIIIIIx',
  'xAnBBn....IH______QI======I~~~~~~~~~~~~~+~~~~x',
  'x..BB....lI__+_____I======I~g|g|g|g~~g|g|g|g~x',
  'x.........d______RRI======I~y|y|y|y~~y|y|y|y~x',
  'x..Z...:..I_c______I======I~-------~~-------~x',
  'x.+.......I____b___I=*====Ij~~~~~~~~:~~~~~~~mx',
  'xA.......cI________I=====pIC~~~Z~~~~~~~c~~~~ux',
  'xwwwwwwwwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// east-block-top-rows-end

/// The floor below, the last one: the manager's office behind its glass
/// in the north-east, the backpack with the rocket launcher in the far
/// corner of the south-east office, and in front of the stairs `D` in the
/// front wall the heap of the ceiling that came down over them.
// east-block-lower-rows-start
const List<String> eastBlockLowerFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWx',
  'xA....l...aIH_____QIp=====Itt~~~~G~~~-------~x',
  'x..........I_______I======Itt~~~~G~~~o|o|o|o~x',
  'x.SSS......d__+____I=*====I~~~~~~d~~~g|g|g|g~x',
  'x......hTThI____RR_I======I~~C~~~G~~~~~~~~+~~x',
  'x.b....:...I_c_____I======I~~~C~~G~~~~~~~c~~~x',
  'xIIIPIIIIIIIIIIIIIII======IIIIIIIIIIIIIPIIIIIx',
  'x=====*========:==*============*======b===*==x',
  'x==========c========Z============:======Z====x',
  'xIIIIIIIIIIIIIPIIIII======IIIIIIIIIIIPIIIIIIIx',
  'xKKOKF,,InBBn....A.I======I~~~~~~~~~~~~~~~+~~x',
  'x,,,,,,,I.BB.......I======I~-------~~-------~x',
  'x,hTTh,,d..........I======I~o|o|o|o~~o|o|o|o~x',
  'x,,,,,+,I...Z..:...I======I~g|g|g|g~~g|g|g|g~x',
  'x,,c,,,,Il.........I==:===I~~~~~~~~:~~~~~~~~~x',
  'x,,,,,b,IA......+.cI:rrr:pI9C~~Z~~~~~c~~~~Zjux',
  'xwwwwwwwwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// east-block-lower-rows-end

/// What the block is called, on the way in and in the save slots.
const String eastBlockName = 'Palazzo accanto all’ospedale';

/// The block's stairwell on both floors, from its back wall to its front
/// wall, and the corridor across the middle of the floor: lit throughout
/// (see `PlaceSpec.litAreas`).
const GridRect eastBlockStairwell = GridRect(20, 1, 25, 18);
const GridRect eastBlockCorridor = GridRect(1, 9, 44, 10);

/// How dark the flats and the offices are between their lamps: nearly
/// black, the few lamps left flickering.
const double eastBlockDarkness = 0.84;

/// The block's floors: the walls, the partitions and the glass are solid,
/// and what furnishes a flat or an office stops a step but not a shot.
/// The plaster down off the ceilings crunches underfoot.
const Legend eastBlockLegend = Legend(
  walls: 'xWwIG',
  obstacles:
      'SaVThBnAlKOFHQRpr'
      'oy|-gCjmut',
);

final Place _eastBlockTop = place(PlaceId.eastBlockTopFloor);
final Place _eastBlockLower = place(PlaceId.eastBlockLowerFloor);

/// The block's stairs, bottom to top: the flight `U` up in the back wall
/// of the lower floor, and where it comes out, the flight `D` down in the
/// front wall of the top floor.
final List<(GridPoint, GridPoint)> eastBlockFlights = <(GridPoint, GridPoint)>[
  (_eastBlockLower.tileOf('U'), _eastBlockTop.tileOf('D')),
];

/// The top of the block's stairwell, on the top floor: up it, the open
/// stairwell on the block's roof, across the gap from the hospital's.
final GridPoint eastBlockRoofStairs = _eastBlockTop.tileOf('U');

/// The stairs on down from the lower floor, in its front wall: buried
/// under the heap of the ceiling, and no door to anywhere.
final GridPoint eastBlockBuriedStairs = _eastBlockLower.tileOf('D');

/// The backpack with the rocket launcher, in the far corner of the lower
/// floor's south-east office.
const String rocketLauncherPickupId = 'rocket-launcher';
final GridPoint rocketLauncherTile = _eastBlockLower.tileOf('9');

/// The wanderers `Z` left in the block, top floor first,
/// `east-block-wanderer-<n>`.
const String eastBlockZombiePrefix = 'east-block-wanderer-';
final List<GridPoint> eastBlockZombieTiles = <GridPoint>[
  for (final floor in <Place>[_eastBlockTop, _eastBlockLower])
    ...floor.tilesOf('Z'),
];

/// Down the stairwell on the block's roof into its top floor and back up
/// onto the step before its foot, and the flight between the two floors.
/// All both ways.
final Map<GridPoint, Portal> eastBlockPortals = <GridPoint, Portal>{
  for (final step in hospitalNextRoofStairsFoot)
    step: Portal(
      to: eastBlockRoofStairs.step(Direction.south),
      facing: Direction.south,
    ),
  eastBlockRoofStairs: Portal(
    to: hospitalNextRoofStairsFoot.first.step(Direction.north),
    facing: Direction.north,
  ),
  for (final (below, above) in eastBlockFlights) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
};
