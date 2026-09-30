import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/fire_frame.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('F2 mounts the Flame game surface', (tester) {
    return tester.runAsync(() async {
      await pumpAppThroughIntro(tester);
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

  testWidgets("in Rome, Molfetta's keys are out of sight and the grappling "
      'hook is not', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      game.progress.level = LevelId.rome;
      // Luigi's welcome to Rome would cover the corner.
      game.story.restore(<String, Object?>{
        ...game.story.toJson(),
        'rome': <String, Object?>{'welcomed': true},
      });
      game
        ..unlock(HudElement.duomoKey)
        ..unlock(HudElement.barKey)
        ..unlock(HudElement.grapplingHook);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('hud-duomo-key')), findsNothing);
      expect(find.byKey(const ValueKey<String>('hud-bar-key')), findsNothing);
      final hook = find.byKey(const ValueKey<String>('hud-grappling-hook'));
      expect(hook, findsOneWidget);
      await tester.tap(hook);
      await tester.pump();
      expect(find.text('Rampino'), findsOneWidget);
    });
  });

  testWidgets('without the launcher, its rounds wait greyed out and '
      'deaf to taps, counted', (tester) {
    return tester.runAsync(() async {
      final semantics = tester.ensureSemantics();
      final game = await pumpReadyGame(tester);
      game.simulation.player.component<AmmoComponent>().rockets = 1;
      game.unlock(HudElement.rockets);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      game.update(1 / 30);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('hud-rockets')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('hud-rockets-count')),
          matching: find.text('×1'),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('hud-rockets')),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Lanciarazzi da trovare, colpi: 1')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  testWidgets('quest inventory badges show their item name when tapped', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester)
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

  testWidgets('one weapon in hand at a time, burning round its badge; the '
      'molotovs show only while there is one', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester)
        ..unlock(HudElement.ammo)
        ..unlock(HudElement.molotov);
      final ammo = game.simulation.player.component<AmmoComponent>()
        ..hasGun = true
        ..molotovs = 0;
      game.update(1 / 60);
      await tester.pump();

      const pistol = ValueKey<String>('touch-ammo');
      const molotov = ValueKey<String>('hud-molotov');
      Finder burning(ValueKey<String> key) =>
          find.ancestor(of: find.byKey(key), matching: find.byType(FireFrame));

      // None carried: no badge at all, not a badge at zero, and the
      // pistol alone does not burn.
      expect(find.byKey(molotov), findsNothing);
      expect(burning(pistol), findsNothing);

      // Two weapons: the one in hand burns, and a tap picks, telling
      // nothing.
      ammo.molotovs = 2;
      game.update(1 / 60);
      await tester.pump();
      await tester.tap(find.byKey(pistol));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(find.byKey(molotov), findsOneWidget);
      expect(find.text('×2'), findsWidgets);
      expect(burning(pistol), findsOneWidget);
      expect(burning(molotov), findsNothing);

      // A tap on the molotov takes it in hand, the pistol goes away.
      await tester.tap(find.byKey(molotov));
      await tester.pump();
      expect(game.input.weapon.value, Weapon.molotov);
      expect(burning(molotov), findsOneWidget);
      expect(burning(pistol), findsNothing);
      // The count is laid over the flames, not under them.
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('hud-molotov-count')),
          matching: find.byType(FireFrame),
        ),
        findsNothing,
      );

      // And the pistol back the same way.
      await tester.tap(find.byKey(pistol));
      await tester.pump();
      expect(game.input.weapon.value, Weapon.pistol);
      expect(burning(pistol), findsOneWidget);
      expect(burning(molotov), findsNothing);

      // The last one gone, the badge goes; a new one found, it is back.
      await tester.tap(find.byKey(molotov));
      await tester.pump();
      ammo.molotovs = 0;
      game.update(1 / 60);
      await tester.pump();
      expect(find.byKey(molotov), findsNothing);
      expect(game.input.weapon.value, Weapon.pistol);
      expect(burning(pistol), findsNothing);
      ammo.molotovs = 1;
      game.update(1 / 60);
      await tester.pump();
      expect(find.byKey(molotov), findsOneWidget);
      expect(find.text('×1'), findsWidgets);

      // Molotovs and no pistol: one weapon, no flames, a tap tells.
      ammo.hasGun = false;
      game.update(1 / 60);
      await tester.pump();
      expect(game.input.weapon.value, Weapon.molotov);
      expect(burning(molotov), findsNothing);
      await tester.tap(find.byKey(molotov));
      await tester.pump();
      expect(find.text('1 molotov'), findsOneWidget);
    });
  });

  testWidgets('a molotov thrown stays the weapon in hand while there are '
      'more; after the last one the pistol is back', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester)
        ..unlock(HudElement.ammo)
        ..unlock(HudElement.molotov);
      final ammo = game.simulation.player.component<AmmoComponent>()
        ..hasGun = true
        ..molotovs = 2;
      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      void throwOne() {
        game.input
          ..selectWeapon(Weapon.molotov)
          ..beginAim()
          ..throwMolotov();
        play(1);
      }

      play(0.1);
      throwOne();
      expect(ammo.molotovs, 1);
      expect(game.input.weapon.value, Weapon.molotov);

      throwOne();
      expect(ammo.molotovs, 0);
      expect(game.input.weapon.value, Weapon.pistol);
    });
  });

  testWidgets('the bullets sit in the row of carried things, and a tap '
      'tells of them', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester)
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

      // The count is written over the bottom-left corner, spilling past it.
      final box = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo')),
      );
      final count = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo-count')),
      );
      expect(count.left, lessThan(box.left));
      expect(count.bottom, greaterThan(box.bottom));
      expect(count.right, greaterThan(box.left));
      expect(count.top, lessThan(box.bottom));

      // The pistol found, the badge wakes up; the only weapon, it does
      // not burn: there is nothing to choose between.
      game.simulation.player.component<AmmoComponent>().hasGun = true;
      game.update(1 / 60);
      await tester.pump();
      expect(borderOf(badge()).top.color, BloodColors.fresh);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('touch-ammo')),
          matching: find.byType(FireFrame),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('touch-ammo')));
      await tester.pump();
      expect(find.text('3 proiettili'), findsOneWidget);
      game.dismissPrompt();
      await tester.pump();

      // One row, from the right edge in the order things were picked up.
      final bullets = tester.getRect(
        find.byKey(const ValueKey<String>('touch-ammo')),
      );
      final incense = tester.getRect(
        find.byKey(const ValueKey<String>('hud-incense')),
      );
      expect(incense.right, lessThanOrEqualTo(bullets.left));
      expect(bullets.top, incense.top);
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

  testWidgets('every object Mario can interact with glints like a backpack, '
      'once the button is there to press', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
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
        ...world.lookouts.where(
          (tile) =>
              tile != trainLuigiTile &&
              tile != chiaraTile &&
              tile != trainChiaraTile,
        ),
        ...world.controls.keys,
        // What the scripts answer when interacted with.
        barLockedDoorTile,
        duomoUpperLockedDoorTile,
        stationTrainDoorTile,
      ]) {
        expect(glinted(tile), isTrue, reason: 'nothing glints near $tile');
      }
      // Only objects glint: Luigi and Chiara, whom Mario talks to, do not.
      expect(glints.where((glint) => tileOf(glint) == trainLuigiTile), isEmpty);
      expect(glints.where((glint) => tileOf(glint) == chiaraTile), isEmpty);
      expect(
        glints.where((glint) => tileOf(glint) == trainChiaraTile),
        isEmpty,
      );
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

  testWidgets('the missions and what Mario carries show only while he is '
      'free to move, and a mission done is crossed out and goes', (tester) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await pumpReadyGame(tester, audio: audio);
      double opacityOf(Mission mission) => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(
                    ValueKey<String>('mission-text-${mission.name}'),
                  ),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      final board = find.byKey(const ValueKey<String>('mission-board'));
      Finder mission(Mission mission) =>
          find.byKey(ValueKey<String>('mission-text-${mission.name}'));
      Future<void> frame() async {
        game.update(1 / 60);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await frame();
      expect(game.freeToMove.value, isTrue);
      expect(board, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mission-board-city')),
        findsOneWidget,
      );
      expect(mission(Mission.findSurvivors), findsOneWidget);

      // Something about to be said: the corner empties before the box.
      game.story.queue(
        StoryPrompt(const <StoryLine>[StoryLine('Un messaggio')], delay: 5),
      );
      await frame();
      expect(game.freeToMove.value, isFalse);
      expect(board, findsNothing);

      // Done while the story holds Mario: crossed out once he is free.
      game.progress.missions
        ..complete(Mission.findSurvivors)
        ..give(Mission.freeLuigi);
      for (var i = 0; i < 400 && game.cover.value == null; i++) {
        game.update(0.05);
      }
      await tester.pump();
      game
        ..dismissPrompt()
        ..update(1 / 60);
      await tester.pump();
      // Back after the dialogue: the mission it already showed is just
      // there, only the new one fades in.
      expect(opacityOf(Mission.findSurvivors), 1);
      expect(opacityOf(Mission.freeLuigi), lessThan(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(board, findsOneWidget);
      expect(mission(Mission.findSurvivors), findsOneWidget);
      expect(mission(Mission.freeLuigi), findsOneWidget);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(mission(Mission.findSurvivors), findsNothing);
      expect(mission(Mission.freeLuigi), findsOneWidget);
      // A pen scratch for each stroke of the cross.
      expect(audio.played.where((sfx) => sfx == Sfx.penStroke), hasLength(2));
      expect(game.missions.value, <BoardMission>[
        (mission: Mission.freeLuigi, done: false),
      ]);
    });
  });

  testWidgets('a mission handed out and done at once still shows, crossed '
      'out, and the story waits for it', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester, audio: SilentAudio());
      final text = find.byKey(
        ValueKey<String>('mission-text-${Mission.freeLuigi.name}'),
      );
      Future<void> frame([double dt = 1 / 60]) async {
        game.update(dt);
        await tester.pump();
      }

      await frame();
      expect(game.freeToMove.value, isTrue);
      expect(game.missionsSettling, isFalse);

      // Luigi's shutter lifted before his scene.
      game.progress.missions
        ..give(Mission.freeLuigi)
        ..complete(Mission.freeLuigi);
      await frame();
      expect(
        game.missions.value,
        contains((mission: Mission.freeLuigi, done: true)),
      );
      expect(game.missionsSettling, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(text, findsOneWidget, reason: 'the corner shows it');

      for (var i = 0; i < 12; i++) {
        await frame(0.25);
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(text, findsNothing, reason: 'crossed out, and gone');
      expect(game.missionsSettling, isFalse);
      expect(game.progress.missions.done, contains(Mission.freeLuigi));
    });
  });
}
