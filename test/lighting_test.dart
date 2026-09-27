import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide PositionComponent;
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/lighting_component.dart';

/// A room of 12 by 8 tiles with one lamp of each kind, and a torch close
/// enough to a flickering lamp for their pools to overlap.
const ui.Rect _room = ui.Rect.fromLTWH(32, 16, 192, 128);
const List<LightSpot> _lights = <LightSpot>[
  LightSpot(GridPoint(4, 2)),
  LightSpot(GridPoint(9, 4), flickers: true),
  LightSpot(GridPoint(11, 3), torch: true),
  LightSpot(GridPoint(3, 6), flickers: true),
];

LightingComponent _lighting(Vector2 feet) => LightingComponent(
  area: _room,
  lights: _lights,
  playerPosition: () => feet,
  darkness: 0.8,
);

/// The component drawn over a flat grey floor, as pixels.
Future<Uint8List> _pixels(LightingComponent lighting) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      const ui.Rect.fromLTWH(0, 0, 256, 160),
      ui.Paint()..color = const ui.Color(0xff808080),
    );
  lighting.renderTree(canvas);
  final image = await recorder.endRecording().toImage(256, 160);
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// How many pixels of [a] and [b] differ by more than [tolerance] in any
/// channel.
int _differing(Uint8List a, Uint8List b, {int tolerance = 2}) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var channel = 0; channel < 4; channel++) {
      if ((a[i + channel] - b[i + channel]).abs() > tolerance) {
        count++;
        break;
      }
    }
  }
  return count;
}

void main() {
  testWidgets('the composed darkness draws what the live one drew', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final feet in <Vector2>[
        // By the steady lamp, out of every live pool.
        Vector2(100, 60),
        // On the torch, whose pool overlaps the flickering lamp's.
        Vector2(210, 80),
        // Outside the room altogether.
        Vector2(10, 150),
      ]) {
        final live = _lighting(feet);
        final baked = _lighting(feet);
        await baked.onLoad();
        for (var frame = 0; frame < 7; frame++) {
          live.update(0.05);
          baked.update(0.05);
          final expected = await _pixels(live);
          final actual = await _pixels(baked);
          expect(
            _differing(expected, actual),
            lessThan(256 * 160 ~/ 500),
            reason: 'frame $frame with Mario at $feet',
          );
        }
        baked.onRemove();
      }
    });
  });

  testWidgets('the darkness is lifted where the lamps are', (tester) async {
    await tester.runAsync(() async {
      final lighting = _lighting(Vector2(100, 60));
      await lighting.onLoad();
      final pixels = await _pixels(lighting);
      int red(int x, int y) => pixels[(y * 256 + x) * 4];
      // Under the steady lamp the floor shows through; in a corner with no
      // lamp it is nearly black; outside the room it is untouched.
      expect(red(32 + 72, 16 + 40), greaterThan(red(32 + 180, 16 + 120)));
      expect(red(32 + 180, 16 + 120), lessThan(0x30));
      expect(red(10, 10), 0x80);
      lighting.onRemove();
    });
  });

  testWidgets('nothing is drawn off screen', (tester) async {
    await tester.runAsync(() async {
      final lighting = _lighting(Vector2(100, 60))..onScreen = false;
      await lighting.onLoad();
      final pixels = await _pixels(lighting);
      expect(pixels.where((value) => value != 0x80 && value != 0xff), isEmpty);
    });
  });
}
