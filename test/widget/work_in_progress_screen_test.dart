import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/ui/work_in_progress_screen.dart';

void main() {
  testWidgets('the end of the demo: what is still to be made, and the links '
      'to Instagram that open them without taking the screen away', (
    tester,
  ) async {
    // A phone on its side, as the game is always played.
    tester.view
      ..physicalSize = const Size(1830, 824)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var closed = 0;
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WorkInProgressScreen(
          onBack: () => closed++,
          openLink: (link) async => opened.add(link),
        ),
      ),
    );
    expect(find.text(WorkInProgressScreen.title), findsOneWidget);
    expect(find.text(WorkInProgressScreen.missingItems), findsOneWidget);
    expect(find.text(WorkInProgressScreen.feedback), findsOneWidget);
    expect(WorkInProgressScreen.missingItems, contains('Estintore'));
    expect(WorkInProgressScreen.missingItems, contains('Piede di porco'));

    // Each page on the Instagram line opens its own, fastsite_ first.
    for (final handle in <String>['fastsite_', 'vannicolasanto']) {
      await tester.tap(
        find.byKey(ValueKey<String>('work-in-progress-link-$handle')),
      );
      await tester.pump();
    }
    expect(opened, <Uri>[
      Uri.parse('https://www.instagram.com/fastsite_/'),
      Uri.parse('https://www.instagram.com/vannicolasanto/'),
    ]);
    expect(closed, 0);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(closed, 1);
    expect(opened, hasLength(2));
  });
}
