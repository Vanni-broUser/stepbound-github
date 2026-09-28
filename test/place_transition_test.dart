import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/place_transition_controller.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';

/// Where the game's portals lead, as the transitions see them.
final class _Doors {
  _Doors() {
    final portals = createGameWorld().portals;
    for (final MapEntry(key: from, value: portal) in portals.entries) {
      final origin = placeAt(from);
      final destination = placeAt(portal.to);
      if (destination == null || origin == null) {
        continue;
      }
      if (destination.cardImage != null &&
          destination != origin &&
          !origin.indoor) {
        byRoadToCard ??= (from: from, to: portal.to);
      }
      if (destination.indoor && !origin.indoor) {
        intoBuilding ??= (from: from, to: portal.to);
      }
      if (!destination.indoor && origin.indoor) {
        outOfBuilding ??= (from: from, to: portal.to);
      }
    }
  }

  ({GridPoint from, GridPoint to})? byRoadToCard;
  ({GridPoint from, GridPoint to})? intoBuilding;
  ({GridPoint from, GridPoint to})? outOfBuilding;
}

void main() {
  late ValueNotifier<GameCover?> cover;
  late List<GameCover> shown;
  late List<double> fades;
  late int stops;
  late PlaceTransitionController transitions;
  final doors = _Doors();

  setUp(() {
    cover = ValueNotifier<GameCover?>(null);
    shown = <GameCover>[];
    fades = <double>[];
    stops = 0;
    transitions = PlaceTransitionController(
      cover: cover,
      show: (what) {
        shown.add(what);
        cover.value = what;
      },
      fadeScreen: ({required fadeIn}) => fades.add(fadeIn),
      stopInput: () => stops++,
    );
  });

  tearDown(() => cover.dispose());

  test('the level has a road into a place with a card, a door in and out', () {
    expect(doors.byRoadToCard, isNotNull);
    expect(doors.intoBuilding, isNotNull);
    expect(doors.outOfBuilding, isNotNull);
  });

  test('a road into a place with a card puts the card up', () {
    final road = doors.byRoadToCard!;
    transitions.goThrough(from: road.from, to: road.to);
    final destination = placeAt(road.to)!;
    expect(
      shown.single,
      isA<PlaceCardCover>()
          .having((card) => card.name, 'name', destination.name)
          .having((card) => card.image, 'image', destination.cardImage),
    );
    expect(fades, isEmpty, reason: 'the card fades, not the screen');
    expect(transitions.threshold, road.from);
    expect(transitions.inTransit, isTrue);
    expect(transitions.holdsMario, isFalse);
  });

  test('Mario is drawn on the threshold until the card is black', () {
    final road = doors.byRoadToCard!;
    transitions.goThrough(from: road.from, to: road.to);
    expect(transitions.drawnAt(playerMoving: false), road.from);
    expect(
      transitions.drawnAt(playerMoving: true),
      isNull,
      reason: 'a step being played is drawn where it goes',
    );
    transitions.cardBlack();
    expect(transitions.threshold, isNull);
    expect(transitions.inTransit, isFalse);
    expect(cover.value, isA<PlaceCardCover>(), reason: 'still fading in');
    transitions.dismissCard();
    expect(cover.value, isNull);
  });

  test('dismissing the card takes down only a card', () {
    cover.value = const ZombieBookCover();
    transitions.dismissCard();
    expect(cover.value, isA<ZombieBookCover>());
  });

  test('a door into a building fades slowly and holds Mario a moment', () {
    final door = doors.intoBuilding!;
    transitions.goThrough(from: door.from, to: door.to);
    expect(shown, isEmpty);
    expect(fades, <double>[ScreenFadeComponent.slowFadeIn]);
    expect(stops, 1);
    expect(transitions.holdsMario, isTrue);
    expect(transitions.inTransit, isFalse);
    transitions.update(PlaceTransitionController.entranceHoldSeconds / 2);
    expect(transitions.holdsMario, isTrue);
    transitions.update(PlaceTransitionController.entranceHoldSeconds / 2);
    expect(transitions.holdsMario, isFalse);
  });

  test('coming back out is a short fade, no card, no hold', () {
    final door = doors.outOfBuilding!;
    transitions.goThrough(from: door.from, to: door.to);
    expect(shown, isEmpty, reason: 'leaving a building is no arrival');
    expect(fades, <double>[ScreenFadeComponent.defaultFadeIn]);
    expect(stops, 0);
    expect(transitions.holdsMario, isFalse);
  });

  test('a card is only for a place reached by road', () {
    final road = doors.byRoadToCard!;
    final withCard = placeAt(road.to)!;
    var origin = gamePlaces.firstWhere((candidate) => candidate.indoor);
    final fromOrigin = PlaceTransitionController(
      cover: cover,
      show: shown.add,
      fadeScreen: ({required fadeIn}) => fades.add(fadeIn),
      stopInput: () => stops++,
      placeOf: (tile) => tile == road.to ? withCard : origin,
    )..goThrough(from: road.from, to: road.to);
    expect(shown, isEmpty, reason: 'out of its own building: no card');
    expect(fades, <double>[ScreenFadeComponent.defaultFadeIn]);
    origin = place(PlaceId.street);
    fromOrigin.goThrough(from: road.from, to: road.to);
    expect(shown.single, isA<PlaceCardCover>());
  });

  test('the place shown is the one under Mario’s feet', () {
    final street = place(PlaceId.street);
    final tile = GridPoint(street.bounds.left + 1, street.bounds.top + 1);
    final feet = Vector2(
      tile.x * levelTileSize + levelTileSize / 2,
      tile.y * levelTileSize + levelTileSize,
    );
    expect(transitions.placeShown(feet), street);
    expect(
      transitions.placeShown(Vector2(-1000, -1000)),
      street,
      reason: 'nowhere is the street',
    );
  });
}
