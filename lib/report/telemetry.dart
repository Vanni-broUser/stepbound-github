import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/report/telemetry_outbox.dart';
import 'package:stepbound/report/telemetry_transport.dart';

/// The `stepbound-be` server the app sends to, given by CI as
/// `--dart-define=STEPBOUND_TELEMETRY_URL=https://…`. Empty in a local
/// build: nothing is collected and nothing leaves the phone.
const String telemetryUrl = String.fromEnvironment('STEPBOUND_TELEMETRY_URL');

/// The key the server asks of the app (`INGEST_KEY` on the server), given
/// as `--dart-define=STEPBOUND_TELEMETRY_KEY=…`. It ships in the APK: it
/// keeps stray traffic out, it guards nothing.
const String telemetryKey = String.fromEnvironment('STEPBOUND_TELEMETRY_KEY');

/// Where the switch, the install id and the outbox are kept.
abstract interface class TelemetryStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// The phone's own storage, next to the saves.
final class PreferencesTelemetryStore implements TelemetryStore {
  PreferencesTelemetryStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Sends, on its own, what the players would otherwise have to send by
/// hand: the report of an error nobody caught, and anonymous events of how
/// the game is played (levels started and completed, zombies killed,
/// deaths, places reached, time played). See `docs/telemetry.md`.
///
/// The game never waits for it and never needs the network: everything
/// goes first into an outbox on the phone ([TelemetryOutbox]), and leaves
/// when the server can be reached: at start, whenever the app comes back
/// to the front, after an error, and every [flushThreshold] events. What
/// cannot leave waits for the next time, within the outbox's bounds.
///
/// Players are known by a random id made at the first start, nothing
/// else. The switch in the pause menu turns it all off: the outbox is
/// emptied, the id forgotten, and the server asked to delete what it holds
/// under it (asked again at every start until it answers).
final class Telemetry {
  Telemetry({
    this._clock = DateTime.now,
    Random? random,
    this.persistDelay = const Duration(seconds: 3),
    this.flushThreshold = 50,
    this.batchEvents = 200,
    this.batchReports = 1,
    TelemetryOutbox Function(String? encoded)? outbox,
  }) : _random = random ?? Random.secure(),
       _readOutbox = outbox ?? TelemetryOutbox.fromJson;

  /// The one the whole app tracks to; [start]ed by `bootstrap`. Until
  /// then, in tests and in a local build, every call is a no-op.
  static final Telemetry shared = Telemetry();

  static const String enabledKey = 'telemetry.enabled';
  static const String installIdKey = 'telemetry.installId';
  static const String outboxKey = 'telemetry.outbox';
  static const String forgetKey = 'telemetry.forget';

  /// How long after an event the outbox is written down: a burst of kills
  /// is one write, not one each.
  final Duration persistDelay;

  /// Events waiting past this many are sent without waiting for the app
  /// to come back to the front.
  final int flushThreshold;

  /// How many events and reports go in one request.
  final int batchEvents;
  final int batchReports;

  final DateTime Function() _clock;
  final Random _random;
  final TelemetryOutbox Function(String? encoded) _readOutbox;

  TelemetryStore? _store;
  TelemetryTransport? _transport;
  bool _started = false;
  bool _enabled = true;
  String? _installId;
  String? _pendingForget;
  late final String _session = _uuid();
  Map<String, Object?> _app = const <String, Object?>{};
  TelemetryOutbox _outbox = TelemetryOutbox();

  Timer? _persistTimer;
  Future<void>? _flushing;
  DateTime? _retryAfter;
  static const Duration _firstBackoff = Duration(minutes: 1);
  static const Duration _lastBackoff = Duration(minutes: 30);
  Duration _backoff = _firstBackoff;
  final Stopwatch _foreground = Stopwatch();

  /// Whether this build has a server to send to: without one there is
  /// nothing to switch off.
  bool get available => _started && _transport != null;

  /// Whether the player lets the app send (on unless turned off).
  bool get enabled => _enabled;

  /// Whether events are being collected right now.
  bool get active => available && _enabled && _installId != null;

  /// What is waiting to leave, for tests and diagnostics.
  TelemetryOutbox get outbox => _outbox;

  /// Reads the switch, the id and the outbox, and sends what was left
  /// waiting. [transport] null (a local build) leaves it all off. [app]
  /// says what the app and the phone are, once, for every batch.
  Future<void> start({
    required TelemetryStore store,
    required TelemetryTransport? transport,
    Future<Map<String, Object?>> Function()? app,
  }) async {
    _store = store;
    _transport = transport;
    if (transport == null) {
      _started = true;
      return;
    }
    try {
      _enabled = await store.read(enabledKey) != 'false';
      _pendingForget = await store.read(forgetKey);
      _installId = await store.read(installIdKey);
      if (_enabled && _installId == null) {
        _installId = _newInstallId();
        await store.write(installIdKey, _installId!);
      }
      _outbox = _readOutbox(await store.read(outboxKey))..prune(_clock());
    } on Object catch (error) {
      debugPrint('telemetry: could not read its state ($error)');
    }
    try {
      _app =
          await (app?.call() ??
              Future<Map<String, Object?>>.value(const <String, Object?>{}));
    } on Object catch (error) {
      debugPrint('telemetry: could not read the app details ($error)');
    }
    _started = true;
    _foreground
      ..reset()
      ..start();
    track('app_opened');
    unawaited(flush(force: true));
  }

  /// Turns sending on or off. Off empties the outbox and forgets the id,
  /// asking the server to delete what it holds under it; on again starts
  /// with a new id, unrelated to the old one.
  Future<void> setEnabled({required bool enabled}) async {
    final store = _store;
    if (enabled == _enabled || store == null) {
      _enabled = enabled;
      return;
    }
    _enabled = enabled;
    await store.write(enabledKey, '$enabled');
    if (enabled) {
      _installId = _newInstallId();
      await store.write(installIdKey, _installId!);
      track('app_opened');
      return;
    }
    _persistTimer?.cancel();
    _outbox.clear();
    await store.remove(outboxKey);
    final old = _installId;
    _installId = null;
    await store.remove(installIdKey);
    if (old != null) {
      _pendingForget = old;
      await store.write(forgetKey, old);
    }
    // A batch on its way under the old id is let go first: the request to
    // forget it comes after.
    unawaited(
      (_flushing ?? Future<void>.value()).then((_) => flush(force: true)),
    );
  }

  /// Something happened in the game worth counting. [data] is JSON: names
  /// and numbers, never anything the player typed.
  void track(String type, [Map<String, Object?> data = const {}]) {
    if (!active) {
      return;
    }
    _outbox.addEvent(<String, Object?>{
      'id': _uuid(),
      'type': type,
      'at': _clock().toUtc().toIso8601String(),
      'session': _session,
      'data': data,
    });
    _schedulePersist();
    if (_outbox.events.length >= flushThreshold) {
      unawaited(flush());
    }
  }

  /// The report of an error, as the player would have shared it, to send
  /// on its own. Written down at once: the app may not live much longer.
  Future<void> sendReport({
    required DateTime at,
    required String source,
    required String summary,
    required String text,
  }) async {
    if (!active) {
      return;
    }
    _outbox
      ..addReport(<String, Object?>{
        'id': _uuid(),
        'at': at.toUtc().toIso8601String(),
        'source': source,
        'summary': summary.length > 500 ? summary.substring(0, 500) : summary,
        'text': fit(text),
      })
      ..prune(_clock());
    await persist();
    unawaited(flush(force: true));
  }

  /// Every error [reporter] shows is sent, rendered as the player would
  /// have shared it.
  void watch(ErrorReporter reporter) {
    ErrorReport? sent;
    reporter.addListener(() {
      final report = reporter.report;
      if (report == null || identical(report, sent)) {
        return;
      }
      sent = report;
      unawaited(_sendRendered(reporter, report));
    });
  }

  Future<void> _sendRendered(ErrorReporter reporter, ErrorReport report) async {
    if (!active) {
      return;
    }
    try {
      await sendReport(
        at: report.at,
        source: report.source,
        summary: report.summary,
        text: await reporter.render(report),
      );
    } on Object catch (error) {
      debugPrint('telemetry: could not send the report ($error)');
    }
  }

  /// The app is in front again: the clock of the visit starts, and what
  /// waits is tried at once, whatever the last failure.
  void cameToFront() {
    if (!available) {
      return;
    }
    _foreground.start();
    unawaited(flush(force: true));
  }

  /// The app has left the front (every step of the way out calls it): the
  /// visit is counted once, the outbox written down, and sent if it can
  /// be before the phone puts the app to sleep.
  void leftFront() {
    if (!available) {
      return;
    }
    final seconds = _foreground.elapsed.inSeconds;
    _foreground
      ..stop()
      ..reset();
    if (seconds > 0) {
      track('session_ended', <String, Object?>{'seconds': seconds});
    }
    if (active) {
      unawaited(persist());
    }
    unawaited(flush(force: true));
  }

  /// Writes the outbox down now.
  Future<void> persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    final store = _store;
    if (store == null || !_enabled) {
      return;
    }
    try {
      _outbox.prune(_clock());
      await store.write(outboxKey, _outbox.toJson());
    } on Object catch (error) {
      debugPrint('telemetry: could not write the outbox ($error)');
    }
  }

  void _schedulePersist() {
    _persistTimer ??= Timer(persistDelay, () => unawaited(persist()));
  }

  /// Sends what waits, a batch at a time, until the outbox is empty or a
  /// batch fails; one at a time. After a failure nothing is tried again
  /// for a while (one minute, doubling up to half an hour), unless
  /// [force]d: the app coming back to the front, an error.
  Future<void> flush({bool force = false}) {
    final running = _flushing;
    if (running != null) {
      return running;
    }
    if (!available) {
      return Future<void>.value();
    }
    final retryAfter = _retryAfter;
    if (!force && retryAfter != null && _clock().isBefore(retryAfter)) {
      return Future<void>.value();
    }
    return _flushing = _flush().whenComplete(() => _flushing = null);
  }

  Future<void> _flush() async {
    final transport = _transport!;
    final forget = _pendingForget;
    if (forget != null) {
      final outcome = await transport('/v1/forget', <String, Object?>{
        'installId': forget,
      });
      if (outcome == SendOutcome.failed) {
        _failed();
        return;
      }
      _pendingForget = null;
      await _store?.remove(forgetKey);
    }
    var sent = false;
    while (active && !_outbox.isEmpty) {
      final events = _outbox.events.take(batchEvents).toList();
      final reports = _outbox.reports.take(batchReports).toList();
      final outcome = await transport('/v1/ingest', <String, Object?>{
        'installId': _installId,
        'app': _app,
        'events': events,
        'reports': reports,
      });
      if (outcome == SendOutcome.failed) {
        _failed();
        return;
      }
      if (outcome == SendOutcome.rejected) {
        debugPrint('telemetry: a batch was refused and dropped');
      }
      _outbox.remove(<String>[
        for (final item in <Map<String, Object?>>[...events, ...reports])
          item['id']! as String,
      ]);
      sent = true;
    }
    _retryAfter = null;
    _backoff = _firstBackoff;
    if (sent) {
      await persist();
    }
  }

  void _failed() {
    _retryAfter = _clock().add(_backoff);
    final next = _backoff * 2;
    _backoff = next > _lastBackoff ? _lastBackoff : next;
  }

  /// Stops the pending write; the outbox stays as last written.
  void dispose() {
    _persistTimer?.cancel();
    _persistTimer = null;
  }

  /// [text] if it fits in [maxBytes] of UTF-8; otherwise its head, where
  /// the error and its stack are, and its tail, where the trail ends, with
  /// a line saying how much was cut from between them (the save, mostly).
  static String fit(String text, {int maxBytes = 150 * 1024}) {
    final bytes = utf8.encode(text);
    if (bytes.length <= maxBytes) {
      return text;
    }
    final head = maxBytes * 2 ~/ 3;
    final tail = maxBytes ~/ 4;
    final cut = bytes.length - head - tail;
    String decode(List<int> part) => utf8.decode(part, allowMalformed: true);
    return '${decode(bytes.sublist(0, head))}'
        '\n\n[… rapporto tagliato: $cut byte in meno …]\n\n'
        '${decode(bytes.sublist(bytes.length - tail))}';
  }

  String _newInstallId() => <String>[
    for (var i = 0; i < 16; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  /// A random (version 4) UUID.
  String _uuid() {
    final bytes = <int>[for (var i = 0; i < 16; i++) _random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
