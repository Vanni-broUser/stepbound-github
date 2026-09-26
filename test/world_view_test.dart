import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';

void main() {
  const width = IntegerResolutionViewport.virtualWidth;
  const height = IntegerResolutionViewport.virtualHeight;

  test('a 16:9 screen of any size shows the same 16:9 view', () {
    for (final (w, h) in <(double, double)>[(640, 360), (1920, 1080)]) {
      final view = IntegerResolutionViewport.worldViewFor(w, h);
      expect(view.width, closeTo(width, 0.001));
      expect(view.height, closeTo(height, 0.001));
    }
  });

  test('any other screen gets its own shape with as much ground in view', () {
    for (final (w, h) in <(double, double)>[
      (915, 412),
      (844, 390),
      (1280, 800),
      (1024, 768),
    ]) {
      final view = IntegerResolutionViewport.worldViewFor(w, h);
      expect(view.width / view.height, closeTo(w / h, 0.001));
      expect(view.width * view.height, closeTo(width * height, 0.01));
    }
    // A 20:9 phone: a few columns more, a row or so less.
    final phone = IntegerResolutionViewport.worldViewFor(915, 412);
    expect(phone.width / 16, closeTo(26.8, 0.1));
    expect(phone.height / 16, closeTo(12.1, 0.1));
  });

  test('past the shapes it fills, it keeps the nearest one', () {
    final strip = IntegerResolutionViewport.worldViewFor(2000, 300);
    expect(
      strip.width / strip.height,
      closeTo(IntegerResolutionViewport.maxAspect, 0.001),
    );
    final square = IntegerResolutionViewport.worldViewFor(500, 500);
    expect(
      square.width / square.height,
      closeTo(IntegerResolutionViewport.minAspect, 0.001),
    );
  });
}
