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

/// Keeps Mario in the middle of the view, frame by frame as he walks,
/// inside the place he is in -- or, where the place declares a camera
/// zone, inside that zone's limits (see [CameraZone]): there the view
/// stops as at the edge of the place. Walking from one zone into another,
/// the limits slide over to the new ones in a fraction of a second rather
/// than jumping. A place smaller than the view sits centred on the dark
/// background.
///
/// Two fingers can bring the view closer (see [beginPinch]): it zooms
/// toward the point they were pinched on and stays there, it does not
/// pan. Changing place puts it back, and so does [showWholeView].
final class FollowCamera {
  FollowCamera(this.camera);

  /// How far above his feet the middle of Mario is: that is what the view
  /// centres on, not his feet, or he would stand in its upper half.
  static const double bodyHeight = 12;

  /// How close two fingers can bring the view.
  static const double maxZoom = 2;

  /// A pinch let go closer than this to the whole view goes back to it.
  static const double snapBackZoom = 1.08;

  /// How far inside a zoomed view Mario always stays, in pixels.
  static const double zoomMargin = 16;

  /// How fast the edges the view stops at slide to a new camera zone's:
  /// most of the way in about a third of a second.
  static const double limitsRate = 9;

  final CameraComponent camera;
  Place? _place;

  /// The edges the view is kept inside, in pixels, on their way to
  /// [_targetLimits] when Mario has changed camera zone.
  Rect _limits = Rect.zero;
  Rect _targetLimits = Rect.zero;

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

  /// Back to the whole view, still around Mario: a zombie met for the first
  /// time is framed in it wherever it is noticed from.
  void showWholeView() {
    _zoom = 1;
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
    _limits = _targetLimits = _limitsFor(player, place);
    _centre = _rounded(_body(player));
    _clamp();
    _show(player);
  }

  /// The edges the view stops at with Mario's feet at [player]: the
  /// limits of the camera zone of the tile he stands on.
  static Rect _limitsFor(Vector2 player, Place place) => pixelRect(
    place.cameraLimitsAt(
      GridPoint((player.x / 16).floor(), ((player.y - 1) / 16).floor()),
    ),
  );

  static Vector2 _body(Vector2 feet) => Vector2(feet.x, feet.y - bodyHeight);

  static Vector2 _rounded(Vector2 point) =>
      Vector2(point.x.roundToDouble(), point.y.roundToDouble());

  /// One frame of following [player], [dt] seconds after the last: a new
  /// place is snapped to, with the whole view, like the first one. Without
  /// [dt], a change of camera zone is not slid over to but taken at once.
  void follow({required Vector2 player, required Place place, double? dt}) {
    if (place != _place) {
      snapTo(player, place);
      return;
    }
    _targetLimits = _limitsFor(player, place);
    if (dt == null) {
      _limits = _targetLimits;
    } else if (_limits != _targetLimits) {
      final t = 1 - math.exp(-limitsRate * dt);
      final next = Rect.lerp(_limits, _targetLimits, t)!;
      // Close enough: there, so it stops moving by fractions of a pixel.
      final off =
          (next.left - _targetLimits.left).abs() +
          (next.top - _targetLimits.top).abs() +
          (next.right - _targetLimits.right).abs() +
          (next.bottom - _targetLimits.bottom).abs();
      _limits = off < 0.5 ? _targetLimits : next;
    }
    _centre = _rounded(_body(player));
    _clamp();
    _show(player);
  }

  void _clamp() {
    final area = _limits;
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
