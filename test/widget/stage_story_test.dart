import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/crucified_zombie_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/portrait_image.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets("Luigi's music waits for the reunion on the far platform", (
    tester,
  ) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await pumpReadyGame(tester, audio: audio);
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

  testWidgets('with the hook, the line comes first, and Mario swings '
      'across, the hook thrown and its sound with it, the moment it is '
      'dismissed', (tester) {
    return tester.runAsync(() async {
      final audio = SilentAudio();
      final game = await pumpReadyGame(tester, audio: audio);
      final edge = duomoTowerLookoutTile;
      final over = game.simulation.grapples[edge]!;
      game.unlock(HudElement.interact);
      game.simulation.player.component<AmmoComponent>().grapplingHook = true;
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = edge.step(over.facing.opposite)
        ..facing = over.facing;
      final from = mario.position;
      game.update(1 / 60);
      audio.played.clear();

      game.input.pressInteract();
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      await tester.pump();
      expect(
        (game.cover.value! as PromptCover).lines.single.text,
        RooftopsScript.grappleLine,
      );
      expect(mario.position, from, reason: 'not over yet');
      expect(game.presentation.isAnimating, isFalse);
      expect(audio.played, isNot(contains(Sfx.grapple)));

      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      expect(game.cover.value, isNull);
      expect(mario.position, over.to, reason: 'set off at once');
      expect(game.presentation.isAnimating, isTrue);
      game.update(1 / 60);
      expect(audio.played, contains(Sfx.grapple));
      expect(game.isPromptVisible, isFalse, reason: 'said once, before');
    });
  });

  testWidgets('Mario waits while Luigi walks out of the hypermarket, and '
      'the tile Luigi stood on is free once he has gone', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
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
      tapOn(game, Direction.east);
      game.update(0.3);
      expect(mario.position, start, reason: 'not while Luigi is walking');

      for (var i = 0; i < 400 && !gone; i++) {
        game.update(0.05);
      }
      expect(gone, isTrue);
      expect(map.tileAt(luigiTile).isWalkable, isTrue, reason: 'he has gone');
      tapOn(game, Direction.east);
      game.update(0.3);
      expect(mario.position, start.step(Direction.east));
    });
  });

  testWidgets('nobody walks through the people at the Duomo', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
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

  testWidgets('the mass leaves four cultists across the nave, Don Angelo '
      'dead and the key beside him', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
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
      final game = await pumpReadyGame(tester, audio: audio);
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
      final game = await pumpReadyGame(tester);
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
      final game = await pumpReadyGame(tester);
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
      final portrait = tester.widget<PortraitImage>(
        find.byKey(const ValueKey<String>('dialogue-portrait-0')),
      );
      expect(portrait.asset, PlayerOutfit.cultist.portrait);
    });
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
}
