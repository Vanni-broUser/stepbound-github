import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';

/// The screens the view has to work on: the Redmi 9 the game is tried on,
/// the usual 16:9 and a 4:3 tablet, the squarest the game allows.
const Map<String, Size> _screens = <String, Size>{
  'Redmi 9': Size(2340, 1080),
  '16:9': Size(1920, 1080),
  '4:3 tablet': Size(1440, 1080),
};

/// How far above its tile a zombie's head reaches, in pixels.
const double _headroom = 12;

/// The whole view, as the game frames it with Mario standing on [mario].
Rect _viewAround(GridPoint mario, Place place, Size screen) {
  // A MaxViewport takes the size it is given; a fixed one has none until
  // it is mounted, and the view would fall back to the 16:9 one.
  final camera = CameraComponent()
    ..viewport.size = Vector2(screen.width, screen.height);
  FollowCamera(
    camera,
  ).snapTo(Vector2(mario.x * 16 + 8, (mario.y + 1) * 16.0), place);
  final zoom = camera.viewfinder.zoom;
  return Rect.fromCenter(
    center: Offset(camera.viewfinder.position.x, camera.viewfinder.position.y),
    width: screen.width / zoom,
    height: screen.height / zoom,
  );
}

bool _framed(Rect view, GridPoint zombie) =>
    view.left <= zombie.x * 16 &&
    view.right >= (zombie.x + 1) * 16 &&
    view.top <= zombie.y * 16 - _headroom &&
    view.bottom >= (zombie.y + 1) * 16;

/// The tiles of [place] Mario can stand on from which the zombie on
/// [zombie] can notice him: seen or tracked (its vision, plus the two
/// tiles a hunt keeps it going), heard by the path, or, for the zombie of
/// the first street, stepping into its [trigger].
Set<GridPoint> _noticedFrom(
  WorldState world,
  Place place,
  GridPoint zombie,
  EntityKind kind, {
  GridRect? trigger,
}) {
  final stats = BalanceConfig.standard().actors[kind]!;
  final heard = world.map.floodFillDistances(
    zombie,
    maxDistance: stats.hearing,
  );
  return <GridPoint>{
    for (var y = place.bounds.top; y <= place.bounds.bottom; y++)
      for (var x = place.bounds.left; x <= place.bounds.right; x++)
        if (world.map.tileAt(GridPoint(x, y)).isWalkable &&
            (GridPoint(x, y).manhattanDistanceTo(zombie) <= stats.vision + 2 ||
                heard.containsKey(GridPoint(x, y)) ||
                (trigger?.contains(GridPoint(x, y)) ?? false)))
          GridPoint(x, y),
  };
}

void main() {
  // The first zombie of each kind met by the story is already in the whole
  // view when it notices Mario, whatever the screen: its lesson is shown
  // with no pan to it (see StoryDirector.introduceZombie).
  final world = createGameWorld();
  final cases = <String, (PlaceId, GridPoint, EntityKind, GridRect?)>{
    'the zombie of the first street': (
      PlaceId.street,
      world.entities[tutorialZombieId]!.component<PositionComponent>().position,
      EntityKind.wanderer,
      tutorialZombieTrigger,
    ),
    for (final spawn in carabiniereSpawns)
      'the carabiniere coming out at $spawn': (
        PlaceId.barracks,
        spawn,
        EntityKind.carabiniere,
        null,
      ),
  };
  for (final MapEntry(key: name, value: (id, zombie, kind, trigger))
      in cases.entries) {
    test('$name is on screen wherever it notices Mario from', () {
      final shown = place(id);
      final from = _noticedFrom(world, shown, zombie, kind, trigger: trigger);
      expect(from, isNotEmpty);
      for (final MapEntry(key: screenName, value: screen) in _screens.entries) {
        final hidden = <GridPoint>[
          for (final mario in from)
            if (!_framed(_viewAround(mario, shown, screen), zombie)) mario,
        ];
        expect(hidden, isEmpty, reason: 'on $screenName, Mario standing on');
      }
    });
  }
}
