import 'dart:math' as math;
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
///
/// Two fingers can bring the view closer (see [beginPinch]): it zooms
/// toward the point they were pinched on and stays there, it does not
/// pan. Changing place, or a character coming into focus, puts it back.
final class FollowCamera {
  FollowCamera(this.camera);

  static const double deadZoneHalfWidth = 48;
  static const double deadZoneHalfHeight = 32;
  static const double panSpeed = 260;

  /// How close two fingers can bring the view.
  static const double maxZoom = 2;

  /// A pinch let go closer than this to the whole view goes back to it.
  static const double snapBackZoom = 1.08;

  /// How far inside a zoomed view Mario always stays, in pixels.
  static const double zoomMargin = 16;

  final CameraComponent camera;
  Place? _place;

  /// How many screen pixels a world pixel takes, before any pinch: the
  /// same on both axes, so nothing is stretched.
  double get screenScale {
    final screen = camera.viewport.size;
    if (screen.x <= 0 || screen.y <= 0) {
      return 1;
    }
    final view = IntegerResolutionViewport.worldViewFor(screen.x, screen.y);
    return math.min(screen.x / view.width, screen.y / view.height);
  }

  /// How much of the world the whole view shows, in pixels: the screen's
  /// shape, about as much ground as the 16:9 view on any screen (see
  /// [IntegerResolutionViewport.worldViewFor]).
  Vector2 get _view {
    final screen = camera.viewport.size;
    if (screen.x <= 0 || screen.y <= 0) {
      return Vector2(
        IntegerResolutionViewport.virtualWidth,
        IntegerResolutionViewport.virtualHeight,
      );
    }
    return screen / screenScale;
  }

  /// The view as it would be without zoom: its centre.
  Vector2 _centre = Vector2.zero();

  /// Mario's feet, as last followed: a zoom keeps him in the picture.
  Vector2 _player = Vector2.zero();

  double _zoom = 1;
  double _pinchStartZoom = 1;

  /// Where on the whole view the zoom goes toward, as a fraction of its
  /// width and height: that point stays put on the screen.
  Offset _anchor = const Offset(0.5, 0.5);

  /// 1 for the whole view, up to [maxZoom].
  double get zoom => _zoom;

  /// Two fingers have come down on [focus] (a fraction of the view). A
  /// view already zoomed keeps the point it went toward: to go toward
  /// another, it has to come all the way back out first.
  void beginPinch(Offset focus) {
    _pinchStartZoom = _zoom;
    if (_zoom == 1) {
      _anchor = _fraction(focus);
    }
  }

  /// The fingers are [scale] times as far apart as when they came down,
  /// now around [focus].
  void pinch(double scale, Offset focus) {
    _zoom = (_pinchStartZoom * scale).clamp(1, maxZoom).toDouble();
    if (_zoom == 1) {
      // All the way out: zooming back in goes where the fingers are now.
      _anchor = _fraction(focus);
      _pinchStartZoom = 1 / scale;
    }
    _show(_player);
  }

  /// The fingers have lifted: nearly the whole view is the whole view.
  void endPinch() {
    if (_zoom < snapBackZoom) {
      _zoom = 1;
    }
    _show(_player);
  }

  static Offset _fraction(Offset focus) =>
      Offset(focus.dx.clamp(0, 1).toDouble(), focus.dy.clamp(0, 1).toDouble());

  /// Centres on [player] (his feet, in pixels) inside [place], with the
  /// whole view.
  void snapTo(Vector2 player, Place place) {
    _place = place;
    _zoom = 1;
    _centre = Vector2(player.x.roundToDouble(), player.y.roundToDouble());
    _clamp(place);
    _show(player);
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
    final current = _centre.clone();
    final Vector2 target;
    if (focus != null) {
      // Both have to be in the picture.
      _zoom = 1;
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
    _centre = Vector2(next.x.roundToDouble(), next.y.roundToDouble());
    _clamp(place);
    _show(player);
  }

  void _clamp(Place place) {
    final area = pixelRect(place.bounds);
    final halfWidth = _view.x / 2;
    final halfHeight = _view.y / 2;
    final x = area.width <= halfWidth * 2
        ? area.center.dx
        : _centre.x.clamp(area.left + halfWidth, area.right - halfWidth);
    final y = area.height <= halfHeight * 2
        ? area.center.dy
        : _centre.y.clamp(area.top + halfHeight, area.bottom - halfHeight);
    _centre = Vector2(x, y);
  }

  /// Points the camera: the whole view around [_centre], or the part of it
  /// the zoom goes toward, moved only as far as it takes to keep [player]
  /// in it.
  void _show(Vector2 player) {
    _player = player.clone();
    final width = _view.x;
    final height = _view.y;
    final shrink = 1 - 1 / _zoom;
    var x = _centre.x + (_anchor.dx - 0.5) * width * shrink;
    var y = _centre.y + (_anchor.dy - 0.5) * height * shrink;
    if (_zoom > 1) {
      final halfWidth = width / 2 / _zoom;
      final halfHeight = height / 2 / _zoom;
      x = _keep(x, player.x, halfWidth);
      y = _keep(y, player.y, halfHeight);
      // Never past the edges of the whole view.
      x = x.clamp(
        _centre.x - width / 2 + halfWidth,
        _centre.x + width / 2 - halfWidth,
      );
      y = y.clamp(
        _centre.y - height / 2 + halfHeight,
        _centre.y + height / 2 - halfHeight,
      );
    }
    camera.viewfinder
      ..zoom = screenScale * _zoom
      ..position = Vector2(x, y);
  }

  /// [centre] moved just enough for [point] to be [zoomMargin] inside a
  /// view [half] wide on each side of it.
  static double _keep(double centre, double point, double half) {
    final reach = half - zoomMargin;
    if (point < centre - reach) {
      return point + reach;
    }
    if (point > centre + reach) {
      return point - reach;
    }
    return centre;
  }
}
