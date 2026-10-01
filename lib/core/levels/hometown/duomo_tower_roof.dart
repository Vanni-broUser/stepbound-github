import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// The top of the Duomo's bell tower, and the top of its twin across the
/// east end of the church. Mario comes out of the hatch `D` onto a flat
/// stone roof walled by its parapet `^`, with a lightning rod `n` at one
/// corner. The other tower stands just across, too far to jump, with a
/// backpack `9` left on its roof. `>` is the stretch of parapet facing it,
/// where Mario measures the gap, and where the grappling hook takes him
/// over to the parapet straight across, and back. `:` is grit and fallen
/// stone.
///
/// Everything else, `x`, is the long way down, and it is all in view: the
/// Duomo itself below the towers, its three domes in a row along the nave
/// and the stone roofs of its aisles, the white terraces of the old town
/// either side, and to the south, as on the harbour map, the sagrato, the
/// palazzi and the alley with its gate, the seafront road, the promenade
/// and at last the sea. None of it
/// can be walked on; the atlas paints it as one picture round the towers.
// duomo-roof-rows-start
const List<String> duomoTowerRoofRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxx^^^^^^^^xxxxxx^^^^^^^^xxxxxxxxxx',
  'xxxxxxxxxx^......^xxxxxx^......^xxxxxxxxxx',
  'xxxxxxxxxx^.n....^xxxxxx^..9...^xxxxxxxxxx',
  'xxxxxxxxxx^..:...>xxxxxx^......^xxxxxxxxxx',
  'xxxxxxxxxx^......^xxxxxx^....:.^xxxxxxxxxx',
  'xxxxxxxxxx^....D.^xxxxxx^......^xxxxxxxxxx',
  'xxxxxxxxxx^^^^^^^^xxxxxx^^^^^^^^xxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// duomo-roof-rows-end

/// The top of the tower: the drop `x` and the nave roof far below `=` are
/// walls, while the parapet `^`, the stretch of it Mario looks over `>`
/// and the lightning rod `n` can be seen over.
const Legend duomoTowerRoofLegend = Legend(walls: 'x=', obstacles: '^>n');

final Place _duomoRoof = place(PlaceId.duomoTowerRoof);

/// The hatch Mario comes out of, up the bell tower's last flight.
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
/// out of reach without the grappling hook: two rounds for the rocket
/// launcher, which lies at the bottom of the block east of the hospital.
final GridPoint duomoFarTowerBackpackTile = _duomoRoof.tileOf('9');
const String duomoFarTowerBackpackId = 'backpack-duomo-tower';

/// How many rounds it holds.
const int duomoFarTowerBackpackRockets = 2;

/// The two cultists waiting on the other tower, in its far corners: there
/// from the start, turned towards where the hook lands Mario, and never in
/// sight from this tower (see [duomoTowerRoofCameraZones]).
final List<GridPoint> duomoFarTowerCultistTiles = <GridPoint>[
  GridPoint(duomoFarTowerEdgeTile.x + 6, duomoFarTowerEdgeTile.y - 2),
  GridPoint(duomoFarTowerEdgeTile.x + 5, duomoFarTowerEdgeTile.y + 2),
];
const String duomoFarTowerCultistPrefix = 'duomo-tower-cultist-';

/// The cultists on the other tower, one on each of
/// [duomoFarTowerCultistTiles].
List<Entity> createDuomoTowerCultists() {
  final factory = EntityFactory(BalanceConfig.standard());
  return <Entity>[
    for (final (index, tile) in duomoFarTowerCultistTiles.indexed)
      factory.zombie(
        id: '$duomoFarTowerCultistPrefix$index',
        kind: EntityKind.cultist,
        position: tile,
      ),
  ];
}

/// The first columns of the roofs the view never shows with Mario on
/// this tower, in the place's own tiles: the far corners of the other
/// tower, where its cultists wait. The backpack, two columns short of
/// them, stays in sight.
const int duomoFarTowerHiddenFromColumn = 29;

/// With Mario on this tower, or over the first half of the gap, the view
/// stops short of [duomoFarTowerHiddenFromColumn], however wide the
/// screen: it is a column wider than the widest view
/// (`IntegerResolutionViewport.maxAspect`). Over the other half, and on
/// the other tower, it slides over to show the whole roofscape, and them.
const List<CameraZone> duomoTowerRoofCameraZones = <CameraZone>[
  CameraZone(
    area: GridRect(0, 0, 20, 41),
    limits: GridRect(0, 0, duomoFarTowerHiddenFromColumn - 2, 41),
  ),
];
