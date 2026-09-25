import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';

/// The area of the world, in pixels, that [bounds] covers.
Rect pixelRect(GridRect bounds, {double tileSize = 16}) => Rect.fromLTRB(
  bounds.left * tileSize,
  bounds.top * tileSize,
  (bounds.right + 1) * tileSize,
  (bounds.bottom + 1) * tileSize,
);

/// Follows Mario with a dead zone, inside the place he is in; while a
/// character is in focus it frames the two together. It glides to its
/// target, so switching focus never jumps, but snaps when Mario changes
/// place. A place smaller than the view sits centred on the dark
/// background.
final class FollowCamera {
  FollowCamera(this.camera);

  static const double deadZoneHalfWidth = 48;
  static const double deadZoneHalfHeight = 32;
  static const double panSpeed = 260;

  final CameraComponent camera;
  Place? _place;

  /// Centres on [player] (his feet, in pixels) inside [place].
  void snapTo(Vector2 player, Place place) {
    _place = place;
    camera.viewfinder.position = Vector2(
      player.x.roundToDouble(),
      player.y.roundToDouble(),
    );
    _clamp(place);
  }

  /// One frame of following [player], framed with [focus] if there is one.
  void follow(
    double dt, {
    required Vector2 player,
    required Place place,
    Vector2? focus,
  }) {
    if (place != _place) {
      snapTo(player, place);
      return;
    }
    final current = camera.viewfinder.position.clone();
    final Vector2 target;
    if (focus != null) {
      target = (player + focus)..scale(0.5);
    } else {
      target = current.clone();
      final differenceX = player.x - current.x;
      final differenceY = player.y - current.y;
      if (differenceX.abs() > deadZoneHalfWidth) {
        target.x = player.x - differenceX.sign * deadZoneHalfWidth;
      }
      if (differenceY.abs() > deadZoneHalfHeight) {
        target.y = player.y - differenceY.sign * deadZoneHalfHeight;
      }
    }
    final offset = target - current;
    final maxStep = panSpeed * dt;
    if (offset.length > maxStep) {
      offset.scaleTo(maxStep);
    }
    final next = current + offset;
    camera.viewfinder.position = Vector2(
      next.x.roundToDouble(),
      next.y.roundToDouble(),
    );
    _clamp(place);
  }

  void _clamp(Place place) {
    final position = camera.viewfinder.position;
    final area = pixelRect(place.bounds);
    const halfWidth = IntegerResolutionViewport.virtualWidth / 2;
    const halfHeight = IntegerResolutionViewport.virtualHeight / 2;
    final x = area.width <= halfWidth * 2
        ? area.center.dx
        : position.x.clamp(area.left + halfWidth, area.right - halfWidth);
    final y = area.height <= halfHeight * 2
        ? area.center.dy
        : position.y.clamp(area.top + halfHeight, area.bottom - halfHeight);
    camera.viewfinder.position = Vector2(x, y);
  }
}
