import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/pickup_component.dart';

/// Whether [component] draws the glint's colour anywhere this frame.
Future<bool> _glinting(Component component) async {
  final recorder = ui.PictureRecorder();
  component.renderTree(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(32, 32);
  final data = (await image.toByteData())!;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) == 0xff &&
        data.getUint8(i + 1) == 0xf6 &&
        data.getUint8(i + 2) == 0xd8) {
      return true;
    }
  }
  return false;
}

void main() {
  test('the glint blinks steadily: on a good part of every second', () {
    const frames = 100;
    final on = <bool>[
      for (var i = 0; i < frames; i++) Glint.litAt(i * Glint.period / frames),
    ];
    final share = on.where((lit) => lit).length / frames;
    expect(share, closeTo(Glint.onShare, 0.02));
    expect(share, greaterThanOrEqualTo(0.3), reason: 'a blink, not a flash');
    expect(Glint.litAt(0), isTrue);
    expect(Glint.litAt(Glint.period * 0.9), isFalse);
    expect(Glint.litAt(Glint.period), isTrue, reason: 'and again');
  });

  testWidgets('a backpack and any other object blink together', (tester) {
    return tester.runAsync(() async {
      final backpack = PickupComponent(
        pickup: Pickup(id: 'backpack', position: const GridPoint(0, 0)),
      );
      await backpack.onLoad();
      final object = InteractGlintComponent(
        tile: const GridPoint(0, 0),
        active: () => true,
      );
      var blinks = 0;
      var wasOn = false;
      for (var i = 0; i < 60; i++) {
        backpack.update(0.05);
        object.update(0.05);
        final on = await _glinting(backpack);
        expect(await _glinting(object), on, reason: 'frame $i');
        if (on && !wasOn) {
          blinks++;
        }
        wasOn = on;
      }
      expect(blinks, 3, reason: 'once a second for three seconds');
    });
  });
}
