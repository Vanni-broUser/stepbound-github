import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stepbound/app_services.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/ui/error_screen.dart';

/// How a report leaves the phone: the file's name and its text.
typedef ShareReport = Future<void> Function(String fileName, String text);

/// Sits over the whole app. While [reporter] holds no error, [child] is
/// the app; once it does, the [ErrorScreen] takes its place, with the
/// sound paused, until the player goes back to the menu: then [child] is
/// built anew, from the main menu, as a fresh start of the app would be.
/// What the app runs on, [services], outlives it here: the app under the
/// error screen goes, and the one built anew runs on the same services,
/// which the guard closes when the engine lets go of the process.
final class CrashGuard extends StatefulWidget {
  const CrashGuard({
    required this.reporter,
    required this.child,
    required this.share,
    this.services,
    super.key,
  });

  final ErrorReporter reporter;
  final Widget child;
  final ShareReport share;

  /// What [child] runs on, owned here for as long as the process lives:
  /// its sound is paused while the error is on screen and resumed with
  /// the menu, and all of it is closed when the guard goes or the engine
  /// lets go of the app. The app under the guard must be handed these
  /// same services, so that it leaves them to the guard to close.
  final AppServices? services;

  @override
  State<CrashGuard> createState() => _CrashGuardState();
}

final class _CrashGuardState extends State<CrashGuard> {
  /// Bumped every time the app starts over: a new key, a new state.
  int _generation = 0;
  bool _sharing = false;

  /// The engine letting go of the app: the last chance to close what was
  /// made for it (the phone's sound), before the process ends.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.reporter.addListener(_onReport);
    _lifecycle = AppLifecycleListener(
      onDetach: () => unawaited(widget.services?.dispose()),
    );
  }

  @override
  void didUpdateWidget(CrashGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reporter != widget.reporter) {
      oldWidget.reporter.removeListener(_onReport);
      widget.reporter.addListener(_onReport);
    }
  }

  @override
  void dispose() {
    widget.reporter.removeListener(_onReport);
    _lifecycle.dispose();
    unawaited(widget.services?.dispose());
    super.dispose();
  }

  /// An error can be reported in the middle of a frame, from a build or a
  /// layout: the switch then waits for the frame to end.
  void _onReport() {
    if (widget.reporter.report != null) {
      widget.services?.audio.pause();
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        })
        ..ensureVisualUpdate();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _share(ErrorReport report) async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final text = await widget.reporter.render(report);
      await widget.share(widget.reporter.fileNameFor(report), text);
    } on Object catch (error) {
      debugPrint('report: could not share ($error)');
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  void _backToMenu() {
    _generation += 1;
    widget.services?.audio.resume();
    widget.reporter.reset();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.reporter.report;
    if (report == null) {
      return KeyedSubtree(key: ValueKey<int>(_generation), child: widget.child);
    }
    return MaterialApp(
      title: 'Stepbound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: PixelPalette.screenBlack,
      ),
      home: ErrorScreen(
        summary: report.summary,
        sharing: _sharing,
        onShare: () => unawaited(_share(report)),
        onMenu: _backToMenu,
      ),
    );
  }
}
