import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/missions.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/level_map.dart';
import 'package:stepbound/ui/loading_art.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('aboard, the books open the zombie types, and the memories '
      'played from the figures go back to them', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      game.progress.confirmPendingMemories();
      game.openZombieBook();
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('zombie-book')), findsOneWidget);
      expect(find.text('VAGANTE'), findsNothing, reason: 'none met yet');
      await tester.tap(find.byKey(const ValueKey<String>('zombie-book-close')));
      await tester.pump();
      expect(game.cover.value, isNull);

      game.replayMemories(LevelId.hometown);
      await tester.pump();
      expect(game.soundscapePaused, isTrue, reason: "the story's sound");
      final story = tester.widget<StoryIntro>(
        find.byKey(const ValueKey<String>('train-memories-story')),
      );
      expect(story.scenes.length, introScenes.length + outbreakScenes.length);
      await tester.tap(find.byKey(const ValueKey<String>('story-exit')));
      await tester.pump();
      expect(
        game.cover.value,
        isA<AdventureStatsCover>().having(
          (cover) => cover.level,
          'level',
          LevelId.hometown,
        ),
        reason: 'back to the city the memories were played from',
      );
      expect(game.soundscapePaused, isFalse, reason: "the game's is back");
    });
  });

  testWidgets('a train save that cannot be written is said on the results, '
      'and the level still ends', (tester) {
    return tester.runAsync(() async {
      final shared = <String>[];
      final game = await pumpReadyGame(
        tester,
        saves: ReadOnlyRepository(),
        share: (name, text) async => shared.add(text),
      );
      game.completeLevel();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsOneWidget,
      );
      expect(find.text(LevelComplete.saveFailedLine), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('level-complete-share')),
      );
      await untilShared(tester, shared);
      expect(shared, hasLength(1));
      expect(shared.single, contains('== Errore (salvataggio: Treno) =='));
      expect(shared.single, contains('disk full'));
    });
  });

  testWidgets('level completion saves aboard the train, opens the Europe '
      'map, and Città natale resumes at the map in the train, loading on '
      'the harbour', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      // Where the station's scene leaves him, after a walk and a rest.
      game.simulation.player.component<PositionComponent>()
        ..position = trainMapStandTile
        ..facing = trainMapFacing;
      game.progress
        ..remember(StoryMemory.luigiAtStation)
        ..countStep()
        ..countStep()
        ..countStep()
        ..lightCampfire('Zona nord')
        ..meet(EntityKind.wanderer);
      game.simulation.player.component<AmmoComponent>()
        ..loaded = 2
        ..hasGun = true;
      game.simulation.entities[tutorialZombieId]!
              .component<HealthComponent>()
              .current =
          0;

      game.completeLevel();
      await tester.pump();
      // Black from the scene's end to the results: the world never shows
      // while the save is written.
      expect(game.cover.value, isA<LevelEndCover>());
      expect(
        find.byKey(const ValueKey<String>('level-end-black')),
        findsOneWidget,
      );
      final saved = (await saves.load(1))!;
      // The results come once the train's save is written.
      await tester.pump();
      expect(saved.place, 'Treno', reason: 'the label in the save slots');
      expect(saved.atCampfire, isTrue, reason: 'it can be resumed from');
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsOneWidget,
      );
      expect(find.text('ZAINI TROVATI'), findsOneWidget);
      expect(find.text(LevelComplete.saveFailedLine), findsNothing);
      expect(find.text('RICORDI VISSUTI'), findsOneWidget);
      expect(find.text('ZOMBI CONOSCIUTI'), findsOneWidget);
      expect(find.text('TIPI DI ZOMBI CONOSCIUTI'), findsNothing);
      String stat(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Text),
            ),
          )
          .last
          .data!;
      final zombies = levelZombieKinds(LevelId.hometown);
      // Among them the two rounds at the end of the dead-end street.
      expect(stat('backpack-stat'), '0 / 20');
      expect(stat('kill-stat'), '1 / ${zombies.length}');
      expect(stat('zombie-kind-stat'), '1 / ${zombies.toSet().length}');
      expect(stat('campfire-stat'), '1 / 6');
      expect(stat('step-stat'), '3');

      await tester.tap(
        find.byKey(const ValueKey<String>('level-complete-continue')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('level-map')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('level-city-north-cape')),
      );
      await tester.pump();
      expect(find.text('Capo Nord'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('level-start')),
        findsNothing,
        reason: 'Capo Nord is visible but has no playable level yet',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('level-city-hometown')),
      );
      await tester.pump();
      expect(find.text('Città natale'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('level-start')));
      await tester.pump();
      final returned = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      await returned.ready();
      final mario = returned.simulation.player.component<PositionComponent>();
      expect(
        mario.position,
        trainMapStandTile,
        reason: 'back home in the train, in front of the map',
      );
      expect(mario.facing, trainArrivalFacing, reason: 'away from the map');
      final cover = tester.widget<LoadingCover>(find.byType(LoadingCover));
      expect(cover.image, LevelMap.hometownImage);
      expect(cover.caption, 'Città natale');
      final ammo = returned.simulation.player.component<AmmoComponent>();
      expect(ammo.loaded, arrivalRounds, reason: 'two made up to five');
      expect(ammo.hasGun, isTrue, reason: 'the pistol travels with him');

      // Before Mario can move, what the train carries between levels.
      await waitForGame(tester);
      expect(returned.story.holdsInput, isTrue);
      for (var i = 0; i < 30 && !returned.isPromptVisible; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(JourneyScript.carryLines.first.text), findsOneWidget);
      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      await tester.tap(dialogue);
      await tester.pump();
      expect(find.text(JourneyScript.carryLines.last.text), findsOneWidget);
      await tester.tap(dialogue);
      await tester.pump();
      expect(returned.isPromptVisible, isFalse);

      returned.cover.value = const GameOverCover();
      await tester.pump();
      expect(
        find.text('RIPRENDI DAL TRENO (60)'),
        findsOneWidget,
        reason: 'the last save was made on the train',
      );
    });
  });

  testWidgets('Rome plays its story, then loads at the map in the train '
      'parked at Termini, where Luigi speaks before Mario can move, and '
      'starts over from there', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final audio = SilentAudio();
      final game = await pumpReadyGame(tester, saves: saves, audio: audio);
      // Where the station's scene leaves him.
      game.simulation.player.component<PositionComponent>()
        ..position = trainMapStandTile
        ..facing = trainMapFacing;
      game.simulation.player.component<AmmoComponent>().loaded = 12;
      game.completeLevel();
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('level-complete-continue')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('level-city-rome')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('level-start')));
      await tester.pump();

      final story = find.byKey(const ValueKey<String>('rome-story'));
      expect(story, findsOneWidget);
      expect(audio.music, Music.rome, reason: "the city's story, its music");
      // A tap for each new picture, one for each line.
      final pictures = romeScenes.map((scene) => scene.image).toSet().length;
      for (var i = 0; i < pictures + romeScenes.length; i++) {
        await tester.tap(story);
        await tester.pump();
      }
      await pumpBlackFade(tester);
      await waitForGame(tester);

      final cover = tester.widget<LoadingCover>(find.byType(LoadingCover));
      expect(cover.image, LevelMap.romeImage);
      expect(cover.caption, 'Roma');
      final rome = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      expect(rome.progress.level, LevelId.rome);
      expect(rome.progress.memories, contains(StoryMemory.presidentFled));
      final mario = rome.simulation.player.component<PositionComponent>();
      expect(mario.position, trainMapStandTile);
      expect(
        rome.simulation.portals[trainExitTile]!.to,
        terminiTrainDoorTile.step(Direction.south),
        reason: 'the train door opens onto Termini',
      );
      final saved = (await saves.load(1))!;
      expect(saved.place, 'Treno');

      // Luigi speaks as soon as the city has loaded, before Mario can go.
      expect(rome.story.holdsInput, isTrue);
      for (var i = 0; i < 30 && !rome.isPromptVisible; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(RomeScript.arrivalLines.first.text), findsOneWidget);
      expect(
        rome.simulation.player.component<AmmoComponent>().loaded,
        arrivalRounds,
        reason: 'the twelve rounds stayed in Molfetta',
      );
      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      for (var i = 0; i < RomeScript.arrivalLines.length; i++) {
        await tester.tap(dialogue);
        await tester.pump();
      }

      // Then, after Luigi, what the train carries between levels.
      expect(rome.story.holdsInput, isTrue);
      for (var i = 0; i < 30 && !rome.isPromptVisible; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(JourneyScript.carryLines.first.text), findsOneWidget);
      for (var i = 0; i < JourneyScript.carryLines.length; i++) {
        await tester.tap(dialogue);
        await tester.pump();
      }
      expect(rome.isPromptVisible, isFalse);

      rome.openMenu();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('pause-restart')));
      await tester.pump();
      expect(find.textContaining('arrivo in città'), findsOneWidget);
      rome.closeMenu();
      await tester.pump();
    });
  });

  testWidgets('the hook picked up in Rome and taken home by train hands out '
      'the terraces in the corner, and the figures counted them all along', (
    tester,
  ) {
    return tester.runAsync(() async {
      final session = GameSession(
        saves: MemorySaveRepository(),
        audio: SilentAudio(),
        onLevelCompleted: (_, {required saved}) {},
        onTravelMapRequested: (_) {},
      );
      Future<StepboundGame> play(StepboundGame game) async {
        await tester.pumpWidget(
          GameWidget<StepboundGame>(game: game, key: UniqueKey()),
        );
        final state = tester.state<GameWidgetState<StepboundGame>>(
          find.byType(GameWidget<StepboundGame>),
        );
        await state.loaderFuture;
        await game.ready();
        game.update(1 / 60);
        return game;
      }

      const terraces = Mission.exploreTerraces;
      final rome = await play(session.gameFrom(vanniDeployScenario.save(1)));
      int counted(StepboundGame game) => LevelStats.of(
        game.simulation,
        game.progress,
        LevelId.hometown,
      ).missions.where((mission) => mission == terraces).length;
      expect(counted(rome), 1, reason: 'counted before it is handed out');
      expect(rome.progress.missions.isOpen(terraces), isFalse);

      final mario = rome.simulation.player.component<PositionComponent>()
        ..position = grapplingHookTile.step(Direction.west)
        ..facing = Direction.east;
      const TurnScheduler().advance(rome.simulation, const InteractAction());
      expect(
        rome.simulation.player.component<AmmoComponent>().grapplingHook,
        isTrue,
      );
      rome.update(1 / 60);
      expect(
        rome.progress.missions.isOpen(terraces),
        isFalse,
        reason: 'not in Rome',
      );
      expect(mario.position, grapplingHookTile.step(Direction.west));

      final home = await play(
        session.startLevel(LevelId.hometown, rome.snapshot(place: 'Terme')),
      );
      expect(home.progress.missions.isOpen(terraces), isTrue);
      expect(
        home.missions.value,
        contains((mission: terraces, done: false)),
        reason: 'in the corner as soon as the train is home',
      );
      expect(counted(home), 1);
    });
  });

  testWidgets('a game loaded from the train offers the train back', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final world = createGameWorld();
      world.player.component<PositionComponent>().position = trainMapStandTile;
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Treno',
          world: saveGameWorld(world),
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
      final game =
          tester
              .state<GameWidgetState<StepboundGame>>(
                find.byType(GameWidget<StepboundGame>),
              )
              .currentGame
            ..openMenu();
      await tester.pump();
      expect(find.text('RIPRENDI DAL TRENO'), findsOneWidget);
      expect(find.text('RIPRENDI DAL FALÒ'), findsNothing);
      game
        ..closeMenu()
        ..cover.value = const GameOverCover();
      await tester.pump();
      expect(find.text('RIPRENDI DAL TRENO (60)'), findsOneWidget);
    });
  });

  testWidgets('the locomotive map returns directly to destination selection', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);

      game.openTravelMap();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('level-map')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsNothing,
      );
    });
  });
}
