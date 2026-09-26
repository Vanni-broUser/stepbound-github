import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';

void main() {
  const width = IntegerResolutionViewport.virtualWidth;
  const height = IntegerResolutionViewport.virtualHeight;
  final street = place(PlaceId.street);
  // Somewhere the whole view fits inside the street on every side.
  final area = pixelRect(street.bounds);
  final middle = Vector2(area.center.dx, area.center.dy);

  late CameraComponent camera;
  late FollowCamera follow;

  setUp(() {
    camera = CameraComponent(
      viewport: FixedResolutionViewport(resolution: Vector2(width, height)),
    );
    follow = FollowCamera(camera)..snapTo(middle, street);
  });

  /// What the camera shows, in world pixels.
  Rect shown() {
    final zoom = camera.viewfinder.zoom;
    return Rect.fromCenter(
      center: Offset(
        camera.viewfinder.position.x,
        camera.viewfinder.position.y,
      ),
      width: width / zoom,
      height: height / zoom,
    );
  }

  test('two fingers zoom toward the point they pinch, which stays put on '
      'the screen', () {
    final whole = shown();
    follow
      ..beginPinch(const Offset(0.25, 0.75))
      ..pinch(1.5, const Offset(0.3, 0.7));
    expect(follow.zoom, 1.5);
    final zoomed = shown();
    expect(zoomed.width, closeTo(whole.width / 1.5, 0.01));
    // The pinched point is as far across the zoomed view as the whole one.
    final pinched = Offset(
      whole.left + whole.width * 0.25,
      whole.top + whole.height * 0.75,
    );
    expect((pinched.dx - zoomed.left) / zoomed.width, closeTo(0.25, 0.001));
    expect((pinched.dy - zoomed.top) / zoomed.height, closeTo(0.75, 0.001));
    expect(whole.contains(zoomed.topLeft), isTrue);
    expect(whole.contains(zoomed.bottomRight - const Offset(1, 1)), isTrue);
  });

  test('no further than twice as close, and the view never pans: a pinch '
      'somewhere else keeps the point the zoom went toward', () {
    follow
      ..beginPinch(const Offset(0.2, 0.2))
      ..pinch(5, const Offset(0.2, 0.2))
      ..endPinch();
    expect(follow.zoom, FollowCamera.maxZoom);
    final zoomed = shown();

    follow
      ..beginPinch(const Offset(0.9, 0.9))
      ..pinch(0.8, const Offset(0.9, 0.9));
    expect(follow.zoom, closeTo(1.6, 0.001));
    // Still toward the top left: moving the fingers did not move the view.
    follow.pinch(1, const Offset(0.5, 0.5));
    expect(shown(), zoomed);
  });

  test('back out all the way, the next zoom goes where the fingers are', () {
    follow
      ..beginPinch(const Offset(0.1, 0.5))
      ..pinch(2, const Offset(0.1, 0.5))
      ..endPinch()
      ..beginPinch(const Offset(0.5, 0.5))
      // All the way out, and on past it...
      ..pinch(0.4, const Offset(0.9, 0.5));
    expect(follow.zoom, 1);
    // ...then apart again from there, around the other side.
    follow.pinch(0.6, const Offset(0.9, 0.5));
    expect(follow.zoom, closeTo(1.5, 0.001));
    final whole = Rect.fromCenter(
      center: Offset(middle.x, middle.y),
      width: width,
      height: height,
    );
    // The point the fingers were on stays nine tenths of the way across.
    final pinched = whole.left + whole.width * 0.9;
    expect((pinched - shown().left) / shown().width, closeTo(0.9, 0.001));
  });

  test('let go nearly all the way out, it is the whole view', () {
    follow
      ..beginPinch(const Offset(0.5, 0.5))
      ..pinch(1.05, const Offset(0.5, 0.5))
      ..endPinch();
    expect(follow.zoom, 1);
    expect(camera.viewfinder.zoom, 1);
  });

  test('Mario is never left outside a zoomed view', () {
    follow
      ..beginPinch(Offset.zero)
      ..pinch(2, Offset.zero);
    // Well to the south-east, where the zoom did not go.
    final mario = middle + Vector2(40, 28);
    follow.follow(1 / 30, player: mario, place: street);
    final view = shown().deflate(FollowCamera.zoomMargin - 0.01);
    expect(view.contains(Offset(mario.x, mario.y)), isTrue);
  });

  test('changing place, or a character to frame, brings the whole view '
      'back', () {
    follow
      ..beginPinch(const Offset(0.5, 0.5))
      ..pinch(2, const Offset(0.5, 0.5))
      ..endPinch()
      ..follow(1 / 30, player: middle, place: place(PlaceId.barracks));
    expect(follow.zoom, 1);
    expect(camera.viewfinder.zoom, 1);

    follow
      ..beginPinch(const Offset(0.5, 0.5))
      ..pinch(2, const Offset(0.5, 0.5))
      ..endPinch()
      ..follow(
        1 / 30,
        player: middle,
        place: place(PlaceId.barracks),
        focus: middle + Vector2(32, 0),
      );
    expect(follow.zoom, 1);
  });
}
