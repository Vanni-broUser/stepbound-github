import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/device_info.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/report/telemetry_outbox.dart';
import 'package:stepbound/report/telemetry_transport.dart';

import 'fake_telemetry.dart';

void main() {
  final now = DateTime.utc(2026, 9, 30, 12);

  Map<String, Object?> item(String id, DateTime at, [String pad = '']) =>
      <String, Object?>{'id': id, 'at': at.toIso8601String(), 'pad': pad};

  group('TelemetryOutbox', () {
    test('drops what is older than its age', () {
      final outbox = TelemetryOutbox()
        ..addEvent(item('old', now.subtract(const Duration(days: 31))))
        ..addEvent(item('new', now.subtract(const Duration(days: 29))))
        ..addReport(item('broken', now)..['at'] = 'not a date')
        ..prune(now);
      expect(outbox.events.map((e) => e['id']), <String>['new']);
      expect(outbox.reports, isEmpty);
    });

    test('keeps the newest within the counts', () {
      final outbox = TelemetryOutbox(maxEvents: 2, maxReports: 1);
      for (var i = 0; i < 4; i++) {
        outbox
          ..addEvent(item('e$i', now))
          ..addReport(item('r$i', now));
      }
      outbox.prune(now);
      expect(outbox.events.map((e) => e['id']), <String>['e2', 'e3']);
      expect(outbox.reports.map((e) => e['id']), <String>['r3']);
    });

    test('over its weight, events go before reports', () {
      final outbox = TelemetryOutbox(maxBytes: 3000);
      for (var i = 0; i < 20; i++) {
        outbox.addEvent(item('e$i', now, 'x' * 100));
      }
      outbox
        ..addReport(item('r', now, 'y' * 2000))
        ..prune(now);
      expect(outbox.reports, hasLength(1));
      expect(outbox.toJson().length, lessThanOrEqualTo(3000));
      expect(outbox.events.last['id'], 'e19');

      final heavy = TelemetryOutbox(maxBytes: 1000)
        ..addReport(item('r1', now, 'y' * 800))
        ..addReport(item('r2', now, 'y' * 800))
        ..prune(now);
      expect(heavy.reports.map((e) => e['id']), <String>['r2']);
    });

    test('reads back what it wrote, and nothing from garbage', () {
      final outbox = TelemetryOutbox()
        ..addEvent(item('e', now))
        ..addReport(item('r', now));
      final read = TelemetryOutbox.fromJson(outbox.toJson());
      expect(read.events.single['id'], 'e');
      expect(read.reports.single['id'], 'r');
      expect(TelemetryOutbox.fromJson('{not json').isEmpty, isTrue);
      expect(TelemetryOutbox.fromJson(null).isEmpty, isTrue);
      expect(
        TelemetryOutbox.fromJson('{"events":[{"no":"id"},3]}').isEmpty,
        isTrue,
      );
      read.remove(<String>['e', 'r']);
      expect(read.isEmpty, isTrue);
    });
  });

  group('Telemetry', () {
    test('does nothing until started, nor without a server', () async {
      final telemetry = Telemetry()..track('ignored');
      expect(telemetry.active, isFalse);
      expect(telemetry.outbox.isEmpty, isTrue);
      final store = MemoryTelemetryStore();
      await telemetry.start(store: store, transport: null);
      telemetry
        ..track('ignored')
        ..leftFront()
        ..cameToFront();
      expect(telemetry.available, isFalse);
      expect(telemetry.outbox.isEmpty, isTrue);
      expect(store.values, isEmpty, reason: 'not even an id is made');
    });

    test('says the app opened and sends it with the app details', () async {
      final server = FakeServer();
      final store = MemoryTelemetryStore();
      final telemetry = await startedTelemetry(server: server, store: store);
      expect(telemetry.active, isTrue);
      final (path, body) = server.requests.single;
      expect(path, '/v1/ingest');
      expect(body['installId'], store.values[Telemetry.installIdKey]);
      expect(body['installId'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(body['app'], <String, Object?>{'platform': 'test'});
      final opened = server.events('app_opened').single;
      expect(opened['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(opened['session'], isA<String>());
      expect(telemetry.outbox.isEmpty, isTrue);
      telemetry.dispose();
    });

    test('offline, events wait in the outbox, across restarts', () async {
      final server = FakeServer()..outcome = SendOutcome.failed;
      final store = MemoryTelemetryStore();
      final telemetry = await startedTelemetry(server: server, store: store)
        ..track('zombie_killed', <String, Object?>{'kind': 'wanderer'});
      await telemetry.persist();
      expect(telemetry.outbox.events, hasLength(2));
      expect(server.events(), hasLength(1), reason: 'tried once, failed');

      // The next start, with the network back, sends the lot.
      server.outcome = SendOutcome.delivered;
      final again = await startedTelemetry(server: server, store: store);
      expect(again.outbox.isEmpty, isTrue);
      expect(
        server.requests.last.$2['events'],
        hasLength(3),
        reason: 'the two left waiting, and this opening',
      );
      expect(
        server.requests.last.$2['installId'],
        server.requests.first.$2['installId'],
        reason: 'the same player',
      );
      telemetry.dispose();
      again.dispose();
    });

    test(
      'after a failure it waits before trying again, unless forced',
      () async {
        var clock = now;
        final server = FakeServer()..outcome = SendOutcome.failed;
        final telemetry = await startedTelemetry(
          server: server,
          clock: () => clock,
        );
        await telemetry.flush();
        expect(server.requests, hasLength(1));
        clock = clock.add(const Duration(minutes: 2));
        await telemetry.flush();
        expect(server.requests, hasLength(2), reason: 'a minute has gone');
        clock = clock.add(const Duration(minutes: 1));
        await telemetry.flush();
        expect(server.requests, hasLength(2), reason: 'now it waits two');
        telemetry.cameToFront();
        await telemetry.flush();
        expect(server.requests, hasLength(3), reason: 'back in front: at once');
        telemetry.dispose();
      },
    );

    test('a refused batch is dropped, not tried forever', () async {
      final server = FakeServer()..outcome = SendOutcome.rejected;
      final telemetry = await startedTelemetry(server: server);
      expect(telemetry.outbox.isEmpty, isTrue);
      telemetry.dispose();
    });

    test('sends in batches, and on its own past the threshold', () async {
      final server = FakeServer();
      final telemetry = Telemetry(flushThreshold: 5, batchEvents: 2);
      await telemetry.start(
        store: MemoryTelemetryStore(),
        transport: server.send,
      );
      await telemetry.flush(force: true);
      server.requests.clear();
      for (var i = 0; i < 5; i++) {
        telemetry.track('zombie_killed');
      }
      await telemetry.flush();
      expect(
        server.requests.map((r) => (r.$2['events']! as List).length),
        <int>[2, 2, 1],
      );
      telemetry.dispose();
    });

    test('a visit is counted when the app leaves the front', () async {
      final server = FakeServer();
      final telemetry = await startedTelemetry(server: server);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      telemetry
        ..leftFront()
        // Every step of the way out calls it; the visit counts once.
        ..leftFront();
      await telemetry.flush(force: true);
      final ended = server.events('session_ended');
      expect(ended, hasLength(1));
      expect(
        (ended.single['data']! as Map<String, Object?>)['seconds'],
        greaterThanOrEqualTo(1),
      );
      telemetry.dispose();
    });

    test('an error report is written down and sent at once', () async {
      final server = FakeServer()..outcome = SendOutcome.failed;
      final store = MemoryTelemetryStore();
      final telemetry = await startedTelemetry(server: server, store: store);
      await telemetry.sendReport(
        at: now,
        source: 'async',
        summary: 'Bad state: ${'x' * 600}',
        text: 'RAPPORTO',
      );
      expect(store.values[Telemetry.outboxKey], contains('RAPPORTO'));
      server.outcome = SendOutcome.delivered;
      await telemetry.flush(force: true);
      final report = server.reports().single;
      expect(report['text'], 'RAPPORTO');
      expect(report['source'], 'async');
      expect((report['summary']! as String).length, 500);
      expect(report['at'], now.toIso8601String());
      telemetry.dispose();
    });

    test('watches the error reporter and sends each error once', () async {
      final server = FakeServer();
      final telemetry = await startedTelemetry(server: server);
      final reporter = ErrorReporter(
        breadcrumbs: Breadcrumbs(),
        device: () async => const DeviceInfo(
          model: 'Xiaomi Redmi 9',
          system: 'Android 12',
          memory: '?',
          appVersion: '0.1.0 (402)',
        ),
      );
      telemetry.watch(reporter);
      reporter.record(StateError('boom'), StackTrace.current, source: 'async');
      await pumpEventQueue();
      await telemetry.flush(force: true);
      final report = server.reports().single;
      expect(report['summary'], 'Bad state: boom');
      expect(report['text'], contains('RAPPORTO DI ERRORE DI STEPBOUND'));
      expect(report['text'], contains('Xiaomi Redmi 9'));
      reporter.notifyListeners();
      await pumpEventQueue();
      expect(server.reports(), hasLength(1));
      telemetry.dispose();
    });

    test(
      'turned off: nothing kept, the id forgotten, the server told',
      () async {
        final server = FakeServer()..outcome = SendOutcome.failed;
        final store = MemoryTelemetryStore();
        final telemetry = await startedTelemetry(server: server, store: store)
          ..track('zombie_killed');
        final id = store.values[Telemetry.installIdKey];
        await telemetry.setEnabled(enabled: false);
        // The request to forget has been tried, offline.
        await pumpEventQueue();
        expect(server.requests.last.$1, '/v1/forget');
        expect(telemetry.active, isFalse);
        expect(telemetry.outbox.isEmpty, isTrue);
        expect(store.values[Telemetry.enabledKey], 'false');
        expect(store.values[Telemetry.installIdKey], isNull);
        expect(store.values[Telemetry.outboxKey], isNull);
        expect(store.values[Telemetry.forgetKey], id);
        telemetry.track('ignored');
        expect(telemetry.outbox.isEmpty, isTrue);

        // Offline then; the next start asks again, and stays off.
        server
          ..outcome = SendOutcome.delivered
          ..requests.clear();
        final next = await startedTelemetry(server: server, store: store);
        expect(server.requests.single.$1, '/v1/forget');
        expect(server.requests.single.$2, <String, Object?>{'installId': id});
        expect(store.values[Telemetry.forgetKey], isNull);
        expect(next.active, isFalse);
        expect(next.enabled, isFalse);

        // On again: a new player, unrelated to the old one.
        await next.setEnabled(enabled: true);
        await next.flush(force: true);
        expect(store.values[Telemetry.installIdKey], isNot(id));
        expect(server.events('app_opened'), hasLength(1));
        telemetry.dispose();
        next.dispose();
      },
    );

    test('the switch before start only changes the flag', () async {
      final telemetry = Telemetry();
      await telemetry.setEnabled(enabled: false);
      expect(telemetry.enabled, isFalse);
    });

    test('a store that fails leaves the game alone', () async {
      final telemetry = Telemetry();
      await telemetry.start(
        store: _BrokenStore(),
        transport: FakeServer().send,
        app: () => throw StateError('no device'),
      );
      telemetry.track('zombie_killed');
      await telemetry.persist();
      telemetry.dispose();
    });

    test('fit keeps short reports and cuts the middle of long ones', () {
      expect(Telemetry.fit('short'), 'short');
      final long = 'HEAD${'é' * 1000}TAIL';
      final cut = Telemetry.fit(long, maxBytes: 300);
      expect(cut, startsWith('HEAD'));
      expect(cut, endsWith('TAIL'));
      expect(cut, contains('rapporto tagliato'));
      expect(utf8.encode(cut).length, lessThan(400));
    });
  });

  group('HttpTelemetryTransport', () {
    test('posts JSON with the key and reads the answer', () async {
      late http.Request seen;
      final transport = HttpTelemetryTransport(
        baseUrl: 'https://telemetry.example/',
        key: 'secret',
        client: MockClient((request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
      );
      final outcome = await transport.send('/v1/ingest', <String, Object?>{
        'installId': 'x',
      });
      expect(outcome, SendOutcome.delivered);
      expect(seen.url.toString(), 'https://telemetry.example/v1/ingest');
      expect(seen.headers['X-Stepbound-Key'], 'secret');
      expect(jsonDecode(seen.body), <String, Object?>{'installId': 'x'});
    });

    test('an exception is a failure, to try again', () async {
      final transport = HttpTelemetryTransport(
        baseUrl: 'https://telemetry.example',
        key: 'k',
        client: MockClient((_) => throw http.ClientException('offline')),
      );
      expect(
        await transport.send('/v1/ingest', const <String, Object?>{}),
        SendOutcome.failed,
      );
    });

    test('what each status means', () {
      expect(HttpTelemetryTransport.outcomeOf(200), SendOutcome.delivered);
      expect(HttpTelemetryTransport.outcomeOf(400), SendOutcome.rejected);
      expect(HttpTelemetryTransport.outcomeOf(401), SendOutcome.rejected);
      expect(HttpTelemetryTransport.outcomeOf(413), SendOutcome.rejected);
      expect(HttpTelemetryTransport.outcomeOf(408), SendOutcome.failed);
      expect(HttpTelemetryTransport.outcomeOf(429), SendOutcome.failed);
      expect(HttpTelemetryTransport.outcomeOf(503), SendOutcome.failed);
    });
  });
}

final class _BrokenStore implements TelemetryStore {
  @override
  Future<String?> read(String key) => throw StateError('broken');

  @override
  Future<void> write(String key, String value) => throw StateError('broken');

  @override
  Future<void> remove(String key) => throw StateError('broken');
}
