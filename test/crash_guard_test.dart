import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/device_info.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/crash_guard.dart';
import 'package:stepbound/ui/error_screen.dart';

void main() {
  final noon = DateTime(2026, 9, 28, 12);

  ErrorReporter reporter() => ErrorReporter(
    clock: () => noon,
    breadcrumbs: Breadcrumbs(clock: () => noon),
    device: () async => const DeviceInfo(
      model: 'telefono di prova',
      system: 'test',
      memory: '-',
      appVersion: '0.0.0 (1)',
    ),
  );

  Future<void> pumpGuard(
    WidgetTester tester,
    ErrorReporter reporter, {
    required ShareReport share,
    GameAudio? audio,
  }) async {
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CrashGuard(
        reporter: reporter,
        share: share,
        audio: audio,
        child: const MaterialApp(
          home: Text('il gioco', key: ValueKey<String>('the-game')),
        ),
      ),
    );
  }

  group('CrashGuard', () {
    testWidgets('shows the game until an error is reported, then the '
        'screen, and pauses the sound', (tester) async {
      final errors = reporter();
      final audio = SilentAudio();
      await pumpGuard(tester, errors, share: (_, _) async {}, audio: audio);
      expect(find.byKey(const ValueKey<String>('the-game')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('error-screen')), findsNothing);

      errors.record(StateError('il mondo è rotto'), null, source: 'test');
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('the-game')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('error-screen')),
        findsOneWidget,
      );
      expect(find.text(ErrorScreen.title), findsOneWidget);
      expect(find.text('Bad state: il mondo è rotto'), findsOneWidget);
      // On the loading picture, not on black.
      expect(
        find.byKey(const ValueKey<String>('loading-backdrop')),
        findsOneWidget,
      );
      expect(audio.paused, isTrue);
      // Everything fits the phone's screen: nothing to scroll for.
      for (final key in <String>['error-share', 'error-menu']) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
        expect(rect.bottom, lessThanOrEqualTo(432), reason: key);
        expect(rect.top, greaterThanOrEqualTo(0), reason: key);
      }
    });

    testWidgets('shares the report as a file named after the error', (
      tester,
    ) async {
      final errors = reporter();
      final shared = <(String, String)>[];
      final sharing = Completer<void>();
      await pumpGuard(
        tester,
        errors,
        share: (name, text) {
          shared.add((name, text));
          return sharing.future;
        },
      );
      errors.record(StateError('boom'), StackTrace.current, source: 'test');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('error-share')));
      await tester.pump();
      expect(find.text(ErrorScreen.sharingLabel), findsOneWidget);
      // A second tap while the sheet is being prepared does nothing.
      await tester.tap(find.byKey(const ValueKey<String>('error-share')));
      await tester.pump();
      expect(shared, hasLength(1));
      expect(shared.single.$1, 'stepbound-rapporto-20260928-120000.txt');
      expect(shared.single.$2, contains('Bad state: boom'));
      expect(shared.single.$2, contains('Telefono: telefono di prova'));

      sharing.complete();
      await tester.pumpAndSettle();
      expect(find.text(ErrorScreen.shareLabel), findsOneWidget);
    });

    testWidgets('a share that fails leaves the screen usable', (tester) async {
      final errors = reporter();
      await pumpGuard(
        tester,
        errors,
        share: (_, _) async => throw StateError('no sheet'),
      );
      errors.record(StateError('boom'), null, source: 'test');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('error-share')));
      await tester.pump();
      expect(find.text(ErrorScreen.shareLabel), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('error-screen')),
        findsOneWidget,
      );
    });

    testWidgets('back to the menu starts the game over and resumes the '
        'sound', (tester) async {
      final errors = reporter();
      final audio = SilentAudio();
      await pumpGuard(tester, errors, share: (_, _) async {}, audio: audio);
      errors.record(StateError('boom'), null, source: 'test');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('error-menu')));
      await tester.pump();
      expect(errors.report, isNull);
      expect(find.byKey(const ValueKey<String>('the-game')), findsOneWidget);
      expect(audio.paused, isFalse);
      // The next error is a new one.
      errors.record(StateError('again'), null, source: 'test');
      await tester.pump();
      expect(find.text('Bad state: again'), findsOneWidget);
    });

    testWidgets('an error reported during a build waits for the frame', (
      tester,
    ) async {
      final errors = reporter();
      tester.view.physicalSize = const Size(768, 432);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CrashGuard(
          reporter: errors,
          share: (_, _) async {},
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                errors.record(StateError('in build'), null, source: 'build');
                return const Text('costruito');
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bad state: in build'), findsOneWidget);
    });
  });

  group('StepboundApp', () {
    testWidgets('tells the report about the slot, the phase and the save', (
      tester,
    ) async {
      final errors = reporter();
      final saves = MemorySaveRepository();
      tester.view.physicalSize = const Size(768, 432);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        StepboundApp(saves: saves, audio: SilentAudio(), reporter: errors),
      );
      await tester.pump();
      expect(errors.context, isNotNull);
      final text = await errors.render(
        ErrorReport(error: 'x', at: noon, source: 'test'),
      );
      expect(text, contains('== Partita ==\nslot: 1\nfase: menu\n'));
      expect(text, contains('posto: nessuno\n'));
      expect(text, contains('== Salvataggio dello slot 1 ==\nvuoto\n'));
      expect(
        Breadcrumbs.shared.entries.map((e) => e.text),
        contains('app: menù principale'),
      );

      await tester.pumpWidget(const SizedBox());
      expect(errors.context, isNull, reason: 'the app let go of the report');
    });
  });
}
