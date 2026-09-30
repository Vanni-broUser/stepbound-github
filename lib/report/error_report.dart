import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/device_info.dart';

/// The commit the build was made from, given by CI as
/// `--dart-define=STEPBOUND_COMMIT=<sha>`; a local build says so.
const String buildCommit = String.fromEnvironment(
  'STEPBOUND_COMMIT',
  defaultValue: 'build locale',
);

/// An error nobody caught, as it was reported.
final class ErrorReport {
  const ErrorReport({
    required this.error,
    required this.at,
    required this.source,
    this.stack,
  });

  final Object error;
  final StackTrace? stack;

  /// Where it came from: the Flutter library that reported it, or `async`
  /// for one that fell out of a future.
  final String source;
  final DateTime at;

  /// The first line of the error, for the screen.
  String get summary {
    final text = error.toString().trim();
    final end = text.indexOf('\n');
    return end < 0 ? text : text.substring(0, end);
  }
}

/// A titled part of the report the app adds: the slot in play, the save.
final class ReportSection {
  const ReportSection(this.title, this.body);

  final String title;
  final String body;
}

/// What the app knows at the time of the error, asked when the report is
/// written. It may throw or hang: the report then says so and goes on.
typedef ReportContext = Future<List<ReportSection>> Function();

/// Catches what nobody else caught, keeps the first such error and tells
/// the `CrashGuard` over the app, which shows it and offers the report.
/// In a release build these errors otherwise go to a console nobody
/// reads, and the player is left with a game that no longer answers.
final class ErrorReporter extends ChangeNotifier {
  ErrorReporter({
    Breadcrumbs? breadcrumbs,
    this._clock = DateTime.now,
    this._device = DeviceInfo.read,
  }) : breadcrumbs = breadcrumbs ?? Breadcrumbs.shared;

  final DateTime Function() _clock;
  final Future<DeviceInfo> Function() _device;
  final Breadcrumbs breadcrumbs;

  /// Set by the app: what it adds to a report. Asked the moment an error
  /// is recorded, while the app is still there to answer: the error
  /// screen takes its place right after, and its answer would be gone
  /// with it.
  ReportContext? context;

  /// How long the phone and the app are given to answer.
  static const Duration patience = Duration(seconds: 5);

  ErrorReport? _report;

  /// What the app said at the moment of [report], kept for its rendering.
  ({ErrorReport report, Future<List<ReportSection>> sections})? _captured;

  /// The error being shown, null while the game runs.
  ErrorReport? get report => _report;

  /// Hooks the framework's and the platform's uncaught-error handlers.
  /// The handler that was there keeps running first, so a debug build
  /// still prints to the console and tests still fail.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      record(
        details.exception,
        details.stack,
        source: details.library ?? 'flutter',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, source: 'async');
      return true;
    };
  }

  /// Keeps [error] if none is being shown: the ones after it, a frame
  /// failing again and again, follow from the first.
  void record(Object error, StackTrace? stack, {required String source}) {
    if (_report != null) {
      return;
    }
    final report = ErrorReport(
      error: error,
      stack: stack,
      source: source,
      at: _clock(),
    );
    _report = report;
    if (context != null) {
      _captured = (report: report, sections: _askContext());
    }
    notifyListeners();
  }

  /// What the app adds right now; what it throws is a section of its own.
  /// The future never fails: nobody may be waiting on it when it does.
  Future<List<ReportSection>> _askContext() async {
    final ask = context;
    if (ask == null) {
      return const <ReportSection>[];
    }
    try {
      return await ask();
    } on Object catch (error) {
      return <ReportSection>[
        ReportSection('Partita', 'non disponibile: $error'),
      ];
    }
  }

  /// The player goes back to the menu: the next error is a new one.
  void reset() {
    if (_report == null) {
      return;
    }
    _report = null;
    notifyListeners();
  }

  /// The file name a report is shared as.
  String fileNameFor(ErrorReport report) {
    String two(int n) => n.toString().padLeft(2, '0');
    final at = report.at;
    return 'stepbound-rapporto-${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}.txt';
  }

  /// The whole report as text: build, phone, error, what the app added
  /// when [report] was recorded (or adds now, for a report that was not),
  /// then the trail. Nothing in it can stop it from being written.
  Future<String> render(ErrorReport report) async {
    final device = await _guard(
      _device,
      (error) => const DeviceInfo(
        model: DeviceInfo.unknown,
        system: DeviceInfo.unknown,
        memory: DeviceInfo.unknown,
        appVersion: DeviceInfo.unknown,
      ),
    );
    // The error's own report has what the app said when it happened; any
    // other report (a failed save, the trail asked for) asks the app now.
    final captured = _captured;
    final sections = await _guard(
      captured != null && identical(captured.report, report)
          ? () => captured.sections
          : _askContext,
      (error) => <ReportSection>[
        ReportSection('Partita', 'non disponibile: $error'),
      ],
    );
    final out = StringBuffer()
      ..writeln('RAPPORTO DI ERRORE DI STEPBOUND')
      ..writeln('Quando: ${report.at.toIso8601String()}')
      ..writeln('Versione: ${device.appVersion}')
      ..writeln('Commit: $buildCommit')
      ..writeln('Telefono: ${device.model}')
      ..writeln('Sistema: ${device.system}')
      ..writeln('Memoria: ${device.memory}')
      ..writeln()
      ..writeln('== Errore (${report.source}) ==')
      ..writeln(report.error)
      ..writeln()
      ..writeln(report.stack ?? 'nessuno stack trace');
    for (final section in sections) {
      out
        ..writeln()
        ..writeln('== ${section.title} ==')
        ..writeln(section.body);
    }
    out
      ..writeln()
      ..writeln('== Ultimi passi ==');
    final trail = breadcrumbs.entries;
    if (trail.isEmpty) {
      out.writeln('nessuno');
    }
    trail.forEach(out.writeln);
    return out.toString();
  }

  /// [action]'s result, or [fallback]'s when it throws or takes too long.
  Future<T> _guard<T>(
    Future<T> Function() action,
    T Function(Object error) fallback,
  ) async {
    try {
      return await action().timeout(patience);
    } on Object catch (error) {
      return fallback(error);
    }
  }
}
