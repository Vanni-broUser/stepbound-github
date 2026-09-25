import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/ui/blood_splat.dart';

void main() {
  Set<(int, int)> cellsOf(BloodSplatShape shape) => <(int, int)>{
    for (final pixel in shape.pixels) (pixel.x, pixel.y),
  };

  test('the same touch always leaves the same splat, another one never', () {
    final one = BloodSplatShape.generate(seed: 7, kind: SplatKind.tap);
    final again = BloodSplatShape.generate(seed: 7, kind: SplatKind.tap);
    expect(cellsOf(again), cellsOf(one));
    for (var seed = 8; seed < 20; seed++) {
      final other = BloodSplatShape.generate(seed: seed, kind: SplatKind.tap);
      expect(cellsOf(other), isNot(cellsOf(one)), reason: 'seed $seed');
    }
  });

  test('holding leaves a bigger splat than tapping', () {
    for (var seed = 0; seed < 20; seed++) {
      final tap = BloodSplatShape.generate(seed: seed, kind: SplatKind.tap);
      final hold = BloodSplatShape.generate(seed: seed, kind: SplatKind.hold);
      expect(hold.pixels.length, greaterThan(tap.pixels.length));
    }
  });

  test('a swipe smears the blood the way the finger went', () {
    for (final direction in <Offset>[
      const Offset(40, 0),
      const Offset(-40, 0),
      const Offset(0, -40),
    ]) {
      final shape = BloodSplatShape.generate(
        seed: 3,
        kind: SplatKind.swipe,
        direction: direction,
      );
      final mean =
          shape.pixels.fold(
            Offset.zero,
            (sum, pixel) => sum + Offset(pixel.x * 1.0, pixel.y * 1.0),
          ) /
          shape.pixels.length.toDouble();
      expect(
        mean.dx * direction.dx + mean.dy * direction.dy,
        greaterThan(0),
        reason: '$direction',
      );
    }
  });

  test('the splat spreads at once, the drips crawl down after it', () {
    final shape = BloodSplatShape.generate(seed: 11, kind: SplatKind.hold);
    final first = shape.pixels.where((pixel) => pixel.appearAt < 0.2);
    final late = shape.pixels.where((pixel) => pixel.appearAt >= 0.2);
    expect(first, isNotEmpty);
    expect(late, isNotEmpty, reason: 'a held splat always drips');
    final bottom = first
        .map((pixel) => pixel.y)
        .reduce((a, b) => a > b ? a : b);
    expect(
      late.map((pixel) => pixel.y).reduce((a, b) => a > b ? a : b),
      greaterThan(bottom),
    );
  });
}
