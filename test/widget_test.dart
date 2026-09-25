import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/crucified_zombie_component.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_splat.dart';
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

/// The blood splats left on the screen.
List<LiveSplat> _splats(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('blood-splats')),
                )
                .painter!
            as BloodSplatPainter)
        .splats;

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
      for (final key in <String>['touch-move', 'touch-act']) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
      // The tutorial starts with walking only: nothing on the HUD.
      expect(find.byKey(const ValueKey<String>('touch-ammo')), findsNothing);
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      expect(game.hud.value, isEmpty);
    });
  });

  testWidgets('quest inventory badges show their item name when tapped', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester)
        ..unlock(HudElement.incense)
        ..unlock(HudElement.barKey)
        ..unlock(HudElement.episcopalRing);
      await tester.pump();

      final incense = find.byKey(const ValueKey<String>('hud-incense'));
      final key = find.byKey(const ValueKey<String>('hud-bar-key'));
      final ring = find.byKey(const ValueKey<String>('hud-episcopal-ring'));
      expect(incense, findsOneWidget);
      expect(key, findsOneWidget);
      expect(ring, findsOneWidget);

      await tester.tap(incense);
      await tester.pump();
      expect(find.text('Incenso'), findsOneWidget);

      game.dismissPrompt();
      await tester.pump();
      await tester.tap(key);
      await tester.pump();
      expect(find.text('Chiave del Bar Arcobaleno'), findsOneWidget);

      game.dismissPrompt();
      await tester.pump();
      await tester.tap(ring);
      await tester.pump();
      expect(find.text('Anello episcopale'), findsOneWidget);
    });
  });

  testWidgets('Mario waits while Luigi walks out of the hypermarket, and '
      'the tile Luigi stood on is free once he has gone', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final map = game.simulation.map;
      for (var x = luigiBars.left; x <= luigiBars.right; x++) {
        map.setTile(GridPoint(x, luigiBars.top), const Tile(TileKind.floor));
      }
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = GridPoint(luigiBars.right + 2, luigiSceneTrigger.top)
        ..facing = Direction.east;
      final start = mario.position;
      expect(map.tileAt(luigiTile).isWalkable, isFalse, reason: 'he is there');

      var gone = false;
      game
        ..sendLuigiAway(onFinished: () => gone = true)
        ..pressDirection(Direction.east)
        ..releaseDirection(Direction.east)
        ..update(0.3);
      expect(mario.position, start, reason: 'not while Luigi is walking');

      for (var i = 0; i < 400 && !gone; i++) {
        game.update(0.05);
      }
      expect(gone, isTrue);
      expect(map.tileAt(luigiTile).isWalkable, isTrue, reason: 'he has gone');
      game
        ..pressDirection(Direction.east)
        ..releaseDirection(Direction.east)
        ..update(0.3);
      expect(mario.position, start.step(Direction.east));
    });
  });

  testWidgets('nobody walks through the people at the Duomo', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final map = game.simulation.map;
      bool free(GridPoint tile) => map.tileAt(tile).isWalkable;
      expect(free(priestTile), isFalse, reason: 'Don Angelo at his gate');
      expect(free(duomoWelcomingCultistTile), isFalse);
      expect(free(duomoStairCultistTile), isFalse);
      expect(free(duomoStairCultistMovedTile), isTrue, reason: 'nobody yet');

      game.openDuomo();
      expect(free(priestTile), isTrue, reason: 'he has gone inside');
      expect(free(duomoPriestTile), isFalse);

      game.openDuomoUpper();
      expect(free(duomoStairCultistTile), isTrue, reason: 'he stepped aside');
      expect(free(duomoStairCultistMovedTile), isFalse, reason: 'to here');
    });
  });

  test('everything Mario picks up lies in a backpack, so the end of the '
      'level counts all of it', () {
    final world = createTutorialWorld();
    final pickups = world.pickups.values;
    expect(
      pickups.where((pickup) => pickup.episcopalRing).single.id,
      episcopalRingPickupId,
    );
    expect(
      pickups.where((pickup) => pickup.cultistRobe).single.position,
      duomoUpperRobeTile,
    );
    // The robe and the ring are backpacks among the others: the results
    // screen counts world.pickups, so they are in the total.
    expect(
      pickups.map((pickup) => pickup.id),
      containsAll(<String>[episcopalRingPickupId, cultistRobePickupId]),
    );
  });

  testWidgets('the mass leaves four cultists across the nave, Don Angelo '
      'dead and the key beside him', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final map = game.simulation.map;
      final key = game.simulation.pickups[duomoKeyPickupId]!;
      expect(key.active, isFalse);
      expect(map.tileAt(duomoPriestCorpseTile).isWalkable, isTrue);

      game.startDuomoMassacre();
      await tester.pump();

      final cultists = game.simulation.entities.values
          .where((entity) => entity.kind == EntityKind.cultist)
          .toList();
      expect(cultists, hasLength(4));
      expect(
        cultists.map(
          (cultist) => cultist.component<PositionComponent>().position,
        ),
        unorderedEquals(duomoCultistSpawns),
      );
      expect(
        cultists.every(
          (cultist) => cultist.component<HealthComponent>().current == 3,
        ),
        isTrue,
        reason: 'three shots each',
      );
      expect(key.active, isTrue, reason: 'the backpack is there to be taken');
      expect(
        map.tileAt(duomoPriestCorpseTile).isWalkable,
        isFalse,
        reason: 'Mario walks around the body, not over it',
      );
      // Nobody of the community is left standing in the nave.
      for (final tile in <GridPoint>[
        duomoPriestTile,
        duomoWelcomingCultistTile,
        duomoStairCultistMovedTile,
      ]) {
        expect(map.tileAt(tile).isWalkable, isTrue, reason: '$tile');
      }

      // Playing it again changes nothing: a load calls it a second time.
      game.startDuomoMassacre();
      await tester.pump();
      expect(
        game.simulation.entities.values.where(
          (entity) => entity.kind == EntityKind.cultist,
        ),
        hasLength(4),
      );
    });
  });

  testWidgets('the crucified zombie hangs over the altar only after the '
      'mass, moves on its own and groans across the nave', (tester) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await _pumpReadyGame(tester, audio: audio);
      Iterable<CrucifiedZombieComponent> onTheCross() =>
          game.world.children.whereType<CrucifiedZombieComponent>();
      expect(onTheCross(), isEmpty, reason: 'nothing there before the mass');

      game.progress.meet(EntityKind.cultist);
      game.startDuomoMassacre();
      // Its sheet is loaded before it is mounted, like every sprite.
      await game.ready();
      await tester.pump();

      final cross = onTheCross().single;
      expect(
        cross.position,
        Vector2(
          duomoCrucifixTile.x * StepboundGame.tileSize,
          duomoCrucifixTile.y * StepboundGame.tileSize,
        ),
      );
      // Scenery, not an actor: it is in nobody's way and nothing in the
      // simulation stands there, so it can neither be walked into nor bite.
      expect(game.simulation.entityAt(duomoCrucifixTile), isNull);
      expect(
        game.simulation.map.tileAt(duomoCrucifixTile).isWalkable,
        isFalse,
        reason: 'it hangs on the back wall',
      );
      expect(
        game.simulation.entities.values.where(
          (entity) => entity.kind == EntityKind.cultist,
        ),
        hasLength(4),
        reason: 'the four in the nave, and no fifth one on the cross',
      );

      // Mario in the Duomo hears it thrash; the fit itself is the sound.
      game.simulation.player.component<PositionComponent>().position =
          game.simulation.portals[duomoPortalTile]!.to;
      audio.played.clear();
      var seconds = 0.0;
      while (!cross.isTwitching && seconds < CrucifiedZombieComponent.maxRest) {
        game.update(1 / 60);
        seconds += 1 / 60;
      }
      expect(cross.isTwitching, isTrue, reason: 'it moves on its own');
      expect(audio.played, contains(Sfx.zombieAlert));

      // From another place it is out of earshot.
      game.simulation.player.component<PositionComponent>().position =
          trainMapStandTile;
      audio.played.clear();
      for (var i = 0; i < 60 * 30; i++) {
        game.update(1 / 60);
      }
      expect(audio.played, isNot(contains(Sfx.zombieAlert)));
    });
  });

  testWidgets('the key found beside Don Angelo shows on the HUD and opens '
      'the door upstairs', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      // Their own lesson is not what is being tested here: met already, it
      // does not queue itself in front of the lines that are.
      game.progress.meet(EntityKind.cultist);
      game
        ..startDuomoMassacre()
        ..unlock(HudElement.interact);
      final key = game.simulation.pickups[duomoKeyPickupId]!;
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = key.position.step(Direction.east)
        ..facing = Direction.west;
      Future<void> use() async {
        game.pressInteract();
        for (var i = 0; i < 60; i++) {
          game.update(1 / 20);
        }
        await tester.pump();
      }

      await use();
      expect(key.collected, isTrue);
      expect(game.hud.value, contains(HudElement.duomoKey));
      expect(
        (game.cover.value! as PromptCover).lines.single.text,
        BackpacksScript.duomoKeyFound,
      );
      // The badge is drawn with the rest of the controls, once the line
      // telling of it is gone.
      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('hud-duomo-key')),
        findsOneWidget,
      );

      // The same key, used on the door of the upper floor.
      mario
        ..position = duomoUpperLockedDoorTile.step(Direction.south)
        ..facing = Direction.north;
      await use();
      expect(
        game.simulation.map.tileAt(duomoUpperLockedDoorTile).isWalkable,
        isTrue,
      );
      expect(game.hud.value, isNot(contains(HudElement.duomoKey)));
      expect(
        (game.cover.value! as PromptCover).lines.single.text,
        DuomoScript.keyUsedLine,
      );
    });
  });

  testWidgets('the Duomo robe fades Mario into the occultist outfit and '
      'changes his portrait', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      expect(game.progress.activeOutfit, PlayerOutfit.base);

      game.collectCultistRobe();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(game.progress.unlockedOutfits, contains(PlayerOutfit.cultist));
      expect(game.progress.activeOutfit, PlayerOutfit.cultist);

      await tester.pump(const Duration(seconds: 2));
      game.showPrompt(const <TutorialLine>[
        TutorialLine.mario('La tunica mi sta bene.'),
      ]);
      await tester.pump();
      final portrait = tester.widget<Image>(
        find.byKey(const ValueKey<String>('dialogue-portrait-0')),
      );
      expect(
        (portrait.image as AssetImage).assetName,
        PlayerOutfit.cultist.portrait,
      );
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
        final before = _splats(tester).lastOrNull;
        await tester.tapAt(left);
        await tester.pump();
        final splat = _splats(tester).last;
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
    await _startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    final box = tester.getRect(intro);
    final left = Offset(box.left + box.width * 0.2, box.center.dy);
    final right = Offset(box.left + box.width * 0.8, box.center.dy);
    await tester.tapAt(left);
    await tester.pump();
    expect(_splats(tester), hasLength(1));
    expect(_splats(tester).single.at.dx, lessThan(box.center.dx));
    await tester.tapAt(right);
    await tester.pump();
    expect(_splats(tester), hasLength(2));
    expect(_splats(tester).last.at.dx, greaterThan(box.center.dx));
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

  testWidgets('a drag on the left walks that way for as long as it is held, '
      'turns without lifting and stops on release', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final mario = game.simulation.player.component<PositionComponent>();
      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      final zone = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-move')),
      );
      final start = mario.position;
      final thumb = await tester.startGesture(zone);
      await thumb.moveBy(const Offset(0, -8));
      play(1);
      expect(mario.position, start, reason: 'inside the dead zone');

      await thumb.moveBy(const Offset(0, -30));
      play(1.5);
      expect(mario.facing, Direction.north);
      expect(
        start.y - mario.position.y,
        greaterThan(1),
        reason: 'still walking while the thumb stays down',
      );

      // Round to the east without lifting the thumb.
      final turned = mario.position;
      await thumb.moveBy(const Offset(40, 30));
      play(0.4);
      expect(mario.facing, Direction.east);
      expect(mario.position.x - turned.x, greaterThan(1));

      // Lifted well short of the wall at the end of the street.
      await thumb.up();
      play(0.3);
      final stopped = mario.position;
      play(1.5);
      expect(mario.position, stopped, reason: 'lifting the thumb stops him');
    });
  });

  testWidgets('holding the right aims, a swipe shoots that way and a tap '
      'lowers the pistol', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final mario = game.simulation.player;
      final zone = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-act')),
      );
      Future<void> holdLongEnough() => Future<void>.delayed(
        ActionZone.holdToAim + const Duration(milliseconds: 150),
      );
      Iterable<ShotEvent> shots() =>
          game.presentation.lastEvents.whereType<ShotEvent>();
      // Lets the turn just taken play out, so the next one starts at once.
      void settle() {
        for (var i = 0; i < 30; i++) {
          game.update(1 / 30);
        }
      }

      mario.component<AmmoComponent>().hasGun = true;
      var finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.aiming.value, isFalse, reason: 'no shooting unlocked yet');

      game.unlock(HudElement.shoot);
      await tester.pump();

      // Nothing loaded: holding only clicks the pistol.
      mario.component<AmmoComponent>().loaded = 0;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.aiming.value, isFalse);
      expect(
        game.presentation.lastEvents.whereType<DryFiredEvent>(),
        hasLength(1),
      );

      settle();

      mario.component<AmmoComponent>().loaded = 3;
      // A swipe before the pistol is up does nothing.
      finger = await tester.startGesture(zone);
      await finger.moveBy(const Offset(40, 0));
      await holdLongEnough();
      await finger.up();
      expect(game.aiming.value, isFalse);

      // Hold, then swipe with the same finger: aimed and fired at once.
      await tester.pump();
      final before = _splats(tester).length;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.aiming.value, isTrue);
      await tester.pump();
      expect(_splats(tester), hasLength(before + 1), reason: 'the hold');
      await finger.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(_splats(tester), hasLength(before + 2), reason: 'the swipe');
      expect(game.aiming.value, isFalse);
      expect(shots().single.direction, Direction.north);
      expect(mario.component<PositionComponent>().facing, Direction.north);
      await finger.up();
      settle();

      // Hold and lift: the pistol stays up, and a new swipe fires.
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.aiming.value, isTrue, reason: 'lifting does not lower it');
      finger = await tester.startGesture(zone);
      await finger.moveBy(const Offset(-40, 5));
      await finger.up();
      expect(shots().single.direction, Direction.west);
      expect(game.aiming.value, isFalse);
      settle();

      // Right thumb holding the pistol up, left thumb swiping: it fires
      // that way instead of walking.
      mario.component<AmmoComponent>().loaded = 3;
      final standing = mario.component<PositionComponent>().position;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.aiming.value, isTrue);
      final left = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-move'))),
      );
      await left.moveBy(const Offset(0, 40));
      expect(shots().single.direction, Direction.south);
      expect(game.aiming.value, isFalse);
      settle();
      expect(
        mario.component<PositionComponent>().position,
        standing,
        reason: 'the swipe that fired does not walk him on',
      );
      await left.up();
      await finger.up();
      settle();

      // The keyboard arrows do the same.
      game.pressShoot();
      expect(game.aiming.value, isTrue);
      game.pressDirection(Direction.east);
      expect(shots().single.direction, Direction.east);
      expect(game.aiming.value, isFalse);
      settle();

      // Aiming, a tap lowers the pistol without firing.
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.aiming.value, isTrue);
      final loaded = mario.component<AmmoComponent>().loaded;
      await tester.tap(find.byKey(const ValueKey<String>('touch-act')));
      expect(game.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, loaded);

      // A few seconds on, the blood has dried off the glass.
      await tester.pump();
      expect(_splats(tester), isNotEmpty);
      await Future<void>.delayed(
        Duration(
          milliseconds: (BloodSplatPainter.lifetime * 1000).round() + 100,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(_splats(tester), isEmpty);
    });
  });

  testWidgets('on a keyboard, tapping space interacts, holding it aims and '
      'the arrows then shoot', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, saves: saves);
      final mario = game.simulation.player;
      void key(LogicalKeyboardKey key, {required bool down}) {
        final physical = key == LogicalKeyboardKey.space
            ? PhysicalKeyboardKey.space
            : PhysicalKeyboardKey.arrowUp;
        game.onKeyEvent(
          down
              ? KeyDownEvent(
                  physicalKey: physical,
                  logicalKey: key,
                  timeStamp: Duration.zero,
                )
              : KeyUpEvent(
                  physicalKey: physical,
                  logicalKey: key,
                  timeStamp: Duration.zero,
                ),
          const <LogicalKeyboardKey>{},
        );
      }

      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      const space = LogicalKeyboardKey.space;
      mario.component<AmmoComponent>()
        ..hasGun = true
        ..loaded = 2;
      game.unlock(HudElement.shoot);

      // Held: the pistol comes up once the hold is long enough.
      key(space, down: true);
      play(0.2);
      expect(game.aiming.value, isFalse, reason: 'not held long enough yet');
      play(0.2);
      expect(game.aiming.value, isTrue);
      key(space, down: false);
      expect(game.aiming.value, isTrue, reason: 'letting go keeps it up');

      // An arrow fires that way.
      key(LogicalKeyboardKey.arrowUp, down: true);
      expect(
        game.presentation.lastEvents.whereType<ShotEvent>().single.direction,
        Direction.north,
      );
      key(LogicalKeyboardKey.arrowUp, down: false);
      expect(game.aiming.value, isFalse);
      play(1);

      // Aiming, a quick tap lowers the pistol.
      key(space, down: true);
      play(0.4);
      key(space, down: false);
      expect(game.aiming.value, isTrue);
      key(space, down: true);
      play(0.1);
      key(space, down: false);
      expect(game.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, 1);

      // Not aiming, a quick tap interacts: here, resting at the fire.
      game.tutorial.restore(const <String, Object?>{
        'north': <String, Object?>{'campLesson': true},
        'backpacks': <String, Object?>{'lesson': true},
        'street': <String, Object?>{'zombieLesson': true},
      });
      final camp = game.simulation.campfires.firstWhere(
        place(PlaceId.northDistrict).bounds.contains,
      );
      mario.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      game.unlock(HudElement.interact);
      key(space, down: true);
      play(0.1);
      key(space, down: false);
      expect(game.aiming.value, isFalse);
      play(3);
      await Future<void>.delayed(Duration.zero);
      expect((await saves.load(1))?.atCampfire, isTrue);
    });
  });

  testWidgets('a tap on the right interacts once interacting is unlocked', (
    tester,
  ) {
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
      var splatted = false;
      Future<void> tapAndWait() async {
        final before = _splats(tester).lastOrNull;
        await tester.tap(find.byKey(const ValueKey<String>('touch-act')));
        await tester.pump();
        splatted = !identical(_splats(tester).lastOrNull, before);
        for (var i = 0; i < 60; i++) {
          game.update(1 / 20);
        }
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }

      await tapAndWait();
      expect(await saves.load(1), isNull, reason: 'not unlocked yet');
      expect(splatted, isFalse, reason: 'a tap that does nothing');

      game.unlock(HudElement.interact);
      await tester.pump();
      await tapAndWait();
      expect((await saves.load(1))?.atCampfire, isTrue);
      expect(splatted, isTrue, reason: 'the tap left blood');
    });
  });

  test('a drag points along the axis it leans on, and keeps its direction '
      'along a diagonal', () {
    expect(directionOf(const Offset(30, 10)), Direction.east);
    expect(directionOf(const Offset(-30, 10)), Direction.west);
    expect(directionOf(const Offset(5, -30)), Direction.north);
    expect(directionOf(const Offset(5, 30)), Direction.south);
    const diagonal = Offset(20, 22);
    expect(directionOf(diagonal, current: Direction.east), Direction.east);
    expect(directionOf(diagonal, current: Direction.south), Direction.south);
    expect(
      directionOf(const Offset(10, 30), current: Direction.east),
      Direction.south,
    );
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
      expect(game.drawnPlaces, <String>[place(PlaceId.street).background!]);

      game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      game
        ..pressDirection(Direction.north)
        ..releaseDirection(Direction.north)
        ..update(0.3);
      // The barracks are painted from the tile atlas: no picture to name.
      expect(game.drawnPlaces, <String>['tiles:barracks']);
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
      // The far platform is painted from the tile atlas: what the story
      // opens is the railcar's door, an object in it, not a second
      // picture of the whole place.
      expect(game.drawnPlaces, <String>['tiles:stationFarSide']);

      progress.remember(StoryMemory.luigiRescued);
      game.update(1 / 30);
      expect(world.map.tileAt(stationTrainDoorTile).isWalkable, isTrue);
      expect(game.drawnPlaces, <String>['tiles:stationFarSide:open']);
    });
  });

  testWidgets('every object Mario can interact with glints like a backpack, '
      'once the button is there to press', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final glints = game.world.children.whereType<InteractGlintComponent>();
      GridPoint tileOf(InteractGlintComponent glint) => GridPoint(
        (glint.position.x / StepboundGame.tileSize).round(),
        (glint.position.y / StepboundGame.tileSize).round(),
      );
      final world = game.simulation;
      // A glint on the thing itself, or on the tile of it that shows it
      // best: a crate or a cot spans a few tiles.
      bool glinted(GridPoint tile) =>
          glints.any((glint) => tileOf(glint).manhattanDistanceTo(tile) <= 1);
      for (final tile in <GridPoint>[
        ...world.campfires,
        ...world.lookouts.where((tile) => tile != trainLuigiTile),
        ...world.controls.keys,
        // What the scripts answer when interacted with.
        barLockedDoorTile,
        duomoUpperLockedDoorTile,
      ]) {
        expect(glinted(tile), isTrue, reason: 'nothing glints near $tile');
      }
      // Only objects glint: Luigi, whom Mario talks to, does not.
      expect(glints.where((glint) => tileOf(glint) == trainLuigiTile), isEmpty);
      expect(
        world.travelMaps.any(glinted),
        isTrue,
        reason: 'the map on the table',
      );

      final gap = glints.singleWhere(
        (glint) => tileOf(glint) == rooftopGapTile,
      );
      expect(gap.active(), isFalse, reason: 'no interact button yet');
      game.unlock(HudElement.interact);
      expect(gap.active(), isTrue);
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
      expect(find.byKey(const ValueKey<String>('touch-move')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(game.inputLocked, isFalse);
      expect(find.byKey(const ValueKey<String>('touch-move')), findsOneWidget);
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
    const controls = <String>['touch-move', 'touch-act', 'touch-ammo'];
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

  testWidgets('the left half of the screen walks, the right half acts', (
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

    Rect rectOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    // Like every gamepad since the NES: the thumb that moves is the left one.
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final move = rectOf('touch-move');
    final act = rectOf('touch-act');
    expect(move.left, 0);
    expect(move.right, moreOrLessEquals(screen / 2));
    expect(act.left, moreOrLessEquals(screen / 2));
    expect(act.right, moreOrLessEquals(screen));
    expect(rectOf('touch-ammo').center.dx, greaterThan(screen / 2));
  });

  group('on a phone longer than 16:9, with the camera on the left', () {
    /// A 20:9 phone in landscape: the picture leaves a band on each side.
    const screen = Size(915, 412);
    const cutout = 32.0;
    final picture =
        IntegerResolutionViewport.virtualWidth *
        IntegerResolutionViewport.scaleFor(screen.width, screen.height);
    final band = (screen.width - picture) / 2;

    Future<StepboundGame> loadOnThePhone(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = screen
        ..padding = const FakeViewPadding(left: cutout);
      addTearDown(tester.view.reset);
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
      return tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
    }

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    testWidgets('the controls sit in the bands, as far from either edge', (
      tester,
    ) async {
      await loadOnThePhone(tester);
      expect(
        rectOf(tester, 'stepbound-game').width,
        moreOrLessEquals(picture),
        reason: 'the picture keeps its 16:9',
      );

      // The camera cutout is on the left; the right edge keeps the same
      // gap, so the HUD looks the same from either side.
      final right = screen.width - rectOf(tester, 'touch-ammo').right;
      expect(right, moreOrLessEquals(cutout), reason: 'same gap both sides');
      expect(right, lessThan(band), reason: 'out in the band, off the game');
      expect(
        screen.width - rectOf(tester, 'touch-menu').right,
        moreOrLessEquals(right),
      );
      // The gesture halves cover the whole screen, bands included.
      expect(rectOf(tester, 'touch-move').left, 0);
      expect(rectOf(tester, 'touch-act').right, moreOrLessEquals(screen.width));
    });

    testWidgets('a text box spans the screen, as far from either edge', (
      tester,
    ) async {
      final game = await loadOnThePhone(tester);
      game.showPrompt(const <TutorialLine>[TutorialLine('Una battuta')]);
      await tester.pump();

      final box = rectOf(tester, 'story-text');
      expect(box.left, lessThan(band), reason: 'out into the band');
      expect(box.left, greaterThanOrEqualTo(cutout), reason: 'clear of it');
      expect(
        screen.width - box.right,
        moreOrLessEquals(box.left),
        reason: 'same gap both sides',
      );
    });
  });
}
