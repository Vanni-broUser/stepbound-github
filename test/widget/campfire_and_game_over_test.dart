import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('a fatal bite shows the game over overlay and restart works', (
    tester,
  ) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, audio: audio, saves: saves);

      final player = game.simulation.player;
      expect(
        player.component<HealthComponent>().maximum,
        1,
        reason: 'a single zombie bite must be fatal',
      );
      player.component<HealthComponent>().current = 1;
      final playerPosition = player.component<PositionComponent>().position;
      final zombie = game.simulation.entities.values.firstWhere(
        (entity) => entity.kind != EntityKind.player,
      );
      zombie.component<PositionComponent>()
        ..position = playerPosition.step(Direction.east)
        ..facing = Direction.west;
      zombie.component<ActorComponent>().energy =
          zombie.component<ActorComponent>().tickCost - 1;

      game.input.pressWait();
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.component<HealthComponent>().current, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(game.cover.value, isA<GameOverCover>());
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsOneWidget,
      );

      expect(audio.played, contains(Sfx.gameOver));
      expect(audio.stopped, isEmpty);

      expect(
        find.text('RICOMINCIA IL LIVELLO (60)'),
        findsOneWidget,
        reason: 'no fire found yet: the level from the start is the only way',
      );
      expect(
        find.byKey(const ValueKey<String>('game-over-restart')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('restart-button')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsNothing,
      );
      expect(
        audio.stopped,
        contains(Sfx.gameOver),
        reason: 'the sting is cut: it must not play on over the new game',
      );
      expect(find.byKey(const ValueKey<String>('story-intro')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('story-skip')),
        findsOneWidget,
        reason: 'the opening was already watched before Mario died',
      );
      expect(
        Progress.fromJson((await saves.load(1))!.progress).memories,
        isEmpty,
        reason: 'a level-start write is not a campfire or train save',
      );

      await tester.tap(find.byKey(const ValueKey<String>('story-skip')));
      await tester.pump();
      await pumpBlackFade(tester);
      await waitForGame(tester);
      expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
    });
  });

  testWidgets('dying with a campfire behind him offers the fire first and '
      'the level second', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Dietro la caserma',
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact'],
        ),
      );
      await tester.pumpWidget(StepboundApp(saves: saves, audio: SilentAudio()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      await waitForGame(tester);
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;

      game.cover.value = const GameOverCover();
      await tester.pump();

      expect(
        find.text('RIPRENDI DAL FALÒ (60)'),
        findsOneWidget,
        reason: 'the fire is the first choice and the one the clock takes',
      );
      expect(find.text('RICOMINCIA IL LIVELLO'), findsOneWidget);

      // Starting over here throws the fire away, so it asks.
      await tester.tap(find.byKey(const ValueKey<String>('game-over-restart')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-cost')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('game-over-restart-cancel')),
      );
      await tester.pump();
      expect(find.text('RICOMINCIA IL LIVELLO'), findsOneWidget);
      expect((await saves.load(1))!.place, 'Dietro la caserma');

      await tester.tap(find.byKey(const ValueKey<String>('game-over-restart')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('game-over-restart-confirm')),
      );
      await tester.pump();
      await tester.pump();

      final saved = (await saves.load(1))!;
      expect(saved.place, 'Inizio del livello');
      expect(saved.atCampfire, isFalse);
    });
  });

  testWidgets('resting at a campfire saves at once and just says so, with '
      'no menu', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      // Teleported to the camp: its lessons count as given already.
      game.story.restore(const <String, Object?>{
        'north': <String, Object?>{'campLesson': true},
        'backpacks': <String, Object?>{'lesson': true},
        'street': <String, Object?>{'zombieLesson': true},
      });
      final camp = game.simulation.campfires.firstWhere(
        place(PlaceId.northDistrict).bounds.contains,
      );
      game.simulation.player.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      game
        ..unlock(HudElement.interact)
        ..input.pressInteract();
      for (var i = 0; i < 60; i++) {
        game.update(1 / 20);
      }
      await tester.pump();
      final saved = (await saves.load(1))!;
      expect(saved.place, 'Dietro la caserma');
      expect(saved.atCampfire, isTrue);
      final prompt = game.cover.value! as PromptCover;
      expect(prompt.lines.single.text, 'Salvataggio completato');
      expect(prompt.lines.single.speaker, isNull);
      await tester.pump();
      expect(find.text('Salvataggio completato'), findsOneWidget);
      for (final gone in <String>['SALVA IL GIOCO', 'TIPI DI ZOMBI']) {
        expect(find.text(gone), findsNothing, reason: 'the fire has no menu');
      }
      expect(find.byKey(const ValueKey<String>('touch-move')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(game.inputLocked, isFalse);
      expect(find.byKey(const ValueKey<String>('touch-move')), findsOneWidget);
      game
        ..input.pressDirection(Direction.west)
        ..update(1 / 20);
      expect(
        game.simulation.player.component<PositionComponent>().position,
        isNot(camp.step(Direction.west)),
        reason: 'Mario is up again once the line is gone',
      );
    });
  });

  testWidgets('the table laid with food above the map table saves aboard '
      'the train', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      final table = trainFoodTiles[1];
      final train = place(PlaceId.trainInterior);
      expect(train.bounds.contains(table), isTrue);
      expect(
        trainFoodTiles.map((tile) => tile.y).toSet(),
        <int>{train.origin.y + 1},
        reason: 'one row, against the top wall',
      );
      expect(
        trainMapTiles.map((tile) => tile.x),
        containsAll(trainFoodTiles.map((tile) => tile.x)),
        reason: 'right above the map table',
      );
      expect(game.simulation.campfires, containsAll(trainFoodTiles));
      game.simulation.player.component<PositionComponent>()
        ..position = table.step(Direction.south)
        ..facing = Direction.north;
      game
        ..unlock(HudElement.interact)
        ..input.pressInteract();
      for (var i = 0; i < 60; i++) {
        game.update(1 / 20);
      }
      await tester.pump();
      final saved = (await saves.load(1))!;
      expect(saved.place, trainPlaceName);
      expect(saved.atCampfire, isTrue);
      expect(
        (game.cover.value! as PromptCover).lines.single.text,
        StepboundGame.savedLine,
      );
      // It saves like a fire, but is not one of the fires to find.
      expect(game.progress.litCampfires, isNot(contains(trainPlaceName)));
      for (final level in LevelId.values) {
        expect(levelCampfires(level), isNot(contains(trainPlaceName)));
      }
    });
  });

  testWidgets('a save that cannot be written at a campfire says so, lets '
      'Mario up and can be tried again at the fire', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final shared = <String>[];
      final game = await pumpReadyGame(
        tester,
        saves: saves,
        share: (name, text) async => shared.add(text),
      );
      game.story.restore(const <String, Object?>{
        'north': <String, Object?>{'campLesson': true},
        'backpacks': <String, Object?>{'lesson': true},
        'street': <String, Object?>{'zombieLesson': true},
      });
      final camp = game.simulation.campfires.firstWhere(
        place(PlaceId.northDistrict).bounds.contains,
      );
      game.simulation.player.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      Future<void> rest() async {
        game.input.pressInteract();
        for (var i = 0; i < 60; i++) {
          game.update(1 / 20);
        }
        // The write happens off the frame loop.
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }

      saves.failWrites = true;
      game.unlock(HudElement.interact);
      await rest();
      final notice = game.cover.value! as SaveFailedCover;
      expect(notice.line, StepboundGame.saveFailedLine);
      expect(find.text(StepboundGame.saveFailedLine), findsOneWidget);
      expect(await saves.load(1), isNull, reason: 'nothing was written');
      // The report of the failed save can be sent from here.
      await tester.tap(find.byKey(const ValueKey<String>('save-failed-share')));
      await untilShared(tester, shared);
      expect(shared, hasLength(1));
      expect(shared.single, contains('== Errore (salvataggio: '));
      expect(shared.single, contains('storage full'));
      expect(shared.single, contains('== Partita ==\nslot: 1\nfase: playing'));
      await tester.tap(
        find.byKey(const ValueKey<String>('save-failed-continue')),
      );
      await tester.pump();
      expect(game.cover.value, isNull);
      // Not stuck kneeling: the pause menu opens, as it does not while
      // Mario is saving.
      game.openMenu();
      expect(game.cover.value, isA<PauseCover>());
      game.closeMenu();

      saves.failWrites = false;
      await rest();
      expect(
        (game.cover.value! as PromptCover).lines.single.text,
        StepboundGame.savedLine,
      );
      expect((await saves.load(1))!.place, 'Dietro la caserma');
    });
  });
}
