import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

export 'package:stepbound/core/levels/rome/termini.dart';

/// Roma Termini (termini.dart) keeps to the far platform's glyphs, but
/// its train's door `P` is open from the start: the train is Mario's own.
/// The name board high on the wall `Q` is wall, the one on its posts at
/// the platform's edge `o` can be seen over.
const Legend terminiLegend = Legend(walls: 'xWMQ|', obstacles: 'Tno');

/// Rome, the second level: for now Roma Termini alone, on the same grid as
/// Molfetta. The train is the one place the two levels share, and there is
/// no road between them.
const List<PlaceSpec> romePlaces = <PlaceSpec>[
  PlaceSpec(
    id: PlaceId.romeTermini,
    area: AreaId.romeTermini,
    rows: terminiRows,
    legend: terminiLegend,
  ),
];

final Place _termini = place(PlaceId.romeTermini);

/// The passenger door of the train standing at Roma Termini, open onto
/// the platform.
final GridPoint terminiTrainDoorTile = _termini.tileOf('P');

/// The stairs out of Termini: for now the end of the playable game.
final List<GridPoint> terminiExitTiles = _termini.tilesOf('D');

/// The wanderers on the platforms of Termini, `termini-wanderer-<n>`.
const String terminiZombiePrefix = 'termini-wanderer-';

/// What Rome holds when a game starts: the dead wandering Termini's
/// platforms.
LevelContents romeContents(EntityFactory factory) => LevelContents(
  entities: <Entity>[
    for (final (index, spot) in terminiZombieSpots.indexed)
      factory.zombie(
        id: '$terminiZombiePrefix$index',
        kind: EntityKind.wanderer,
        position: GridPoint(
          _termini.origin.x + spot.x,
          _termini.origin.y + spot.y,
        ),
      ),
  ],
);
