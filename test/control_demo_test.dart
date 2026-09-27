import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
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
      DialogueLine.tutorial('Prima', demo: ControlDemo.shoot),
      DialogueLine.tutorial('Dopo'),
    ]);
    expect(find.byKey(const ValueKey<String>('control-demo-shoot')), findsOne);
    await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
    await tester.pump();
    expect(find.text('Dopo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('control-demo-shoot')),
      findsNothing,
    );
  });
}
