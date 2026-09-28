import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';

/// Mario's way from one place into the next: the fade through a door or
/// along a road, the card that announces a place reached by road, the
/// moment he stands still on the threshold of a building, and where he is
/// drawn while a card fades to black, so the camera keeps showing the
/// place he is leaving. The game asks it every frame, and the card
/// overlay tells it when the screen is black and when the card is gone.
final class PlaceTransitionController {
  PlaceTransitionController({
    required this.cover,
    required this.show,
    required this.fadeScreen,
    required this.stopInput,
    this.placeOf = placeAt,
  });

  /// How long Mario stands still on the threshold of a building, so the
  /// place he has just walked into can sink in.
  static const double entranceHoldSeconds = 2.2;

  /// What covers the game, if anything: the card goes up here, and is
  /// taken down from here.
  final ValueNotifier<GameCover?> cover;

  /// Puts [GameCover] over the game the way the game does it (Mario stops).
  final void Function(GameCover cover) show;

  /// Fades the screen to black and back in over `fadeIn` seconds.
  final void Function({required double fadeIn}) fadeScreen;

  /// Drops the steps queued and the arrow held.
  final void Function() stopInput;

  /// The place a tile belongs to, if any; the level's own layout by
  /// default, another one in tests.
  final Place? Function(GridPoint tile) placeOf;

  GridPoint? _threshold;
  double _holdLeft = 0;

  /// Where Mario is drawn while a place card fades to black, if one does:
  /// the tile he stepped through from.
  GridPoint? get threshold => _threshold;

  /// True while a card is on its way to black: the game cannot be put down
  /// in between (see `StepboundGame.canBeSuspended`).
  bool get inTransit => _threshold != null;

  /// True while Mario stands still on a building's threshold.
  bool get holdsMario => _holdLeft > 0;

  void update(double dt) {
    if (_holdLeft > 0) {
      _holdLeft -= dt;
    }
  }

  /// A door or a road into another place: a short fade to black (a slower
  /// one into a building, where Mario then stands still a moment), or,
  /// into a place with a card, its picture and name. The card only
  /// announces a place reached by road: coming back out of one of its own
  /// buildings is no arrival. Until the card's fade has gone black Mario
  /// is still drawn on the [from] threshold.
  void goThrough({required GridPoint from, required GridPoint to}) {
    final destination = placeOf(to);
    final origin = placeOf(from);
    if (destination?.cardImage != null &&
        destination != origin &&
        !(origin?.indoor ?? false)) {
      _threshold = from;
      show(
        PlaceCardCover(
          name: destination!.name ?? '',
          image: destination.cardImage!,
        ),
      );
      return;
    }
    final entering = destination?.indoor ?? false;
    fadeScreen(
      fadeIn: entering
          ? ScreenFadeComponent.slowFadeIn
          : ScreenFadeComponent.defaultFadeIn,
    );
    if (entering) {
      stopInput();
      _holdLeft = entranceHoldSeconds;
    }
  }

  /// Called by the card overlay once the screen is black: Mario moves to
  /// the new place behind it.
  void cardBlack() => _threshold = null;

  /// Called by the card overlay once the new place has faded in.
  void dismissCard() {
    _threshold = null;
    if (cover.value is PlaceCardCover) {
      cover.value = null;
    }
  }

  /// The tile Mario is drawn on instead of where the simulation has him:
  /// the threshold, while a card goes black and he is not taking a step.
  GridPoint? drawnAt({required bool playerMoving}) =>
      playerMoving ? null : _threshold;

  /// The place Mario is drawn in, from where his [feet] are (it changes
  /// once the step through a door has finished playing).
  Place placeShown(Vector2 feet) {
    final tile = GridPoint(
      (feet.x / levelTileSize).floor(),
      ((feet.y - 1) / levelTileSize).floor(),
    );
    return placeOf(tile) ?? place(PlaceId.street);
  }
}
