import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('the fire on the roofs past the airliner', () {
    final roofs = place(PlaceId.airlinerRoofs);
    final middle = GridPoint(roofs.origin.x + 10, roofs.origin.y + 5);

    void standAt(GridPoint tile) =>
        world.player.component<PositionComponent>().position = tile;

    void burnAround(GridPoint tile) {
      for (final side in Direction.values) {
        world.map.setTile(tile.step(side), const Tile(TileKind.fire));
      }
    }

    test('shut in by it, the game ends with the line that says so, once', () {
      standAt(middle);
      settle();
      expect(host.noWayOut, isEmpty, reason: 'the roofs are wide open');

      burnAround(middle);
      director
        ..onEvents(<WorldEvent>[
          FireStartedEvent(at: middle.step(Direction.east), entityId: 'z'),
        ])
        ..update(0.1, turnAnimating: true);
      expect(host.noWayOut, isEmpty, reason: 'not while the turn plays');
      settle();
      expect(host.noWayOut, <String>[RooftopsScript.noWayOut]);
      expect(
        RooftopsScript.noWayOut,
        'Le fiamme ti hanno completamente bloccato, non c’è più via di fuga, '
        'ricomincia dal falò o l’intero livello',
      );

      director.onEvents(<WorldEvent>[
        FireStartedEvent(at: middle.step(Direction.west), entityId: 'z'),
      ]);
      settle();
      expect(host.noWayOut, hasLength(1), reason: 'said once');
    });

    test('a game saved already shut in ends as soon as it is loaded', () {
      standAt(middle);
      burnAround(middle);
      director.restore(director.toJson());
      settle();
      expect(host.noWayOut, <String>[RooftopsScript.noWayOut]);
    });

    test('nothing is said while a way out is left, or once Mario is dead', () {
      standAt(middle);
      world.map.setTile(middle.step(Direction.east), const Tile(TileKind.fire));
      director.onEvents(<WorldEvent>[
        FireStartedEvent(at: middle.step(Direction.east), entityId: 'z'),
      ]);
      settle();
      expect(host.noWayOut, isEmpty);

      burnAround(middle);
      world.player.component<HealthComponent>().current = 0;
      director.onEvents(<WorldEvent>[
        FireStartedEvent(at: middle.step(Direction.west), entityId: 'z'),
      ]);
      settle();
      expect(host.noWayOut, isEmpty);
    });
  });
}
