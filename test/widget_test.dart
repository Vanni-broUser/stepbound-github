import 'dart:ui' as ui;

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
import 'package:stepbound/game/render/asset_image.dart';
import 'package:stepbound/game/render/crucified_zombie_component.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/render/offscreen_culled.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/tile_place_component.dart';
import 'package:stepbound/game/render/torch_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/level_map.dart';
import 'package:stepbound/ui/loading_art.dart';
import 'package:stepbound/ui/story_intro.dart';

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

/// One step: an arrow pressed and let go at once.
void _tap(StepboundGame game, Direction direction) => game.input
  ..pressDirection(direction)
  ..releaseDirection(direction);

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

  testWidgets("Luigi's music waits for the reunion on the far platform", (
    tester,
  ) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await _pumpReadyGame(tester, audio: audio);
      game.progress.remember(StoryMemory.luigiRescued);
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = place(PlaceId.stationUnderpass).tilesOf('*').first;
      game.update(1 / 60);
      expect(
        audio.music,
        isNot(Music.luigi),
        reason: 'crossing the underpass must not start the reunion music',
      );

      mario.position = GridPoint(
        (stationPlatform.left + stationPlatform.right) ~/ 2,
        stationPlatform.top,
      );
      game.update(1 / 60);
      expect(
        audio.music,
        isNot(Music.luigi),
        reason: 'the StationScript starts it with the reunion cutscene',
      );
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

  testWidgets('the bullets sit in the row of carried things, and a tap '
      'tells of them', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester)
        ..unlock(HudElement.ammo)
        ..unlock(HudElement.incense);
      game.simulation.player.component<AmmoComponent>().loaded = 3;
      game.update(1 / 60);
      await tester.pump();

      Container badge() => tester.widget<Container>(
        find.byKey(const ValueKey<String>('touch-ammo')),
      );
      Border borderOf(Container badge) =>
          (badge.decoration! as BoxDecoration).border! as Border;

      // Still without the pistol, the badge is a disabled button: greyed
      // out, a tap does nothing, but the count keeps up all the same.
      expect(borderOf(badge()).top.color, BloodColors.dried);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('touch-ammo-count')),
          matching: find.text('×3'),
        ),
        findsWidgets,
      );
      await tester.tap(find.byKey(const ValueKey<String>('touch-ammo')));
      await tester.pump();
      expect(game.cover.value, isNull, reason: 'nothing to press yet');
      game.simulation.player.component<AmmoComponent>().loaded = 4;
      game.update(1 / 60);
      await tester.pump();
      expect(find.text('×4'), findsWidgets);
      game.simulation.player.component<AmmoComponent>().loaded = 3;
      game.update(1 / 60);
      await tester.pump();

      // The count is written over the bottom-right corner, spilling past it.
      final box = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo')),
      );
      final count = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo-count')),
      );
      expect(count.right, greaterThan(box.right));
      expect(count.bottom, greaterThan(box.bottom));
      expect(count.left, lessThan(box.right));
      expect(count.top, lessThan(box.bottom));

      // The pistol found, the badge wakes up: the count is the news.
      game.simulation.player.component<AmmoComponent>().hasGun = true;
      game.update(1 / 60);
      await tester.pump();
      expect(borderOf(badge()).top.color, BloodColors.fresh);
      await tester.tap(find.byKey(const ValueKey<String>('touch-ammo')));
      await tester.pump();
      expect(find.text('3 proiettili'), findsOneWidget);
      game.dismissPrompt();
      await tester.pump();

      // One row, left to right in the order things were picked up.
      final bullets = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo')),
      );
      final incense = tester.getRect(
        find.byKey(const ValueKey<String>('hud-incense')),
      );
      expect(bullets.right, lessThanOrEqualTo(incense.left));
      expect(bullets.top, incense.top);
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
      game.hometown.sendLuigiAway(onFinished: () => gone = true);
      _tap(game, Direction.east);
      game.update(0.3);
      expect(mario.position, start, reason: 'not while Luigi is walking');

      for (var i = 0; i < 400 && !gone; i++) {
        game.update(0.05);
      }
      expect(gone, isTrue);
      expect(map.tileAt(luigiTile).isWalkable, isTrue, reason: 'he has gone');
      _tap(game, Direction.east);
      game.update(0.3);
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

      game.hometown.openDuomo();
      expect(free(priestTile), isTrue, reason: 'he has gone inside');
      expect(free(duomoPriestTile), isFalse);

      game.hometown.openDuomoUpper();
      expect(free(duomoStairCultistTile), isTrue, reason: 'he stepped aside');
      expect(free(duomoStairCultistMovedTile), isFalse, reason: 'to here');
    });
  });

  test('everything Mario picks up lies in a backpack, so the end of the '
      'level counts all of it', () {
    final world = createGameWorld();
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

      game.hometown.startDuomoMassacre();
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
      game.hometown.startDuomoMassacre();
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
      game.hometown.startDuomoMassacre();
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
      game.hometown.startDuomoMassacre();
      game.unlock(HudElement.interact);
      final key = game.simulation.pickups[duomoKeyPickupId]!;
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = key.position.step(Direction.east)
        ..facing = Direction.west;
      Future<void> use() async {
        game.input.pressInteract();
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

      game.hometown.collectCultistRobe();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(game.progress.unlockedOutfits, contains(PlayerOutfit.cultist));
      expect(game.progress.activeOutfit, PlayerOutfit.cultist);

      await tester.pump(const Duration(seconds: 2));
      game.showPrompt(const <StoryLine>[
        StoryLine.mario('La tunica mi sta bene.'),
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
    expect(
      find.byKey(const ValueKey<String>('outbreak-story')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('loading-cover')), findsNothing);
  });

  testWidgets('the outbreak follows the first scenes without an intermediate '
      'loading screen, then gameplay loads once', (tester) {
    return tester.runAsync(() async {
      await _startNewGame(tester);
      final intro = find.byKey(const ValueKey<String>('story-intro'));
      for (var i = 0; i < _introTapCount; i++) {
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

  testWidgets('the first three scenes lead straight into the outbreak', (
    tester,
  ) async {
    await _startNewGame(tester);
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    for (var i = 0; i < _introTapCount; i++) {
      await tester.tap(intro);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey<String>('title-splash')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('outbreak-story')),
      findsOneWidget,
    );
  });

  testWidgets('camera starts clamped around the player', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      // The player starts near the south-west corner of the tutorial street:
      // the view stops at the map's left edge instead of centring on him,
      // and never reaches past its bottom (42 tiles).
      final view = game.camera.visibleWorldRect;
      expect(view.left, closeTo(0, 0.01));
      expect(view.bottom, lessThanOrEqualTo(42 * 16 + 0.01));
    });
  });

  testWidgets('two fingers landing together zoom the view instead of '
      'walking, and two thumbs, one after the other, still play', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final mario = game.simulation.player.component<PositionComponent>();
      final start = mario.position;
      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      final whole = game.camera.visibleWorldRect.width;
      final left = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-move')),
      );
      final a = await tester.startGesture(left - const Offset(12, 0));
      final b = await tester.startGesture(left + const Offset(12, 0));
      expect(game.pinching.value, isTrue);
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      play(1);
      expect(game.zoom, greaterThan(1));
      expect(
        game.camera.visibleWorldRect.width,
        closeTo(whole / game.zoom, 0.01),
      );
      expect(mario.position, start, reason: 'a pinch is not a step');
      await a.up();
      await b.up();
      expect(game.pinching.value, isFalse);
      expect(game.zoom, greaterThan(1), reason: 'the view stays close');

      // Walking with the left thumb, then touching the right a while
      // later: that is playing, not zooming.
      final zoomed = game.zoom;
      final thumb = await tester.createGesture();
      await thumb.down(left, timeStamp: const Duration(seconds: 10));
      final right = await tester.createGesture();
      await right.down(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-act'))),
        timeStamp:
            const Duration(seconds: 10) +
            PinchZone.together +
            const Duration(milliseconds: 100),
      );
      expect(game.pinching.value, isFalse);
      await thumb.moveBy(const Offset(0, -40));
      await right.moveBy(const Offset(0, 4));
      play(1);
      expect(game.zoom, zoomed);
      expect(mario.position, isNot(start), reason: 'the thumb walked');
      await thumb.up();
      await right.up();
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

  testWidgets('holding the right raises a stick that turns Mario, lifting '
      'fires that way and lifting in the middle ring lowers the pistol', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final mario = game.simulation.player;
      final facing = mario.component<PositionComponent>();
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
      expect(
        game.input.aiming.value,
        isFalse,
        reason: 'no shooting unlocked yet',
      );

      game.unlock(HudElement.shoot);
      await tester.pump();

      // Nothing loaded: holding only clicks the pistol.
      mario.component<AmmoComponent>().loaded = 0;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.input.aiming.value, isFalse);
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
      expect(game.input.aiming.value, isFalse);

      // Hold: the pistol comes up with a splash of blood. Dragging turns
      // Mario without firing, all the way round, and lifting fires.
      await tester.pump();
      // Splats age by the wall clock here, so older ones may dry off in
      // between: count only the new ones on top.
      final before = _splats(tester).lastOrNull;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.input.aiming.value, isTrue);
      await tester.pump();
      final hold = _splats(tester).last;
      expect(hold, isNot(same(before)), reason: 'the hold');
      await finger.moveBy(const Offset(0, -40));
      expect(facing.facing, Direction.north);
      await finger.moveBy(const Offset(40, 40));
      expect(facing.facing, Direction.east);
      expect(shots(), isEmpty, reason: 'nothing fired while held');
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      await tester.pump();
      expect(_splats(tester).last, isNot(same(hold)), reason: 'the shot');
      expect(shots().single.direction, Direction.east);
      expect(game.input.aiming.value, isFalse);
      settle();

      // Dragged out and back into the middle ring: lifting fires nothing.
      var loaded = mario.component<AmmoComponent>().loaded;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.moveBy(const Offset(-40, 5));
      expect(facing.facing, Direction.west);
      await finger.moveBy(const Offset(36, -3));
      await finger.up();
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, loaded);

      // Held and lifted where it landed: the pistol goes down unfired.
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      expect(game.input.aiming.value, isFalse, reason: 'lifting lowers it');
      expect(mario.component<AmmoComponent>().loaded, loaded);

      // Right thumb aiming, left thumb dragging: he neither walks nor
      // fires, the left thumb has no say while the pistol is up.
      final standing = facing.position;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      final left = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-move'))),
      );
      await left.moveBy(const Offset(0, 40));
      settle();
      expect(mario.component<AmmoComponent>().loaded, loaded);
      expect(facing.position, standing);
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      await left.up();
      settle();

      // The keyboard arrows still fire straight away.
      loaded = mario.component<AmmoComponent>().loaded;
      game.input.pressShoot();
      expect(game.input.aiming.value, isTrue);
      game.input.pressDirection(Direction.east);
      expect(shots().single.direction, Direction.east);
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, loaded - 1);

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
      expect(
        game.input.aiming.value,
        isFalse,
        reason: 'not held long enough yet',
      );
      play(0.2);
      expect(game.input.aiming.value, isTrue);
      key(space, down: false);
      expect(game.input.aiming.value, isTrue, reason: 'letting go keeps it up');

      // An arrow fires that way.
      key(LogicalKeyboardKey.arrowUp, down: true);
      expect(
        game.presentation.lastEvents.whereType<ShotEvent>().single.direction,
        Direction.north,
      );
      key(LogicalKeyboardKey.arrowUp, down: false);
      expect(game.input.aiming.value, isFalse);
      play(1);

      // Aiming, a quick tap lowers the pistol.
      key(space, down: true);
      play(0.4);
      key(space, down: false);
      expect(game.input.aiming.value, isTrue);
      key(space, down: true);
      play(0.1);
      key(space, down: false);
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, 1);

      // Not aiming, a quick tap interacts: here, resting at the fire.
      game.story.restore(const <String, Object?>{
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
      expect(game.input.aiming.value, isFalse);
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
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, audio: audio, saves: saves);

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
      await _pumpBlackFade(tester);
      await _waitForGame(tester);
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
      void stepNorth() {
        _tap(game, Direction.north);
        game.update(0.3);
      }

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
      expect(game.drawnPlaces, <String>['tiles:street']);

      game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      _tap(game, Direction.north);
      game.update(0.3);
      // The barracks are painted from the tile atlas: no picture to name.
      expect(game.drawnPlaces, <String>['tiles:barracks']);
    });
  });

  testWidgets('only the fires in view are drawn', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      game.update(1 / 30);
      final view = game.camera.visibleWorldRect;
      final culled = game.world.children.whereType<OffscreenCulled>().toList();
      expect(culled.whereType<FireComponent>(), isNotEmpty);
      expect(culled.whereType<TorchComponent>(), isNotEmpty);
      for (final component in culled) {
        expect(component.onScreen, component.reach.overlaps(view));
      }
      // The city's fires lie mostly far from the first street.
      expect(culled.where((component) => !component.onScreen), isNotEmpty);
    });
  });

  testWidgets('a new game reuses the images the last one decoded and built', (
    tester,
  ) {
    return tester.runAsync(() async {
      List<ui.Image?> imagesOf(StepboundGame game) => <ui.Image?>[
        for (final front in game.world.children.whereType<TilePlaceFront>())
          front.image,
      ];

      final first = imagesOf(await _pumpReadyGame(tester));
      await tester.pumpWidget(const SizedBox());
      final second = imagesOf(await _pumpReadyGame(tester));
      expect(first, isNotEmpty);
      expect(first, everyElement(isNotNull));
      // Each game holds handles of its own on the same pictures.
      expect(second, hasLength(first.length));
      for (final (index, image) in second.indexed) {
        expect(image!.isCloneOf(first[index]!), isTrue);
      }
      expect(
        await loadAssetImage(NpcComponent.luigiAsset),
        same(await loadAssetImage(NpcComponent.luigiAsset)),
      );
    });
  });

  testWidgets('only the area Mario is in, and one door past it, is in memory; '
      'the rest comes and goes with him', (tester) {
    return tester.runAsync(() async {
      final world = createGameWorld();
      final game = StepboundGame(world: world, progress: Progress());
      await tester.pumpWidget(GameWidget<StepboundGame>(game: game));
      final state = tester.state<GameWidgetState<StepboundGame>>(
        find.byType(GameWidget<StepboundGame>),
      );
      await state.loaderFuture;
      await game.ready();

      Set<PlaceId> areaOf(AreaId area) => <PlaceId>{
        for (final place in gamePlaces)
          if (place.area == area) place.id,
      };

      // On the street: the town, the harbour down the road and the train
      // at the far platform.
      expect(game.loadedPlaces, <PlaceId>{
        ...areaOf(AreaId.hometownTown),
        PlaceId.harbour,
        PlaceId.trainInterior,
      });
      expect(game.lastAreaLoad, isNotNull);

      // Down at the harbour the town's buildings are let go, all but the
      // district the road comes from.
      world.player.component<PositionComponent>().position = place(
        PlaceId.harbour,
      ).walkableRow(place(PlaceId.harbour).height ~/ 2).first;
      game.update(1 / 30);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      game.update(1 / 30);
      await game.ready();
      expect(game.loadedPlaces, <PlaceId>{
        ...areaOf(AreaId.hometownHarbour),
        PlaceId.northDistrict,
      });
      expect(
        game.world.children.whereType<TilePlaceComponent>().map(
          (component) => component.place.id,
        ),
        unorderedEquals(game.loadedPlaces),
      );
    });
  });

  test('the train parked at Termini keeps Termini loaded, not Molfetta', () {
    final world = createGameWorld();
    parkTrain(world, LevelId.rome);
    expect(
      PlaceLayers.kept(
        place(PlaceId.trainInterior),
        gamePlaces,
        world.portals,
      ).map((place) => place.id),
      unorderedEquals(<PlaceId>[PlaceId.trainInterior, PlaceId.romeTermini]),
    );
    expect(
      PlaceLayers.kept(
        place(PlaceId.romeTermini),
        gamePlaces,
        world.portals,
      ).map((place) => place.id),
      unorderedEquals(<PlaceId>[PlaceId.romeTermini, PlaceId.trainInterior]),
    );
  });

  testWidgets('rescuing Luigi opens both the train tile and its artwork', (
    tester,
  ) {
    return tester.runAsync(() async {
      final world = createGameWorld();
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
      // The table laid aboard is one thing, six tiles wide: one glint on it.
      expect(trainFoodTiles.any(glinted), isTrue);
      for (final tile in <GridPoint>[
        ...world.campfires.where((camp) => !trainFoodTiles.contains(camp)),
        ...world.lookouts.where((tile) => tile != trainLuigiTile),
        ...world.controls.keys,
        // What the scripts answer when interacted with.
        barLockedDoorTile,
        duomoUpperLockedDoorTile,
        stationTrainDoorTile,
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

  testWidgets('coming back out of the Bar Arcobaleno onto the harbour shows '
      'no card', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      final door = place(PlaceId.barArcobaleno).tileOf('E');
      game.simulation.player.component<PositionComponent>()
        ..position = door.step(Direction.north)
        ..facing = Direction.south;
      game.update(1);
      _tap(game, Direction.south);
      for (var i = 0; i < 30; i++) {
        game.update(1 / 30);
      }
      expect(
        placeAt(
          game.simulation.player.component<PositionComponent>().position,
        )?.id,
        PlaceId.harbour,
      );
      expect(game.cover.value, isNot(isA<PlaceCardCover>()));
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
      final harbour = gamePlaces.firstWhere(
        (region) => region.name == harbourName,
      );
      bool cameraIn(GridRect bounds) {
        final at = game.camera.viewfinder.position;
        return bounds.contains(
          GridPoint((at.x / 16).floor(), (at.y / 16).floor()),
        );
      }

      _tap(game, Direction.south);
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
      final game = await _pumpReadyGame(tester, saves: saves);
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
      final game = await _pumpReadyGame(tester, saves: saves);
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
      game.progress.confirmPendingMemories();
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
      expect(saved.story, isEmpty);
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
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
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

    game.showPrompt(const <StoryLine>[StoryLine('Un messaggio')]);
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
    const same = 'assets/story/scenes/mario_luigi_reunion.jpg';
    var finished = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StoryIntro(
          scenes: const <StoryScene>[
            StoryScene(image: same, text: 'Prima'),
            StoryScene(image: same, text: 'Seconda'),
            StoryScene(image: 'assets/story/scenes/harbour.jpg', text: 'Terza'),
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
      final lines = <StoryLine>[
        const StoryLine('Prima battuta'),
        const StoryLine('Seconda battuta'),
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
      'map, and Città natale resumes at the map in the train, loading on '
      'the harbour', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await _pumpReadyGame(tester, saves: saves);
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
      final saved = (await saves.load(1))!;
      expect(saved.place, 'Treno', reason: 'the label in the save slots');
      expect(saved.atCampfire, isTrue, reason: 'it can be resumed from');
      expect(
        find.byKey(const ValueKey<String>('level-complete')),
        findsOneWidget,
      );
      expect(find.text('ZAINI TROVATI'), findsOneWidget);
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
      expect(stat('backpack-stat'), '0 / 17');
      expect(stat('kill-stat'), '1 / ${zombies.length}');
      expect(stat('zombie-kind-stat'), '1 / ${zombies.toSet().length}');
      expect(stat('campfire-stat'), '1 / 4');
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
      await _waitForGame(tester);
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
      final game = await _pumpReadyGame(tester, saves: saves);
      // Where the station's scene leaves him.
      game.simulation.player.component<PositionComponent>()
        ..position = trainMapStandTile
        ..facing = trainMapFacing;
      game.simulation.player.component<AmmoComponent>().loaded = 12;
      game.completeLevel();
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
      // A tap for each new picture, one for each line.
      final pictures = romeScenes.map((scene) => scene.image).toSet().length;
      for (var i = 0; i < pictures + romeScenes.length; i++) {
        await tester.tap(story);
        await tester.pump();
      }
      await _pumpBlackFade(tester);
      await _waitForGame(tester);

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
      expect(saved.levelStart, isNotNull);

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
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
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
    // The bullets are carried up with the rest, in the left corner.
    expect(rectOf('touch-ammo').center.dx, lessThan(screen / 2));
  });

  group('on a phone longer than 16:9, with the camera on the left', () {
    /// A 20:9 phone in landscape: the 16:9 picture the menus keep would
    /// leave a band on each side.
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
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
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
        rectOf(tester, 'stepbound-game'),
        Offset.zero & screen,
        reason: 'the world fills the screen',
      );

      // The camera cutout is on the left; the right edge keeps the same
      // gap, so the HUD looks the same from either side. The carried
      // things start the row on the left, the menu ends the top on the
      // right, and both keep that mirrored gap.
      final left = rectOf(tester, 'touch-ammo').left;
      expect(left, moreOrLessEquals(cutout), reason: 'same gap both sides');
      expect(left, lessThan(band), reason: 'out by the edge of the screen');
      expect(
        screen.width - rectOf(tester, 'touch-menu').right,
        moreOrLessEquals(cutout),
      );
      // The gesture halves cover the whole screen, bands included.
      expect(rectOf(tester, 'touch-move').left, 0);
      expect(rectOf(tester, 'touch-act').right, moreOrLessEquals(screen.width));
    });

    testWidgets('a text box spans the screen, as far from either edge', (
      tester,
    ) async {
      final game = await loadOnThePhone(tester);
      game.showPrompt(const <StoryLine>[StoryLine('Una battuta')]);
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
