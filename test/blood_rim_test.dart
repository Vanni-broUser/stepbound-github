import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

void main() {
  List<(double, double, double, int)> shape(List<BloodDrip> drips) => [
    for (final d in drips) (d.x, d.length, d.width, d.falling.length),
  ];

  test('the same button always bleeds the same way', () {
    expect(shape(rimDrips('menu-load', 2)), shape(rimDrips('menu-load', 2)));
    expect(stableSeed('menu-load'), stableSeed('menu-load'));
  });

  test('different buttons bleed differently', () {
    final names = <String>[
      'menu-new-game',
      'menu-load',
      'menu-settings',
      'menu-credits',
      'pause-settings',
      'pause-resume',
      'pause-restart',
      'pause-quit',
      'pause-close',
    ];
    final shapes = {for (final name in names) shape(rimDrips(name, 1))};
    expect(shapes, hasLength(names.length));
  });

  test('two or three drips, at least one each side, off the corners and '
      'clear of the label in the middle', () {
    for (var i = 0; i < 300; i++) {
      final drips = rimDrips('button $i', 1);
      expect(drips.length, inInclusiveRange(2, 3));
      expect(drips.where((d) => d.x < 0.5), isNotEmpty);
      expect(drips.where((d) => d.x > 0.5), isNotEmpty);
      for (final drip in drips) {
        expect(
          drip.x,
          anyOf(inInclusiveRange(0.05, 0.18), inInclusiveRange(0.82, 0.95)),
        );
        expect(drip.length, inInclusiveRange(5, 11));
      }
      for (var j = 1; j < drips.length; j++) {
        expect(drips[j].x - drips[j - 1].x, greaterThan(0.04));
      }
    }
  });

  testWidgets('a switch keeps its stains when its label changes', (
    tester,
  ) async {
    Future<BloodPainter> painterOf(String label) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MenuButton(
            key: const ValueKey<String>('settings-audio'),
            label: label,
            unit: 1,
            onPressed: () {},
          ),
        ),
      );
      return tester.widget<BloodOverlay>(find.byType(BloodOverlay)).painter;
    }

    final on = await painterOf('AUDIO: SÌ');
    final off = await painterOf('AUDIO: NO');
    expect(shape(on.drips), shape(off.drips));
    expect(on.bandVariant, off.bandVariant);
  });
}
