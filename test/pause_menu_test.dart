import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/ui/pause_menu.dart';

void main() {
  late int resumes;
  late int restarts;
  late int quits;
  late int closes;

  Future<void> pumpMenu(
    WidgetTester tester, {
    bool canResumeFromCamp = true,
  }) async {
    resumes = 0;
    restarts = 0;
    quits = 0;
    closes = 0;
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          key: ValueKey<bool>(canResumeFromCamp),
          canResumeFromCamp: canResumeFromCamp,
          onResumeFromCamp: () => resumes++,
          onRestartLevel: () => restarts++,
          onMainMenu: () => quits++,
          onClose: () => closes++,
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('with a campfire behind him, all three ways out', (tester) async {
    await pumpMenu(tester);
    for (final text in <String>[
      'RIPRENDI DAL FALÒ',
      'RICOMINCIA IL LIVELLO',
      'VAI AL MENÙ PRINCIPALE',
      'TORNA AL GIOCO',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tap(tester, 'pause-close');
    expect(closes, 1);
  });

  testWidgets('without one, there is nothing to resume', (tester) async {
    await pumpMenu(tester, canResumeFromCamp: false);
    expect(find.text('RIPRENDI DAL FALÒ'), findsNothing);
    expect(find.text('RICOMINCIA IL LIVELLO'), findsOneWidget);
    expect(find.text('VAI AL MENÙ PRINCIPALE'), findsOneWidget);
  });

  testWidgets('the way back to the game sits apart from the choices', (
    tester,
  ) async {
    await pumpMenu(tester);
    double topOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).top;
    double bottomOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).bottom;

    final betweenChoices = topOf('pause-quit') - bottomOf('pause-restart');
    final beforeTheWayBack = topOf('pause-close') - bottomOf('pause-quit');

    expect(beforeTheWayBack, greaterThan(betweenChoices * 2));
  });

  for (final (choice, name, count) in <(String, String, int Function())>[
    ('pause-resume', 'going back to the fire', () => resumes),
    ('pause-restart', 'starting the level over', () => restarts),
    ('pause-quit', 'leaving for the main menu', () => quits),
  ]) {
    testWidgets('$name asks first, and No comes back', (tester) async {
      await pumpMenu(tester);
      await tap(tester, choice);
      expect(count(), 0, reason: 'nothing happens until it is confirmed');
      expect(find.byKey(const ValueKey<String>('pause-cost')), findsOneWidget);

      await tap(tester, 'pause-back');
      expect(count(), 0);
      expect(find.text('TORNA AL GIOCO'), findsOneWidget);

      await tap(tester, choice);
      await tap(tester, 'pause-confirm');
      expect(count(), 1);
    });
  }

  testWidgets('every confirmation says what it costs', (tester) async {
    Future<String> costOf(WidgetTester tester, String choice) async {
      await tap(tester, choice);
      return tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('pause-cost')),
              matching: find.byType(Text),
            ),
          )
          .data!;
    }

    await pumpMenu(tester);
    expect(await costOf(tester, 'pause-resume'), contains('va perso'));
    await tap(tester, 'pause-back');
    final restart = await costOf(tester, 'pause-restart');
    expect(restart, contains('si azzerano'));
    expect(
      restart,
      contains('ore di gioco'),
      reason: 'the hours are the one thing it keeps',
    );
    await tap(tester, 'pause-back');
    expect(await costOf(tester, 'pause-quit'), contains('ultimo falò'));

    // Never saved: leaving costs the whole game, and it says so.
    await pumpMenu(tester, canResumeFromCamp: false);
    expect(await costOf(tester, 'pause-quit'), contains('mai stata salvata'));
  });
}
