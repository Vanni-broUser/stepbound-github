import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/asset_image.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/render/offscreen_culled.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/tile_place_component.dart';
import 'package:stepbound/game/render/torch_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('walking into the barracks holds Mario still for a moment', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      final position = game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      void stepNorth() {
        tapOn(game, Direction.north);
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
      final game = await pumpReadyGame(tester);
      game.update(1 / 30);
      expect(game.drawnPlaces, <String>['tiles:street']);

      game.simulation.player.component<PositionComponent>()
        ..position = const GridPoint(16, 7)
        ..facing = Direction.north;
      tapOn(game, Direction.north);
      game.update(0.3);
      // The barracks are painted from the tile atlas: no picture to name.
      expect(game.drawnPlaces, <String>['tiles:barracks']);
    });
  });

  testWidgets('only the fires in view are drawn', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      game.update(1 / 30);
      final view = game.camera.visibleWorldRect;
      final culled = game.world.children.whereType<OffscreenCulled>().toList();
      expect(culled.whereType<FireComponent>(), isNotEmpty);
      // The Duomo's torches are an area away, down at the harbour: not in
      // the world at all, let alone drawn.
      expect(culled.whereType<TorchComponent>(), isEmpty);
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

      final first = imagesOf(await pumpReadyGame(tester));
      await tester.pumpWidget(const SizedBox());
      final second = imagesOf(await pumpReadyGame(tester));
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
      await game.areaSettled;
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
      // What stands in the places comes and goes with them: the Duomo's
      // torches are in now, and no backpack lies in a place let go.
      expect(game.world.children.whereType<TorchComponent>(), isNotEmpty);
      for (final backpack in game.world.children.whereType<PickupComponent>()) {
        expect(
          game.loadedPlaces,
          contains(placeAt(backpack.pickup.position)!.id),
        );
      }
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
    // The station's own places, the train, and the two streets one door
    // out of it: nothing of Molfetta.
    expect(
      PlaceLayers.kept(
        place(PlaceId.romeTermini),
        gamePlaces,
        world.portals,
      ).map((place) => place.id),
      unorderedEquals(<PlaceId>[
        PlaceId.romeTermini,
        PlaceId.terminiOverpass,
        PlaceId.terminiFarPlatform,
        PlaceId.terminiConcourse,
        PlaceId.trainInterior,
        PlaceId.piazzaCinquecento,
        PlaceId.viaMarsala,
      ]),
    );
  });

  testWidgets('coming back out of the Bar Arcobaleno onto the harbour shows '
      'no card', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      final door = place(PlaceId.barArcobaleno).tileOf('E');
      game.simulation.player.component<PositionComponent>()
        ..position = door.step(Direction.north)
        ..facing = Direction.south;
      game.update(1);
      tapOn(game, Direction.south);
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
      final game = await pumpReadyGame(tester);
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

      tapOn(game, Direction.south);
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
}
