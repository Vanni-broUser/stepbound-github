import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/interact_marker_component.dart';
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
  GameAudio? audio,
}) async {
  final repository = saves ?? MemorySaveRepository();
  await tester.pumpWidget(StepboundApp(saves: repository, audio: audio));
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
Future<void> _pumpAppThroughIntro(
  WidgetTester tester, {
  GameAudio? audio,
  SaveRepository? saves,
}) async {
  await _startNewGame(tester, audio: audio, saves: saves);
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
Future<StepboundGame> _pumpReadyGame(
  WidgetTester tester, {
  GameAudio? audio,
  SaveRepository? saves,
}) async {
  await _pumpAppThroughIntro(tester, audio: audio, saves: saves);
  final gameState = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await gameState.loaderFuture;
  final game = gameState.currentGame;
  await game.ready();
  return game;
}

void main() {
  // Tests tap through the lines without waiting: only the test below cares
  // about the pause that keeps a walking tap from eating them.
  setUp(() => GameplayDialogue.settleTime = Duration.zero);
  tearDown(
    () => GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime,
  );

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
      // map height (42 tiles) minus half the view height.
      expect(game.camera.viewfinder.position.x, 192);
      expect(game.camera.viewfinder.position.y, 42 * 16 - 108);
    });
  });

  testWidgets('shoot button dry fires when empty and aims once loaded', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);

      void setLoadedRounds(int value) =>
          game.simulation.player.component<AmmoComponent>().loaded = value;

      game.simulation.player.component<AmmoComponent>().hasGun = true;
      game.unlock(HudElement.shoot);
      await tester.pump();

      setLoadedRounds(0);
      await tester.tap(find.byKey(const ValueKey<String>('touch-shoot')));
      expect(game.aiming.value, isFalse);
      expect(
        game.presentation.lastEvents.whereType<DryFiredEvent>(),
        hasLength(1),
      );

      setLoadedRounds(1);
      await tester.tap(find.byKey(const ValueKey<String>('touch-shoot')));
      expect(game.aiming.value, isTrue);
    });
  });

  testWidgets('a fatal bite shows the game over overlay and restart works', (
    tester,
  ) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await _pumpReadyGame(tester, audio: audio);

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
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsNothing,
      );
      expect(
        audio.stopped,
        contains(Sfx.gameOver),
        reason: 'the sting is cut: it must not play on over the new game',
      );
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
          world: saveTutorialWorld(createTutorialWorld()),
          tutorial: const <String, Object?>{},
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
      await _waitForGame(tester);
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

  testWidgets('walking into the barracks holds Mario still for a moment', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final position = game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      void stepNorth() => game
        ..pressDirection(Direction.north)
        ..releaseDirection(Direction.north)
        ..update(0.3);

      stepNorth();
      final inside = position.position;
      expect(place(PlaceId.barracks).bounds.contains(inside), isTrue);

      stepNorth();
      expect(position.position, inside, reason: 'still on the threshold');

      game.update(StepboundGame.entranceHoldSeconds);
      stepNorth();
      expect(position.position, inside.step(Direction.north));
    });
  });

  testWidgets('only the place in view is drawn', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      game.update(1 / 30);
      expect(game.drawnPlaces, <String>[place(PlaceId.street).background]);

      game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      game
        ..pressDirection(Direction.north)
        ..releaseDirection(Direction.north)
        ..update(0.3);
      expect(game.drawnPlaces, <String>[place(PlaceId.barracks).background]);
    });
  });

  testWidgets('rescuing Luigi opens both the train tile and its artwork', (
    tester,
  ) {
    return tester.runAsync(() async {
      final world = createTutorialWorld();
      world.player.component<PositionComponent>().position = GridPoint(
        (stationPlatform.left + stationPlatform.right) ~/ 2,
        stationPlatform.bottom,
      );
      final progress = Progress();
      final game = StepboundGame(world: world, progress: progress);
      await tester.pumpWidget(GameWidget<StepboundGame>(game: game));
      final state = tester.state<GameWidgetState<StepboundGame>>(
        find.byType(GameWidget<StepboundGame>),
      );
      await state.loaderFuture;
      await game.ready();
      game.update(1 / 30);

      expect(world.map.tileAt(stationTrainDoorTile).isWalkable, isFalse);
      expect(game.drawnPlaces, <String>['assets/levels/station_far_side.png']);

      progress.remember(StoryMemory.luigiRescued);
      game.update(1 / 30);
      expect(world.map.tileAt(stationTrainDoorTile).isWalkable, isTrue);
      expect(game.drawnPlaces, <String>[
        'assets/levels/station_far_side_open.png',
      ]);
    });
  });

  testWidgets('the gap between the roofs wears the interact symbol, once '
      'the button is there to press', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final marker = game.world.children
          .whereType<InteractMarkerComponent>()
          .single;
      expect(
        marker.position,
        Vector2(
          rooftopGapTile.x * StepboundGame.tileSize,
          rooftopGapTile.y * StepboundGame.tileSize,
        ),
      );
      expect(marker.active(), isFalse, reason: 'no interact button yet');
      game.unlock(HudElement.interact);
      expect(marker.active(), isTrue);
    });
  });

  testWidgets('the harbour stays unseen until its card has gone black', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final road = GridPoint(
        place(PlaceId.northDistrict).origin.x +
            northDistrictRows.last.indexOf('|'),
        place(PlaceId.northDistrict).origin.y + northDistrictRows.length - 2,
      );
      game.simulation.player.component<PositionComponent>()
        ..position = road
        ..facing = Direction.south;
      game.update(1);
      final north = place(PlaceId.northDistrict).bounds;
      final harbour = tutorialPlaces.firstWhere(
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
      expect((game.cover.value! as PlaceCardCover).name, harbourName);
      expect(
        harbour.bounds.contains(
          game.simulation.player.component<PositionComponent>().position,
        ),
        isTrue,
      );
      expect(cameraIn(north), isTrue, reason: 'still fading to black');

      game
        ..placeCardBlack()
        ..update(1 / 30);
      expect(cameraIn(harbour.bounds), isTrue);
    });
  });

  testWidgets('resting at a campfire saves at once and just says so, with '
      'no menu', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, saves: saves);
      // Teleported to the camp: its lessons count as given already.
      game.tutorial.restore(const <String, Object?>{
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
        ..pressInteract();
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
      expect(find.byKey(const ValueKey<String>('touch-up')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(game.inputLocked, isFalse);
      expect(find.byKey(const ValueKey<String>('touch-up')), findsOneWidget);
      game
        ..pressDirection(Direction.west)
        ..update(1 / 20);
      expect(
        game.simulation.player.component<PositionComponent>().position,
        isNot(camp.step(Direction.west)),
        reason: 'Mario is up again once the line is gone',
      );
    });
  });

  testWidgets('a save that cannot be written at a campfire says so, lets '
      'Mario up and can be tried again at the fire', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, saves: saves);
      game.tutorial.restore(const <String, Object?>{
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
        game.pressInteract();
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
      final prompt = game.cover.value! as PromptCover;
      expect(prompt.lines.single.text, StepboundGame.saveFailedLine);
      expect(await saves.load(1), isNull, reason: 'nothing was written');
      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
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

  testWidgets('aboard, the books open the zombie types and the cot plays '
      'the memories', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      game.openZombieBook();
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('zombie-book')), findsOneWidget);
      expect(find.text('VAGANTE'), findsNothing, reason: 'none met yet');
      await tester.tap(find.byKey(const ValueKey<String>('zombie-book-close')));
      await tester.pump();
      expect(game.cover.value, isNull);

      game.replayMemories();
      await tester.pump();
      expect(game.soundscapePaused, isTrue, reason: "the story's sound");
      final story = tester.widget<StoryIntro>(
        find.byKey(const ValueKey<String>('train-memories-story')),
      );
      expect(story.scenes.length, introScenes.length + outbreakScenes.length);
      await tester.tap(find.byKey(const ValueKey<String>('story-exit')));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(game.soundscapePaused, isFalse, reason: "the game's is back");
    });
  });

  testWidgets('a damaged slot says so in the menu and does not load; one '
      'with a good backup loads that, marked as such', (tester) async {
    final saves = MemorySaveRepository();
    SaveGame at(int slot, String place) => SaveGame(
      slot: slot,
      savedAt: DateTime(2026, 9, 21, 17, 5),
      place: place,
      world: saveTutorialWorld(createTutorialWorld()),
      tutorial: const <String, Object?>{},
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
    final world = createTutorialWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      20,
    );
    await saves.save(
      SaveGame(
        slot: 3,
        savedAt: DateTime(2026, 9, 21, 17, 5),
        place: 'Dietro la caserma',
        world: saveTutorialWorld(world),
        tutorial: const <String, Object?>{
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
    expect(find.byKey(const ValueKey<String>('touch-interact')), findsOne);
    expect(find.byKey(const ValueKey<String>('touch-shoot')), findsNothing);
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
        world: saveTutorialWorld(createTutorialWorld()),
        tutorial: const <String, Object?>{},
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
      final world = createTutorialWorld();
      world.player.component<AmmoComponent>().loaded = 5;
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Dietro la caserma',
          world: saveTutorialWorld(world),
          tutorial: const <String, Object?>{
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
      await _waitForGame(tester);
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
        find.byKey(const ValueKey<String>('touch-up')),
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
      expect(saved.tutorial, isEmpty);
      final progress = Progress.fromJson(saved.progress);
      expect(progress.knownZombies, isEmpty, reason: 'it had met a wanderer');
      expect(progress.memories, Progress.newGame().memories);
      expect(saved.hud, isEmpty);
      expect(
        saved.played,
        greaterThanOrEqualTo(const Duration(hours: 2, minutes: 30)),
        reason: 'the hours played are the one thing starting over keeps',
      );
      final restored = restoreTutorialWorld(saved.world);
      expect(restored.player.component<AmmoComponent>().loaded, 0);
      expect(
        restored.player.component<PositionComponent>().position,
        createTutorialWorld().player.component<PositionComponent>().position,
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
          world: saveTutorialWorld(createTutorialWorld()),
          tutorial: const <String, Object?>{},
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
      await _waitForGame(tester);

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

  testWidgets('the controls disappear while a text box is on screen', (
    tester,
  ) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Dietro la caserma',
        world: saveTutorialWorld(createTutorialWorld()),
        tutorial: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
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

  testWidgets('a story line over a picture already seen comes up with the '
      'tap that turns to it', (tester) async {
    const same = 'assets/story/scene_mario_luigi_reunion.jpg';
    var finished = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StoryIntro(
          scenes: const <StoryScene>[
            StoryScene(image: same, text: 'Prima'),
            StoryScene(image: same, text: 'Seconda'),
            StoryScene(image: 'assets/story/scene_harbour.jpg', text: 'Terza'),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    final story = find.byKey(const ValueKey<String>('story-intro'));
    Future<void> tap() async {
      await tester.tap(story);
      await tester.pump();
    }

    // A new picture is worth a look before its line covers it.
    expect(find.text('Prima'), findsNothing);
    await tap();
    expect(find.text('Prima'), findsOneWidget);

    // The second line is spoken over the same picture: one tap, not two.
    await tap();
    expect(find.text('Seconda'), findsOneWidget);

    // The third changes the picture, so that one waits for its own tap.
    await tap();
    expect(find.text('Terza'), findsNothing);
    await tap();
    expect(find.text('Terza'), findsOneWidget);

    await tap();
    expect(finished, isTrue);
  });

  testWidgets('a text box ignores the taps of someone still walking', (tester) {
    return tester.runAsync(() async {
      // The opening lines are tapped through with no pause, as everywhere
      // else; the pause is what this test is about, so it starts here.
      final game = await _pumpReadyGame(tester);
      GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime;
      final lines = <TutorialLine>[
        const TutorialLine('Prima battuta'),
        const TutorialLine('Seconda battuta'),
      ];
      game.showPrompt(lines);
      await tester.pump();
      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      expect(find.text('Prima battuta'), findsOneWidget);

      // The tap that was meant for an arrow button lands on the box.
      await tester.tap(dialogue);
      await tester.pump();
      expect(
        find.text('Prima battuta'),
        findsOneWidget,
        reason: 'the first line was eaten by a walking tap',
      );

      await Future<void>.delayed(GameplayDialogue.defaultSettleTime);
      await tester.pump();
      await tester.tap(dialogue);
      await tester.pump();
      expect(find.text('Seconda battuta'), findsOneWidget);
    });
  });

  testWidgets('level completion saves aboard the train, opens the Europe '
      'map, Rome returns to it, and Città Natale resumes at the map in the '
      'train', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, saves: saves);
      // Where the station's scene leaves him.
      game.simulation.player.component<PositionComponent>()
        ..position = trainMapStandTile
        ..facing = Direction.south;

      game.completeLevel();
      await tester.pump();
      final saved = (await saves.load(1))!;
      expect(saved.place, 'Treno', reason: 'the label in the save slots');
      expect(saved.atCampfire, isTrue, reason: 'it can be resumed from');
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsOneWidget,
      );
      expect(find.text('ZAINI TROVATI'), findsOneWidget);
      expect(find.text('RICORDI TROVATI'), findsOneWidget);

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

      await tester.tap(find.byKey(const ValueKey<String>('level-city-rome')));
      await tester.pump();
      expect(find.text('Roma'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('level-start')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('rome-placeholder')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Vanni deve ancora programmarla questa parte\n'
          'Fagli sapere se ti piace il gioco',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('rome-placeholder')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('level-city-hometown')),
      );
      await tester.pump();
      expect(find.text('Città Natale'), findsOneWidget);
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
      expect(mario.facing, Direction.south);

      returned.cover.value = const GameOverCover();
      await tester.pump();
      expect(
        find.text('RIPRENDI DAL TRENO (60)'),
        findsOneWidget,
        reason: 'the last save was made on the train',
      );
    });
  });

  testWidgets('a game loaded from the train offers the train back', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final world = createTutorialWorld();
      world.player.component<PositionComponent>().position = trainMapStandTile;
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Treno',
          world: saveTutorialWorld(world),
          tutorial: const <String, Object?>{},
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
      await _waitForGame(tester);
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
      final game = await _pumpReadyGame(tester);

      game.openTravelMap();
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('level-map')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsNothing,
      );
    });
  });

  testWidgets('the arrows stay on the left and the actions on the right', (
    tester,
  ) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Dietro la caserma',
        world: saveTutorialWorld(createTutorialWorld()),
        tutorial: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
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

    double centreOf(String key) =>
        tester.getCenter(find.byKey(ValueKey<String>(key))).dx;

    // Like every gamepad since the NES: the thumb that moves is the left one.
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final arrow in <String>['touch-up', 'touch-down', 'touch-left']) {
      expect(centreOf(arrow), lessThan(screen / 2), reason: arrow);
    }
    for (final action in <String>[
      'touch-shoot',
      'touch-interact',
      'touch-ammo',
    ]) {
      expect(centreOf(action), greaterThan(screen / 2), reason: action);
    }
    expect(centreOf('touch-shoot'), greaterThan(centreOf('touch-right')));
    expect(centreOf('touch-interact'), greaterThan(centreOf('touch-right')));
  });
}
