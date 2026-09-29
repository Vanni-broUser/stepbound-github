import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/level_restart.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('intro scenes reveal text on tap, then advance to the next', (
    tester,
  ) async {
    await startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    expect(intro, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-text')), findsNothing);
    expect(find.byKey(const ValueKey<String>('story-image-0')), findsOneWidget);

    await tester.tap(intro);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-text')), findsOneWidget);
    expect(
      find.text(
        'Attenzione, interrompiamo le comunicazioni per una edizione '
        'straordinaria del telegiornale',
      ),
      findsOneWidget,
    );

    await tester.tap(intro);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-image-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-text')), findsNothing);

    for (var i = 0; i < 4; i++) {
      await tester.tap(intro);
      await tester.pump();
    }
    expect(
      find.byKey(const ValueKey<String>('outbreak-story')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('loading-cover')), findsNothing);
  });

  testWidgets('the outbreak follows the first scenes without an intermediate '
      'loading screen, then gameplay loads once', (tester) {
    return tester.runAsync(() async {
      await startNewGame(tester);
      final intro = find.byKey(const ValueKey<String>('story-intro'));
      for (var i = 0; i < introTapCount; i++) {
        await tester.tap(intro);
        await tester.pump();
      }
      expect(find.byKey(const ValueKey<String>('title-splash')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('outbreak-story')),
        findsOneWidget,
      );
      expect(find.byType(GameWidget<StepboundGame>), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
      await tester.pump();
      expect(find.text(outbreakScenes.first.text), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
      await tester.pump();
      expect(find.text('Hostess'), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
      await tester.pump();
      expect(find.text('Hostess'), findsOneWidget);
      for (var i = 3; i < outbreakScenes.length * 2; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey<String>('story-fade-out')),
        findsOneWidget,
      );
      expect(find.byType(GameWidget<StepboundGame>), findsNothing);
      await pumpBlackFade(tester);
      expect(
        find.byKey(const ValueKey<String>('gameplay-fade-in')),
        findsOneWidget,
      );

      expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
      expect(find.text('Mario Rossi'), findsNothing, reason: 'still loading');
      expect(
        find.byKey(const ValueKey<String>('loading-cover')),
        findsOneWidget,
      );
      await waitForGame(tester);
      expect(find.byKey(const ValueKey<String>('touch-move')), findsNothing);
      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text(tutorialOpening.first.text), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dialogue-portrait-0')),
        findsOneWidget,
      );

      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      final box = tester.getRect(dialogue);
      // On the left, where during play a tap only walks: a line still
      // bleeds there.
      final left = Offset(box.left + box.width * 0.15, box.bottom - 30);
      for (var i = 0; i < tutorialOpening.length; i++) {
        final before = splats(tester).lastOrNull;
        await tester.tapAt(left);
        await tester.pump();
        final splat = splats(tester).last;
        expect(splat, isNot(same(before)), reason: 'line $i left no blood');
        expect(splat.at.dx, lessThan(box.center.dx));
      }
      expect(dialogue, findsNothing);
      expect(find.byKey(const ValueKey<String>('touch-move')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('touch-ammo')), findsNothing);
    });
  });

  testWidgets('every tap that turns the story leaves blood where it was, '
      'on the left of the screen too', (tester) async {
    await startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    final box = tester.getRect(intro);
    final left = Offset(box.left + box.width * 0.2, box.center.dy);
    final right = Offset(box.left + box.width * 0.8, box.center.dy);
    await tester.tapAt(left);
    await tester.pump();
    expect(splats(tester), hasLength(1));
    expect(splats(tester).single.at.dx, lessThan(box.center.dx));
    await tester.tapAt(right);
    await tester.pump();
    expect(splats(tester), hasLength(2));
    expect(splats(tester).last.at.dx, greaterThan(box.center.dx));
  });

  testWidgets('the first three scenes lead straight into the outbreak', (
    tester,
  ) async {
    await startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    for (var i = 0; i < introTapCount; i++) {
      await tester.tap(intro);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey<String>('title-splash')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('outbreak-story')),
      findsOneWidget,
    );
  });

  testWidgets('a damaged slot says so in the menu and does not load; one '
      'with a good backup loads that, marked as such', (tester) async {
    final saves = MemorySaveRepository();
    SaveGame at(int slot, String place) => SaveGame(
      slot: slot,
      savedAt: DateTime(2026, 9, 21, 17, 5),
      place: place,
      world: saveGameWorld(createGameWorld()),
      story: const <String, Object?>{},
      progress: Progress.newGame().toJson(),
      hud: const <String>[],
    );
    await saves.save(at(1, 'Il porto'));
    await saves.save(at(1, 'Dietro la caserma'));
    await saves.save(at(2, 'La stazione'));
    // Both cut short on their way to the disk; only slot 1 had a save
    // before it.
    for (final slot in <int>[1, 2]) {
      saves.values[StoredSaveRepository.slotKey(slot)] = '{"format": 1';
    }
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();

    expect(find.textContaining('danneggiato'), findsOne);
    expect(find.textContaining('Il porto'), findsOne);
    expect(find.textContaining('(riserva)'), findsOne);
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-2')));
    await tester.pump();
    expect(find.byType(GameWidget<StepboundGame>), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
    await tester.pump();
    expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
  });

  testWidgets('the game opens on the main menu with the Stepbound sign', (
    tester,
  ) async {
    await tester.pumpWidget(StepboundApp(saves: MemorySaveRepository()));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('main-menu')), findsOneWidget);
    expect(find.text('NUOVA PARTITA'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    // Nothing saved yet: the load button does nothing.
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('menu-slot-1')), findsNothing);
  });

  testWidgets('a saved slot is resumed straight into the game', (tester) async {
    final saves = MemorySaveRepository();
    final world = createGameWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      20,
    );
    await saves.save(
      SaveGame(
        slot: 3,
        savedAt: DateTime(2026, 9, 21, 17, 5),
        place: 'Dietro la caserma',
        world: saveGameWorld(world),
        story: const <String, Object?>{
          'street': <String, Object?>{'zombieLesson': true},
        },
        progress: Progress(
          knownZombies: <EntityKind>[EntityKind.wanderer],
        ).toJson(),
        hud: const <String>['interact', 'ammo'],
        played: const Duration(hours: 3, minutes: 5),
      ),
    );
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();
    expect(find.textContaining('Dietro la caserma'), findsOne);
    expect(find.textContaining('21/09/2026 17:05'), findsOne);
    expect(
      find.textContaining('3h 05m'),
      findsOne,
      reason: 'the slot says how long that game has been played',
    );
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-3')));
    await tester.pump();

    expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    expect(find.byKey(const ValueKey<String>('touch-act')), findsOne);
    final game = tester
        .state<GameWidgetState<StepboundGame>>(
          find.byType(GameWidget<StepboundGame>),
        )
        .currentGame;
    expect(
      game.simulation.player.component<PositionComponent>().position,
      const GridPoint(16, 20),
    );
  });

  testWidgets('starting over a used slot asks for confirmation first', (
    tester,
  ) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Dietro la caserma',
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
        hud: const <String>[],
      ),
    );
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1-confirm')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-intro')), findsOneWidget);
    expect(await saves.load(1), isNull, reason: 'the old save is wiped');
  });

  testWidgets('starting the level over from the menu saves the level start '
      'and plays the story from the first picture', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final world = createGameWorld();
      world.player.component<AmmoComponent>().loaded = 5;
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Dietro la caserma',
          world: saveGameWorld(world),
          story: const <String, Object?>{
            'street': <String, Object?>{'zombieLesson': true},
          },
          progress: Progress(
            knownZombies: <EntityKind>[EntityKind.wanderer],
          ).toJson(),
          hud: const <String>['interact', 'ammo', 'shoot'],
          played: const Duration(hours: 2, minutes: 30),
        ),
      );
      final audio = SilentAudio();
      await tester.pumpWidget(StepboundApp(saves: saves, audio: audio));
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
      // Something was playing: it must not come back over the story.
      audio
        ..setAmbience(Ambience.fire, 0.8)
        ..setMusicLevel(0.2);
      await tester.tap(find.byKey(const ValueKey<String>('touch-menu')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('touch-move')),
        findsNothing,
        reason: 'the menu takes the place of the gameplay buttons',
      );
      await tester.tap(find.byKey(const ValueKey<String>('pause-restart')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('pause-confirm')));
      // The old game still ticks until it is gone: it must not bring its
      // own sound back.
      game.update(0.1);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('story-image-0')),
        findsOneWidget,
      );
      expect(audio.music, Music.story);
      expect(audio.musicLevel, 1);
      expect(audio.ambience.values.every((volume) => volume == 0), isTrue);
      final saved = (await saves.load(1))!;
      expect(saved.place, 'Inizio del livello');
      expect(
        saved.atCampfire,
        isFalse,
        reason: 'there is no fire to go back to at the start of a level',
      );
      expect(
        saved.story.keys,
        everyElement(isIn(storyScriptCities.keys)),
        reason: 'only the other cities story is kept',
      );
      final progress = Progress.fromJson(saved.progress);
      expect(progress.knownZombies, isEmpty, reason: 'it had met a wanderer');
      expect(progress.memories, isEmpty);
      expect(saved.hud, isEmpty);
      expect(
        saved.played,
        greaterThanOrEqualTo(const Duration(hours: 2, minutes: 30)),
        reason: 'the hours played are the one thing starting over keeps',
      );
      final restored = restoreGameWorld(saved.world);
      expect(restored.player.component<AmmoComponent>().loaded, 0);
      expect(
        restored.player.component<PositionComponent>().position,
        createGameWorld().player.component<PositionComponent>().position,
      );
    });
  });

  testWidgets('starting the level over still happens when the save cannot '
      'be written, and the slot keeps its fire', (tester) {
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
          hud: const <String>[],
        ),
      );
      await tester.pumpWidget(StepboundApp(saves: saves));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      await waitForGame(tester);

      saves.failWrites = true;
      await tester.tap(find.byKey(const ValueKey<String>('touch-menu')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('pause-restart')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('pause-confirm')));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('story-image-0')),
        findsOneWidget,
      );
      expect((await saves.load(1))!.place, 'Dietro la caserma');
    });
  });
}
