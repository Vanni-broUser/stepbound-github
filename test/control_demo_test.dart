import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/control_demo.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';

void main() {
  setUp(() => GameplayDialogue.settleTime = Duration.zero);
  tearDown(
    () => GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime,
  );

  Future<void> show(WidgetTester tester, List<DialogueLine> lines) =>
      tester.pumpWidget(
        MaterialApp(
          home: GameplayDialogue(onFinished: () {}, lines: lines),
        ),
      );

  for (final demo in ControlDemo.values) {
    testWidgets(
      'a line with the ${demo.name} gesture plays it beside the box',
      (tester) async {
        await show(tester, <DialogueLine>[
          DialogueLine.tutorial('Guarda', demo: demo),
        ]);
        // Round after round, it keeps playing.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 450));
        }
        expect(
          find.byKey(ValueKey<String>('control-demo-${demo.name}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the gesture goes with the line that shows it', (tester) async {
    await show(tester, const <DialogueLine>[
      DialogueLine.tutorial('Prima', demo: ControlDemo.aim),
      DialogueLine.tutorial('Dopo'),
    ]);
    expect(find.byKey(const ValueKey<String>('control-demo-aim')), findsOne);
    await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
    await tester.pump();
    expect(find.text('Dopo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('control-demo-aim')),
      findsNothing,
    );
  });

  testWidgets('right-half gestures stand on the right, movement on the left', (
    tester,
  ) async {
    for (final demo in ControlDemo.values) {
      await show(tester, <DialogueLine>[
        DialogueLine.tutorial('Guarda', demo: demo),
      ]);
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(ControlDemoView),
          matching: find.byType(Positioned),
        ),
      );
      if (demo == ControlDemo.move) {
        expect(positioned.left, 16);
        expect(positioned.right, isNull);
      } else {
        expect(positioned.left, isNull, reason: '${demo.name} uses the right');
        expect(positioned.right, 16, reason: '${demo.name} uses the right');
      }
    }
  });

  Future<void> showHint(WidgetTester tester, VoidCallback onFinished) =>
      tester.pumpWidget(
        MaterialApp(
          home: GameplayDialogue(
            onFinished: onFinished,
            lines: const <DialogueLine>[
              DialogueLine.tutorial(
                'Muoviti',
                demo: ControlDemo.move,
                advanceOnRightDrag: true,
              ),
            ],
          ),
        ),
      );

  testWidgets('a rightward drag dismisses only the opening movement hint', (
    tester,
  ) async {
    var finished = false;
    await showHint(tester, () => finished = true);
    final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
    final right = tester.getTopRight(dialogue) + const Offset(-100, 100);
    await tester.dragFrom(right, const Offset(-100, 0));
    await tester.pump();
    expect(finished, isFalse, reason: 'on the right, only a rightward drag');

    await tester.dragFrom(right, const Offset(100, 0));
    await tester.pump();
    expect(finished, isTrue);

    finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayDialogue(
          onFinished: () => finished = true,
          lines: const <DialogueLine>[DialogueLine.tutorial('Dialogo normale')],
        ),
      ),
    );
    await tester.drag(dialogue, const Offset(100, 0));
    await tester.pump();
    expect(finished, isFalse);
  });

  testWidgets('a drag any way or a tap on the left half, or on the pad '
      'shown, dismisses the movement hint straight away', (tester) async {
    GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime;
    final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
    final demo = find.byType(ControlDemoView);
    for (final (name, gesture) in <(String, Future<void> Function())>[
      (
        'drag left',
        () => tester.dragFrom(
          tester.getTopLeft(dialogue) + const Offset(60, 120),
          const Offset(-40, 0),
        ),
      ),
      (
        'drag up',
        () => tester.dragFrom(
          tester.getBottomLeft(dialogue) + const Offset(80, -80),
          const Offset(0, -60),
        ),
      ),
      (
        'tap left',
        () => tester.tapAt(
          tester.getBottomLeft(dialogue) + const Offset(80, -80),
        ),
      ),
      ('tap on the pad', () => tester.tapAt(tester.getCenter(demo))),
    ]) {
      var finished = false;
      await showHint(tester, () => finished = true);
      await gesture();
      await tester.pump();
      expect(finished, isTrue, reason: name);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(GameplayDialogue.defaultSettleTime);
    }

    var finished = false;
    await showHint(tester, () => finished = true);
    await tester.tapAt(tester.getTopRight(dialogue) + const Offset(-60, 120));
    await tester.pump();
    expect(finished, isFalse, reason: 'a tap on the right waits as ever');
    await tester.pump(GameplayDialogue.defaultSettleTime);
  });
}
