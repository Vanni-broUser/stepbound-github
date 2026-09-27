import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/levels/place.dart';

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

/// The fires [place]'s rows put in it: bins `F`, windows `f`, campfires
/// `S`, and cars `X` (or `k`, parked north-south).
List<FireSpot> firesIn(Place place) {
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
