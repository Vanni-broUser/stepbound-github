import 'dart:convert';

/// What is waiting to leave the phone: gameplay events and error reports,
/// each as the JSON the server takes (see `stepbound-be`), oldest first.
///
/// The phone may stay offline for weeks, so the outbox has bounds, and
/// [prune] keeps it within them: anything older than [maxAge] goes, then
/// the oldest events past [maxEvents] and the oldest reports past
/// [maxReports], then, while the whole still weighs more than [maxBytes],
/// the oldest events and, with none left, the oldest reports. An error is
/// worth more than a step of the story, so events go first.
final class TelemetryOutbox {
  TelemetryOutbox({
    this.maxAge = const Duration(days: 30),
    this.maxEvents = 2000,
    this.maxReports = 3,
    this.maxBytes = 800 * 1024,
  });

  /// The outbox written by [toJson]; what cannot be read is left out, and
  /// an outbox that cannot be read at all comes back empty.
  factory TelemetryOutbox.fromJson(
    String? encoded, {
    Duration maxAge = const Duration(days: 30),
    int maxEvents = 2000,
    int maxReports = 3,
    int maxBytes = 800 * 1024,
  }) {
    final outbox = TelemetryOutbox(
      maxAge: maxAge,
      maxEvents: maxEvents,
      maxReports: maxReports,
      maxBytes: maxBytes,
    );
    if (encoded == null) {
      return outbox;
    }
    try {
      final json = jsonDecode(encoded) as Map<String, Object?>;
      List<Map<String, Object?>> items(String key) => <Map<String, Object?>>[
        for (final item in json[key] as List<Object?>? ?? const <Object?>[])
          if (item is Map<String, Object?> && item['id'] is String) item,
      ];
      outbox._events.addAll(items('events'));
      outbox._reports.addAll(items('reports'));
    } on Object {
      // A broken outbox is an empty one: nothing in it is worth a crash.
    }
    return outbox;
  }

  final Duration maxAge;
  final int maxEvents;
  final int maxReports;
  final int maxBytes;

  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _reports = <Map<String, Object?>>[];

  List<Map<String, Object?>> get events =>
      List<Map<String, Object?>>.unmodifiable(_events);

  List<Map<String, Object?>> get reports =>
      List<Map<String, Object?>>.unmodifiable(_reports);

  bool get isEmpty => _events.isEmpty && _reports.isEmpty;

  void addEvent(Map<String, Object?> event) => _events.add(event);

  void addReport(Map<String, Object?> report) => _reports.add(report);

  /// The server has them: they leave the outbox.
  void remove(Iterable<String> ids) {
    final gone = ids.toSet();
    _events.removeWhere((item) => gone.contains(item['id']));
    _reports.removeWhere((item) => gone.contains(item['id']));
  }

  void clear() {
    _events.clear();
    _reports.clear();
  }

  /// Keeps the outbox within its bounds (see the class).
  void prune(DateTime now) {
    final oldest = now.subtract(maxAge);
    bool tooOld(Map<String, Object?> item) {
      final at = DateTime.tryParse('${item['at']}');
      return at == null || at.isBefore(oldest);
    }

    _events.removeWhere(tooOld);
    _reports.removeWhere(tooOld);
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
    if (_reports.length > maxReports) {
      _reports.removeRange(0, _reports.length - maxReports);
    }
    var size = _encode().length;
    while (size > maxBytes && !isEmpty) {
      // Many at a time: re-encoding after each of two thousand events
      // would cost more than the events are worth.
      if (_events.isNotEmpty) {
        _events.removeRange(0, (_events.length / 10).ceil());
      } else {
        _reports.removeAt(0);
      }
      size = _encode().length;
    }
  }

  String _encode() =>
      jsonEncode(<String, Object?>{'events': _events, 'reports': _reports});

  String toJson() => _encode();
}
