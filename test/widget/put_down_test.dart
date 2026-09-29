import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('putting the app down writes the game as it is, beside the '
      'fire', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      game.simulation.player.component<PositionComponent>().position =
          const GridPoint(16, 20);
      expect(await saves.read(1), isA<EmptySave>());

      // The way out as Android walks it: inactive, hidden, paused.
      <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
      final key = StoredSaveRepository.suspendedKey(1);
      for (var i = 0; i < 20 && !saves.values.containsKey(key); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final read = await saves.read(1);
      expect(read, isA<LoadedSave>());
      expect((read as LoadedSave).suspended, isTrue);
      expect(read.save.atCampfire, isFalse);
      expect(read.save.place, game.placeName);
      expect(
        restoreGameWorld(
          read.save.world,
        ).player.component<PositionComponent>().position,
        const GridPoint(16, 20),
      );
      expect(await saves.load(1), isNull, reason: 'no fire has been rested at');
      <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
    });
  });

  testWidgets('in the middle of a story line, the game is put down as it '
      'last was before it, where it can pick itself up again', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      final position = game.simulation.player.component<PositionComponent>();
      final before = position.position;
      await tester.pump();
      game.showPrompt(const <StoryLine>[StoryLine('Un momento.')]);
      await tester.pump();
      expect(game.canBeSuspended, isFalse);
      // What happens under the line is not what the copy holds.
      position.position = const GridPoint(16, 20);
      await leaveApp(tester);
      final key = StoredSaveRepository.suspendedKey(1);
      for (var i = 0; i < 20 && !saves.values.containsKey(key); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final read = await saves.read(1);
      expect(read, isA<LoadedSave>());
      expect((read as LoadedSave).suspended, isTrue);
      expect(
        restoreGameWorld(
          read.save.world,
        ).player.component<PositionComponent>().position,
        before,
      );
      await backToApp(tester);
    });
  });

  testWidgets('dead, the game is not put down: the way back is the game '
      'over’s', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      await tester.pump();
      final player = game.simulation.player;
      player.component<HealthComponent>().current = 1;
      final zombie = game.simulation.entities.values.firstWhere(
        (entity) => entity.kind != EntityKind.player,
      );
      zombie.component<PositionComponent>()
        ..position = player.component<PositionComponent>().position.step(
          Direction.east,
        )
        ..facing = Direction.west;
      zombie.component<ActorComponent>().energy =
          zombie.component<ActorComponent>().tickCost - 1;
      game.input.pressWait();
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.component<HealthComponent>().current, 0);
      await leaveApp(tester);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        saves.values.containsKey(StoredSaveRepository.suspendedKey(1)),
        isFalse,
      );
      await backToApp(tester);
    });
  });

  testWidgets('a game put down is picked up from the menu as it was, and '
      'the fire behind it is still the one to go back to', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final atFire = createGameWorld();
      atFire.player.component<PositionComponent>().position = const GridPoint(
        16,
        20,
      );
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026, 9, 21, 17),
          place: 'Dietro la caserma',
          world: saveGameWorld(atFire),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact'],
        ),
      );
      final putDown = createGameWorld();
      putDown.player.component<PositionComponent>().position = const GridPoint(
        16,
        24,
      );
      await saves.suspend(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026, 9, 21, 18),
          place: 'Città natale',
          world: saveGameWorld(putDown),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact'],
          atCampfire: false,
        ),
      );
      await tester.pumpWidget(StepboundApp(saves: saves, audio: SilentAudio()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await tester.pump();
      expect(find.textContaining('(in sospeso)'), findsOne);
      expect(find.textContaining('Città natale'), findsOne);
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      await waitForGame(tester);
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      expect(
        game.simulation.player.component<PositionComponent>().position,
        const GridPoint(16, 24),
        reason: 'the game as it was put down',
      );

      game.cover.value = const GameOverCover();
      await tester.pump();
      expect(
        find.text('RIPRENDI DAL FALÒ (60)'),
        findsOneWidget,
        reason: 'the fire of the slot is still there to go back to',
      );
      await tester.tap(find.text('RIPRENDI DAL FALÒ (60)'));
      await tester.pump();
      await waitForGame(tester);
      final resumed = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      expect(
        resumed.simulation.player.component<PositionComponent>().position,
        const GridPoint(16, 20),
      );
      expect(
        (await saves.read(1) as LoadedSave).suspended,
        isFalse,
        reason: 'going back to the fire gives up the game put down',
      );
    });
  });
}
