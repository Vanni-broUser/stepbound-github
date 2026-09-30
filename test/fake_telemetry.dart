import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/report/telemetry_transport.dart';

/// Storage that lives as long as the test.
final class MemoryTelemetryStore implements TelemetryStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// A server that writes down every request and answers [outcome].
final class FakeServer {
  final List<(String, Map<String, Object?>)> requests =
      <(String, Map<String, Object?>)>[];
  SendOutcome outcome = SendOutcome.delivered;

  Future<SendOutcome> send(String path, Map<String, Object?> body) async {
    requests.add((path, body));
    return outcome;
  }

  /// Every event the server was sent, by type.
  List<Map<String, Object?>> events([String? type]) => <Map<String, Object?>>[
    for (final (path, body) in requests)
      if (path == '/v1/ingest')
        for (final event in body['events']! as List<Object?>)
          if (type == null || (event! as Map<String, Object?>)['type'] == type)
            event! as Map<String, Object?>,
  ];

  List<Map<String, Object?>> reports() => <Map<String, Object?>>[
    for (final (path, body) in requests)
      if (path == '/v1/ingest')
        for (final report in body['reports']! as List<Object?>)
          report! as Map<String, Object?>,
  ];
}

/// A [Telemetry] started on [store] and [server], its opening already
/// sent. Offline ([SendOutcome.failed]) keeps everything in the outbox.
Future<Telemetry> startedTelemetry({
  MemoryTelemetryStore? store,
  FakeServer? server,
  DateTime Function()? clock,
  int flushThreshold = 50,
}) async {
  final telemetry = Telemetry(
    clock: clock ?? DateTime.now,
    flushThreshold: flushThreshold,
  );
  await telemetry.start(
    store: store ?? MemoryTelemetryStore(),
    transport: (server ?? FakeServer()).send,
    app: () async => <String, Object?>{'platform': 'test'},
  );
  await telemetry.flush(force: true);
  return telemetry;
}
