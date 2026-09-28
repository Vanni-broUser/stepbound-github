import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/device_info.dart';
import 'package:stepbound/report/error_report.dart';

void main() {
  final noon = DateTime(2026, 9, 28, 12, 30, 5, 7);

  group('Breadcrumbs', () {
    test('keep the last ones, oldest first', () {
      final trail = Breadcrumbs(capacity: 3, clock: () => noon);
      <String>['a', 'b', 'c', 'd'].forEach(trail.add);
      expect(trail.entries.map((e) => e.text), <String>['b', 'c', 'd']);
      expect(trail.entries.first.toString(), '12:30:05.007  b');
      trail.clear();
      expect(trail.entries, isEmpty);
    });
  });

  group('ErrorReport', () {
    test('summary is the first line of the error', () {
      final report = ErrorReport(
        error: StateError('first line\nsecond line'),
        at: noon,
        source: 'test',
      );
      expect(report.summary, 'Bad state: first line');
    });
  });

  group('ErrorReporter', () {
    late ErrorReporter reporter;
    late Breadcrumbs trail;
    late int notified;

    setUp(() {
      trail = Breadcrumbs(clock: () => noon);
      notified = 0;
      reporter = ErrorReporter(
        clock: () => noon,
        breadcrumbs: trail,
        device: () async => const DeviceInfo(
          model: 'Xiaomi Redmi 9',
          system: 'Android 12 (API 31)',
          memory: '2048 MB liberi di 5800',
          appVersion: '0.1.0 (402)',
        ),
      )..addListener(() => notified += 1);
    });

    test('keeps the first error until reset', () {
      reporter
        ..record(StateError('first'), null, source: 'a')
        ..record(StateError('second'), null, source: 'b');
      expect(reporter.report?.summary, 'Bad state: first');
      expect(reporter.report?.source, 'a');
      expect(reporter.report?.at, noon);
      expect(notified, 1);
      reporter.reset();
      expect(reporter.report, isNull);
      expect(notified, 2);
      reporter.reset();
      expect(notified, 2, reason: 'nothing to reset');
    });

    test('names the file after the moment of the error', () {
      final report = ErrorReport(error: 'x', at: noon, source: 'test');
      expect(
        reporter.fileNameFor(report),
        'stepbound-rapporto-20260928-123005.txt',
      );
    });

    test('renders build, phone, error, sections and trail', () async {
      trail.add('app: menù principale');
      reporter.context = () async => <ReportSection>[
        const ReportSection('Partita', 'slot: 2'),
      ];
      final text = await reporter.render(
        ErrorReport(
          error: StateError('boom'),
          stack: StackTrace.fromString('#0 somewhere'),
          at: noon,
          source: 'widgets library',
        ),
      );
      expect(text, startsWith('RAPPORTO DI ERRORE DI STEPBOUND\n'));
      expect(text, contains('Versione: 0.1.0 (402)\n'));
      expect(text, contains('Commit: $buildCommit\n'));
      expect(text, contains('Telefono: Xiaomi Redmi 9\n'));
      expect(text, contains('Memoria: 2048 MB liberi di 5800\n'));
      expect(text, contains('== Errore (widgets library) ==\nBad state: boom'));
      expect(text, contains('#0 somewhere'));
      expect(text, contains('== Partita ==\nslot: 2\n'));
      expect(text, contains('== Ultimi passi ==\n12:30:05.007  app: menù'));
    });

    test('renders even when the app and the phone fail to answer', () async {
      reporter = ErrorReporter(
        clock: () => noon,
        breadcrumbs: trail,
        device: () async => throw StateError('no phone'),
      )..context = () async => throw StateError('no app');
      final text = await reporter.render(
        ErrorReport(error: 'x', at: noon, source: 'test'),
      );
      expect(text, contains('Telefono: ${DeviceInfo.unknown}\n'));
      expect(
        text,
        contains('== Partita ==\nnon disponibile: Bad state: no app'),
      );
      expect(text, contains('nessuno stack trace'));
      expect(text, contains('== Ultimi passi ==\nnessuno\n'));
    });

    test('hooks the framework and the platform handlers', () {
      final previousFlutter = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
      });
      final seenBefore = <Object>[];
      FlutterError.onError = (details) => seenBefore.add(details.exception);
      PlatformDispatcher.instance.onError = null;
      reporter.install();

      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('frame'), library: 'flame'),
      );
      expect(seenBefore, hasLength(1), reason: 'the old handler still runs');
      expect(reporter.report?.source, 'flame');
      expect(reporter.report?.summary, 'Bad state: frame');

      reporter.reset();
      final handled = PlatformDispatcher.instance.onError!(
        StateError('async'),
        StackTrace.empty,
      );
      expect(handled, isTrue);
      expect(reporter.report?.source, 'async');
    });
  });

  group('DeviceInfo', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    /// The activity's answer for this test only.
    void activityAnswers(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceInfo.channel, handler);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceInfo.channel, null),
      );
    }

    test('reads what the activity answers', () async {
      activityAnswers((call) async {
        expect(call.method, 'info');
        return <String, Object?>{
          'manufacturer': 'Xiaomi',
          'model': 'Redmi 9',
          'system': 'Android 12 (API 31)',
          'memory': '2000 MB liberi di 5800',
          'versionName': '0.1.0',
          'versionCode': 402,
        };
      });
      final info = await DeviceInfo.read();
      expect(info.model, 'Xiaomi Redmi 9');
      expect(info.system, 'Android 12 (API 31)');
      expect(info.memory, '2000 MB liberi di 5800');
      expect(info.appVersion, '0.1.0 (402)');
    });

    test('says so when nothing answers', () async {
      final info = await DeviceInfo.read();
      expect(info.model, DeviceInfo.unknown);
      expect(info.appVersion, DeviceInfo.unknown);
      expect(info.system, defaultTargetPlatform.name);
    });

    test('says so when the activity fails', () async {
      activityAnswers((call) async => throw PlatformException(code: 'no'));
      final info = await DeviceInfo.read();
      expect(info.memory, DeviceInfo.unknown);
    });
  });
}
