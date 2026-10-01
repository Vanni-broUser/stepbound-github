import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';

/// The cultists on the Duomo's other tower stay out of the view as long as
/// Mario is on the first, on every screen the game takes, and are in it
/// once he is over.
void main() {
  final roof = place(PlaceId.duomoTowerRoof);
  final world = createGameWorld();
  final landing = world.grapples[duomoTowerLookoutTile]!.to;

  // From a 4:3 tablet to the widest phone the view keeps its shape for
  // (`IntegerResolutionViewport.maxAspect`).
  const screens = <(String, double, double)>[
    ('4:3', 1024, 768),
    ('16:10', 1280, 800),
    ('16:9', 1920, 1080),
    ('2:1', 2160, 1080),
    ('20:9', 2400, 1080),
    ('21:9', 2520, 1080),
    ('2.4:1', 2592, 1080),
  ];

  Rect shownWith(Vector2 feet, double width, double height) {
    // The game's own viewport: the whole screen.
    final camera = CameraComponent(viewport: MaxViewport())
      ..viewport.size = Vector2(width, height);
    FollowCamera(camera).snapTo(feet, roof);
    final zoom = camera.viewfinder.zoom;
    expect(zoom, greaterThan(1), reason: 'the screen, not the 16:9 view');
    return Rect.fromCenter(
      center: Offset(
        camera.viewfinder.position.x,
        camera.viewfinder.position.y,
      ),
      width: width / zoom,
      height: height / zoom,
    );
  }

  Vector2 feetOn(GridPoint tile) =>
      Vector2(tile.x * 16 + 8, (tile.y + 1) * 16.0);

  Rect tileRect(GridPoint tile) =>
      Rect.fromLTWH(tile.x * 16.0, tile.y * 16.0, 16, 16);

  // Every tile of the first tower Mario can stand on, and the first half
  // of the swing over the gap.
  final nearSide = <GridPoint>[
    for (final (tile, _) in roof.glyphs)
      if (tile.x <= duomoTowerLookoutTile.x &&
          world.map.tileAt(tile).isWalkable)
        tile,
    for (var x = duomoTowerLookoutTile.x; x <= roof.origin.x + 20; x++)
      GridPoint(x, duomoTowerLookoutTile.y),
  ];

  for (final (name, width, height) in screens) {
    test('on a $name screen, nothing of the cultists shows from the first '
        'tower, the backpack across does', () {
      var backpackSeen = false;
      for (final tile in nearSide) {
        final shown = shownWith(feetOn(tile), width, height);
        for (final cultist in duomoFarTowerCultistTiles) {
          expect(
            shown.overlaps(tileRect(cultist)),
            isFalse,
            reason: 'Mario on $tile sees the cultist on $cultist',
          );
        }
        backpackSeen |= shown.overlaps(tileRect(duomoFarTowerBackpackTile));
      }
      expect(backpackSeen, isTrue);
    });

    test('on a $name screen, both cultists are in view once Mario has '
        'landed', () {
      final shown = shownWith(feetOn(landing), width, height);
      for (final cultist in duomoFarTowerCultistTiles) {
        expect(shown.contains(tileRect(cultist).center), isTrue);
      }
    });
  }
}
