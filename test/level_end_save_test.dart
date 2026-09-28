import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/level_complete.dart';

void main() {
  group('the results screen', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool saveFailed,
      VoidCallback? onShareReport,
    }) async {
      tester.view.physicalSize = const Size(768, 432);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LevelComplete(
            stats: LevelStats.of(
              createGameWorld(),
              Progress.newGame()..remember(StoryMemory.luigiAtStation),
              LevelId.hometown,
            ),
            saveFailed: saveFailed,
            onShareReport: onShareReport,
            onContinue: () {},
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('says nothing about a save that worked', (tester) async {
      await pump(tester, saveFailed: false);
      expect(
        find.byKey(const ValueKey<String>('level-complete-save-failed')),
        findsNothing,
      );
      expect(find.text(LevelComplete.saveFailedLine), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('level-complete-share')),
        findsNothing,
      );
    });

    testWidgets('offers the report of the failed save', (tester) async {
      var shares = 0;
      await pump(tester, saveFailed: true, onShareReport: () => shares += 1);
      await tester.tap(
        find.byKey(const ValueKey<String>('level-complete-share')),
      );
      expect(shares, 1);
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('level-complete-continue')),
            )
            .bottom,
        lessThanOrEqualTo(432),
      );
    });

    testWidgets('says so, above the button, when the save failed', (
      tester,
    ) async {
      await pump(tester, saveFailed: true);
      final line = find.byKey(
        const ValueKey<String>('level-complete-save-failed'),
      );
      expect(line, findsOneWidget);
      expect(find.text(LevelComplete.saveFailedLine), findsOneWidget);
      final button = find.byKey(
        const ValueKey<String>('level-complete-continue'),
      );
      expect(
        tester.getBottomLeft(line).dy,
        lessThan(tester.getTopLeft(button).dy),
      );
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(432));
    });
  });
}
