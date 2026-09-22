import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/title_splash.dart';

/// Opens the app on the main menu and starts a new game in slot 1.
Future<SaveRepository> _startNewGame(
  WidgetTester tester, {
  SaveRepository? saves,
}) async {
  final repository = saves ?? MemorySaveRepository();
  await tester.pumpWidget(StepboundApp(saves: repository));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
  await tester.pump();
  await tester.pump();
  return repository;
}

/// Two taps per scene (image, then text) across the three intro scenes.
const int _introTapCount = 6;

/// Waits for the game to load, as the opening dialogue only shows then.
/// Image decoding needs real time: call it from inside `tester.runAsync`.
Future<void> _waitForGame(WidgetTester tester) async {
  final state = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await state.loaderFuture;
  await state.currentGame.ready();
  await tester.pump();
}

/// From inside `tester.runAsync`, like everything that loads the game.
Future<void> _pumpAppThroughIntro(WidgetTester tester) async {
  await _startNewGame(tester);
  final intro = find.byKey(const ValueKey<String>('story-intro'));
  for (var i = 0; i < _introTapCount; i++) {
    await tester.tap(intro);
    await tester.pump();
  }
  await tester.pump();
  await tester.pump(TitleSplash.total + const Duration(milliseconds: 50));
  await tester.pump();
  await _tapThroughOutbreak(tester);
  await _waitForGame(tester);
  final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
  for (var i = 0; i < tutorialOpening.length; i++) {
    await tester.tap(dialogue);
    await tester.pump();
  }
}

/// Two taps per scene (image, then text) across the post-title scenes.
Future<void> _tapThroughOutbreak(WidgetTester tester) async {
  final story = find.byKey(const ValueKey<String>('story-intro'));
  for (var i = 0; i < outbreakScenes.length * 2; i++) {
    await tester.tap(story);
    await tester.pump();
  }
  await _pumpBlackFade(tester);
}

/// Lets a [BlackFade] started by the last pump run to completion.
Future<void> _pumpBlackFade(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(
    BlackFade.defaultDuration + const Duration(milliseconds: 50),
  );
  await tester.pump();
}

/// Only from inside `tester.runAsync`.
Future<StepboundGame> _pumpReadyGame(WidgetTester tester) async {
  await _pumpAppThroughIntro(tester);
  final gameState = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await gameState.loaderFuture;
  final game = gameState.currentGame;
  await game.ready();
  return game;
}

void main() {
  testWidgets('F2 mounts the Flame game surface', (tester) {
    return tester.runAsync(() async {
      await _pumpAppThroughIntro(tester);
      expect(
        find.byKey(const ValueKey<String>('stepbound-game-surface')),
        findsOneWidget,
      );
      expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
      for (final key in <String>[
        'touch-up',
        'touch-right',
        'touch-down',
        'touch-left',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
      // The tutorial starts with the arrows only.
      for (final key in <String>[
        'touch-shoot',
        'touch-interact',
        'touch-ammo',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      }
    });
  });

  testWidgets('intro scenes reveal text on tap, then advance to the next', (
    tester,
  ) async {
    await _startNewGame(tester);
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
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    expect(find.byKey(const ValueKey<String>('title-splash')), findsOneWidget);
  });

  testWidgets('title card fades in and out, the outbreak scenes play, then the '
      'protagonist speaks before the controls appear', (tester) {
    return tester.runAsync(() async {
      await _startNewGame(tester);
      final intro = find.byKey(const ValueKey<String>('story-intro'));
      for (var i = 0; i < _introTapCount; i++) {
        await tester.tap(intro);
        await tester.pump();
      }
      final fade = find.descendant(
        of: find.byKey(const ValueKey<String>('title-splash')),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
      await tester.pump();
      await tester.pump(TitleSplash.fade + TitleSplash.hold ~/ 2);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);

      await tester.pump(TitleSplash.total + const Duration(milliseconds: 50));
      await tester.pump();
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
      await _pumpBlackFade(tester);
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
      await _waitForGame(tester);
      expect(find.byKey(const ValueKey<String>('touch-shoot')), findsNothing);
      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text(tutorialOpening.first.text), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dialogue-portrait-0')),
        findsOneWidget,
      );

      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      for (var i = 0; i < tutorialOpening.length; i++) {
        await tester.tap(dialogue);
        await tester.pump();
      }
      expect(dialogue, findsNothing);
      expect(find.byKey(const ValueKey<String>('touch-up')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('touch-shoot')), findsNothing);
    });
  });

  testWidgets('tapping the title card skips to its fade out', (tester) async {
    await _startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    for (var i = 0; i < _introTapCount; i++) {
      await tester.tap(intro);
      await tester.pump();
    }
    await tester.pump();
    await tester.pump(TitleSplash.fade);
    await tester.tap(find.byKey(const ValueKey<String>('title-splash')));
    await tester.pump();
    await tester.pump(TitleSplash.fade + const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('title-splash')), findsNothing);
  });

  testWidgets('camera starts clamped around the player', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      // The player starts near the south-west corner of the tutorial street,
      // so both axes sit on a clamp: x at half the view width, y at the
      // map height (52 tiles) minus half the view height.
      expect(game.camera.viewfinder.position.x, 192);
      expect(game.camera.viewfinder.position.y, 52 * 16 - 108);
    });
  });

  testWidgets('shoot button cannot aim when the magazine is empty', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);

      void setLoadedRounds(int value) =>
          game.simulation.player.component<AmmoComponent>().loaded = value;

      game.simulation.player.component<AmmoComponent>().hasGun = true;
      game.unlock(HudElement.shoot);

      setLoadedRounds(0);
      game.pressShoot();
      expect(game.aiming.value, isFalse);

      setLoadedRounds(1);
      game.pressShoot();
      expect(game.aiming.value, isTrue);
    });
  });

  testWidgets('a fatal bite shows the game over overlay and restart works', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);

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

      game.pressWait();
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.component<HealthComponent>().current, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(game.gameOver.value, isTrue);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('restart-button')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsNothing,
      );
    });
  });

  testWidgets('walking into the barracks holds Mario still for a moment', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final position = game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 17)
        ..facing = Direction.north;
      void stepNorth() => game
        ..pressDirection(Direction.north)
        ..releaseDirection(Direction.north)
        ..update(0.3);

      stepNorth();
      final inside = position.position;
      expect(levelRegions.last.bounds.contains(inside), isTrue);

      stepNorth();
      expect(position.position, inside, reason: 'still on the threshold');

      game.update(StepboundGame.entranceHoldSeconds);
      stepNorth();
      expect(position.position, inside.step(Direction.north));
    });
  });

  testWidgets('the harbour stays unseen until its card has gone black', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final road = GridPoint(
        northDistrictOrigin.x + northDistrictRows.last.indexOf('|'),
        northDistrictOrigin.y + northDistrictRows.length - 2,
      );
      game.simulation.player.component<PositionComponent>()
        ..position = road
        ..facing = Direction.south;
      game.update(1);
      final north = levelRegions[1].bounds;
      final harbour = levelRegions.firstWhere(
        (region) => region.name == harbourName,
      );
      bool cameraIn(GridRect bounds) {
        final at = game.camera.viewfinder.position;
        return bounds.contains(
          GridPoint((at.x / 16).floor(), (at.y / 16).floor()),
        );
      }

      game
        ..pressDirection(Direction.south)
        ..releaseDirection(Direction.south);
      for (var i = 0; i < 30; i++) {
        game.update(1 / 30);
      }
      expect(game.locationCard.value?.name, harbourName);
      expect(
        harbour.bounds.contains(
          game.simulation.player.component<PositionComponent>().position,
        ),
        isTrue,
      );
      expect(cameraIn(north), isTrue, reason: 'still fading to black');

      game
        ..locationCardBlack()
        ..update(1 / 30);
      expect(cameraIn(harbour.bounds), isTrue);
    });
  });

  testWidgets('resting at a campfire opens the camp menu, without saving on '
      'its own', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      // Teleported to the camp: its lessons count as given already.
      game.tutorial.restore(const <String, Object?>{
        'campLesson': true,
        'backpackLesson': true,
        'zombieLesson': true,
      });
      final camp = game.simulation.campfires.single;
      game.simulation.player.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      game
        ..unlock(HudElement.interact)
        ..pressInteract();
      for (var i = 0; i < 60; i++) {
        game.update(1 / 20);
      }
      expect(game.atCamp.value, isTrue);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('camp-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('touch-up')), findsNothing);
      expect(find.text('SALVA IL GIOCO'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('camp-close')));
      await tester.pump();
      expect(game.atCamp.value, isFalse);
      expect(game.inputLocked, isFalse);
      expect(find.byKey(const ValueKey<String>('touch-up')), findsOneWidget);
    });
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
    final world = createStreetWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      30,
    );
    await saves.save(
      SaveGame(
        slot: 3,
        savedAt: DateTime(2026, 9, 21, 17, 5),
        place: 'Accampamento dietro la caserma',
        world: world.toJson(),
        tutorial: const <String, Object?>{'zombieLesson': true},
        hud: const <String>['interact', 'ammo'],
      ),
    );
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();
    expect(find.textContaining('Accampamento dietro la caserma'), findsOne);
    expect(find.textContaining('21/09/2026 17:05'), findsOne);
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-3')));
    await tester.pump();

    expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    expect(find.byKey(const ValueKey<String>('touch-interact')), findsOne);
    expect(find.byKey(const ValueKey<String>('touch-shoot')), findsNothing);
    final game = tester
        .state<GameWidgetState<StepboundGame>>(
          find.byType(GameWidget<StepboundGame>),
        )
        .currentGame;
    expect(
      game.simulation.player.component<PositionComponent>().position,
      const GridPoint(16, 30),
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
        place: 'Accampamento dietro la caserma',
        world: createStreetWorld().toJson(),
        tutorial: const <String, Object?>{},
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

  testWidgets('starting the level over from a camp saves the level start '
      'and plays the story from the first picture', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final world = createStreetWorld();
      world.player.component<AmmoComponent>().loaded = 5;
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Accampamento dietro la caserma',
          world: world.toJson(),
          tutorial: const <String, Object?>{'zombieLesson': true},
          hud: const <String>['interact', 'ammo', 'shoot'],
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
      await _waitForGame(tester);
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      game.atCamp.value = true;
      // By the fire: its crackle, the music hushed.
      audio
        ..setAmbience(Ambience.fire, 0.8)
        ..setMusicLevel(0.2);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('touch-up')), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('camp-restart')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('camp-restart-confirm')),
      );
      // The old game still ticks until it is gone: it must not bring the
      // camp's sound back.
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
      expect(saved.tutorial, isEmpty);
      expect(saved.hud, isEmpty);
      final restored = restoreStreetWorld(saved.world);
      expect(restored.player.component<AmmoComponent>().loaded, 0);
      expect(
        restored.player.component<PositionComponent>().position,
        createStreetWorld().player.component<PositionComponent>().position,
      );
    });
  });

  testWidgets('the controls disappear while a text box is on screen', (
    tester,
  ) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Accampamento dietro la caserma',
        world: createStreetWorld().toJson(),
        tutorial: const <String, Object?>{},
        hud: const <String>['interact', 'ammo', 'shoot'],
      ),
    );
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
    await tester.pump();
    final game = tester
        .state<GameWidgetState<StepboundGame>>(
          find.byType(GameWidget<StepboundGame>),
        )
        .currentGame;
    const controls = <String>[
      'touch-up',
      'touch-shoot',
      'touch-interact',
      'touch-ammo',
    ];
    for (final key in controls) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }

    game.showPrompt(const <TutorialLine>[TutorialLine('Un messaggio')]);
    await tester.pump();
    for (final key in controls) {
      expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
    }

    await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
    await tester.pump();
    for (final key in controls) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
  });
}
