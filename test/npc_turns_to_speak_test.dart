import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/test_scenarios.dart';

void main() {
  test('someone spoken to turns along whichever axis the listener lies '
      'further off, sideways when it is a draw, and not at all on their '
      'own tile', () {
    final npc = NpcComponent(
      asset: NpcComponent.luigiAsset,
      tile: const GridPoint(5, 5),
      facing: Direction.north,
    );
    expect(npc.tile, const GridPoint(5, 5));
    npc.turnTowards(const GridPoint(5, 8));
    expect(npc.facing, Direction.south);
    npc.turnTowards(const GridPoint(2, 5));
    expect(npc.facing, Direction.west);
    npc.turnTowards(const GridPoint(7, 4));
    expect(npc.facing, Direction.east);
    npc.turnTowards(const GridPoint(6, 2));
    expect(npc.facing, Direction.north);
    npc.turnTowards(const GridPoint(3, 3));
    expect(npc.facing, Direction.west, reason: 'a draw turns them sideways');
    npc.turnTowards(const GridPoint(5, 5));
    expect(npc.facing, Direction.west, reason: 'nowhere to turn');
  });

  testWidgets('a line of Tonino or Marcello turns the one speaking to '
      'Mario, wherever he stands, and leaves the other as he was', (tester) {
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
          'maranza': <String, Object?>{'met': true, 'paid': true},
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
      game.update(1 / 30);

      final npcs = game.world.children.whereType<NpcComponent>();
      final tonino = npcs.singleWhere(
        (npc) => npc.asset == NpcComponent.maranzaRomaAsset,
      );
      final marcello = npcs.singleWhere(
        (npc) => npc.asset == NpcComponent.maranzaLazioAsset,
      );
      expect(tonino.name, MaranzaScript.tonino);
      expect(marcello.name, MaranzaScript.marcello);
      expect(tonino.facing, Direction.north);
      expect(marcello.facing, Direction.north);

      final mario = game.simulation.player.component<PositionComponent>()
        ..position = toninoTile.step(Direction.east);
      game.showPrompt(const <StoryLine>[
        StoryLine('Aò', speaker: MaranzaScript.tonino),
      ]);
      expect(tonino.facing, Direction.east);
      expect(marcello.facing, Direction.north, reason: 'not his line');
      game.dismissPrompt();

      // Mario's own lines turn nobody back.
      mario.position = toninoTile.step(Direction.south);
      game.showPrompt(const <StoryLine>[StoryLine.mario('Ciao')]);
      expect(tonino.facing, Direction.east);
      game.dismissPrompt();

      // A scene's frames count the same as a prompt's lines.
      mario.position = marcelloTile.step(Direction.south);
      game.playCutscene(const <CutsceneFrame>[
        CutsceneFrame(
          image: MaranzaScript.meetScene,
          speaker: MaranzaScript.marcello,
          text: 'Bella',
        ),
      ]);
      expect(marcello.facing, Direction.south);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
