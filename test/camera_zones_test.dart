import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';

/// The screens the view has to work on: the Redmi 9 the game is tried on,
/// the usual 16:9, a 4:3 tablet (the squarest the game allows) and the
/// longest phone it allows.
const Map<String, Size> _screens = <String, Size>{
  'Redmi 9': Size(2340, 1080),
  '16:9': Size(1920, 1080),
  '4:3 tablet': Size(1440, 1080),
  '2.4:1': Size(2400, 1000),
};

Vector2 _feet(GridPoint tile) => Vector2(tile.x * 16 + 8, (tile.y + 1) * 16.0);

Rect _view(CameraComponent camera, Size screen) {
  final zoom = camera.viewfinder.zoom;
  return Rect.fromCenter(
    center: Offset(camera.viewfinder.position.x, camera.viewfinder.position.y),
    width: screen.width / zoom,
    height: screen.height / zoom,
  );
}

/// The cells of [offMap] that [view] shows any of (more than a rounding
/// error of).
List<GridPoint> _shown(Rect view, Set<GridPoint> offMap) => <GridPoint>[
  for (
    var y = ((view.top + 0.01) / 16).floor();
    y * 16 < view.bottom - 0.01;
    y++
  )
    for (
      var x = ((view.left + 0.01) / 16).floor();
      x * 16 < view.right - 0.01;
      x++
    )
      if (offMap.contains(GridPoint(x, y))) GridPoint(x, y),
];

void main() {
  // Every place with cells off its map: wherever Mario stands, on any
  // screen, the view stops at its camera zones' edges and shows none of
  // them -- nor while it slides from one zone's edges to the next.
  for (final place in gamePlaces) {
    final offMap = place.tilesOf(Legend.offMap).toSet();
    if (offMap.isEmpty) {
      continue;
    }
    final standing = <GridPoint>[
      for (final (tile, glyph) in place.glyphs)
        if (Tile(place.kindOf(glyph)).isWalkable) tile,
    ];
    String local(GridPoint tile) =>
        '(${tile.x - place.origin.x}, ${tile.y - place.origin.y})';

    test('${place.id.name}: nothing off the map is ever in view', () {
      for (final MapEntry(key: name, value: screen) in _screens.entries) {
        final camera = CameraComponent()
          ..viewport.size = Vector2(screen.width, screen.height);
        final follow = FollowCamera(camera);
        for (final tile in standing) {
          follow.snapTo(_feet(tile), place);
          expect(
            _shown(_view(camera, screen), offMap),
            isEmpty,
            reason: 'on $name, Mario on ${local(tile)}',
          );
        }
      }
    });

    test('${place.id.name}: walking into another camera zone, the view '
        'slides to its edges and shows nothing off the map', () {
      final crossings = <(GridPoint, GridPoint)>[
        for (final from in standing)
          for (final way in Direction.values)
            if (standing.contains(from.step(way)) &&
                place.cameraLimitsAt(from) !=
                    place.cameraLimitsAt(from.step(way)))
              (from, from.step(way)),
      ];
      expect(crossings, isNotEmpty, reason: 'the place has camera zones');
      for (final MapEntry(key: name, value: screen) in _screens.entries) {
        final camera = CameraComponent()
          ..viewport.size = Vector2(screen.width, screen.height);
        final follow = FollowCamera(camera);
        for (final (from, to) in crossings) {
          follow.snapTo(_feet(from), place);
          for (var frame = 0; frame < 90; frame++) {
            follow.follow(player: _feet(to), place: place, dt: 1 / 60);
            expect(
              _shown(_view(camera, screen), offMap),
              isEmpty,
              reason: 'on $name, from ${local(from)} to ${local(to)}',
            );
          }
        }
      }
    });
  }

  test('the edges slide over rather than jump, and settle', () {
    final place = gamePlaces.firstWhere(
      (place) => place.id == PlaceId.northDistrict,
    );
    const screen = Size(1920, 1080);
    final camera = CameraComponent()
      ..viewport.size = Vector2(screen.width, screen.height);
    final follow = FollowCamera(camera);
    // Up the side road north of the crossroads, into its zone: the view
    // stops two rows past the pile-up, but only once it has slid there.
    final fire = northDistrictFireTile;
    final below = fire.step(Direction.south);
    expect(place.cameraLimitsAt(below), isNot(place.bounds));
    final outside = GridPoint(below.x, below.y + 10);
    expect(place.cameraLimitsAt(outside), place.bounds);
    follow.snapTo(_feet(outside), place);
    final tops = <double>[];
    for (var frame = 0; frame < 120; frame++) {
      follow.follow(player: _feet(below), place: place, dt: 1 / 60);
      tops.add(_view(camera, screen).top);
    }
    final limit = place.cameraLimitsAt(below).top * 16.0;
    expect(tops.first, lessThan(limit), reason: 'not there at once');
    expect(tops.last, limit, reason: 'there in the end');
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] - tops[i - 1], lessThan(16), reason: 'frame $i');
    }
  });
}
