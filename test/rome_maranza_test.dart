import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/test_scenarios.dart';

void main() {
  testWidgets('Tonino and Marcello stand in the way, and a step at them '
      'walks Mario back up Via Cavour before he has the controls again', (
    tester,
  ) {
    return tester.runAsync(() async {
      final save = testScenarios
          .singleWhere(
            (scenario) => scenario.name == 'Roma, Piazza dei Cinquecento',
          )
          .save(1);
      final game = StepboundGame(
        world: restoreGameWorld(save.world),
        storyState: <String, Object?>{
          ...save.story,
          'maranza': <String, Object?>{'met': true},
        },
        progress: Progress.fromJson(save.progress),
        unlocked: <HudElement>{
          for (final name in save.hud) HudElement.values.byName(name),
        },
      );
      await tester.pumpWidget(GameWidget<StepboundGame>(game: game));
      final state = tester.state<GameWidgetState<StepboundGame>>(
        find.byType(GameWidget<StepboundGame>),
      );
      await state.loaderFuture;
      await game.ready();
      void run(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      run(1);
      for (final tile in <GridPoint>[marcelloTile, toninoTile]) {
        expect(game.simulation.map.tileAt(tile).isWalkable, isFalse);
      }

      final mario = game.simulation.player.component<PositionComponent>();
      final near = GridPoint(marcelloTile.x, marcelloTile.y - 2);
      mario
        ..position = near
        ..facing = Direction.south;
      run(1);
      final prompt = game.cover.value;
      expect(prompt, isA<PromptCover>());
      expect(
        (prompt! as PromptCover).lines.single.speaker,
        MaranzaScript.tonino,
      );

      game
        ..dismissPrompt()
        ..update(1 / 30);
      expect(game.freeToMove.value, isFalse, reason: 'still walking back');
      run(1);
      expect(mario.position, near.step(Direction.north));
      expect(mario.facing, Direction.north);
      expect(game.cover.value, isNull);
      expect(game.freeToMove.value, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
