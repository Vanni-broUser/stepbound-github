import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stepbound/game/stepbound_game.dart';

/// Whether the build shows [DiagnosticsOverlay]: only one built with
/// `--dart-define=STEPBOUND_DIAGNOSTICS=true`, to measure a release on a
/// phone (docs/maintainability_and_scalability_backlog.md).
const bool diagnosticsEnabled = bool.fromEnvironment('STEPBOUND_DIAGNOSTICS');

/// A line in a corner over the game: frames per second, the slowest frame
/// of the last second (the longest gap between two), how long the game
/// took to load and how long the last area took to compose.
final class DiagnosticsOverlay extends StatefulWidget {
  const DiagnosticsOverlay({required this.game, super.key});

  final StepboundGame game;

  @override
  State<DiagnosticsOverlay> createState() => _DiagnosticsOverlayState();
}

final class _DiagnosticsOverlayState extends State<DiagnosticsOverlay>
    with SingleTickerProviderStateMixin {
  late final Timer _tick;
  late final Ticker _frameTicker;
  int _frames = 0;
  Duration _lastFrame = Duration.zero;
  Duration _slowest = Duration.zero;
  String _line = '';

  @override
  void initState() {
    super.initState();
    // Called once a frame: the gap between two is how long a frame took.
    _frameTicker = createTicker(_onFrame);
    unawaited(_frameTicker.start());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _onFrame(Duration elapsed) {
    _frames++;
    final gap = elapsed - _lastFrame;
    _lastFrame = elapsed;
    if (gap > _slowest) {
      _slowest = gap;
    }
  }

  void _refresh() {
    String ms(Duration? duration) =>
        duration == null ? '-' : '${duration.inMilliseconds} ms';
    setState(() {
      _line =
          '$_frames fps · frame max ${ms(_slowest)} · '
          'avvio ${ms(widget.game.loadTime)} · '
          'area ${ms(widget.game.lastAreaLoad)}';
    });
    _frames = 0;
    _slowest = Duration.zero;
  }

  @override
  void dispose() {
    _tick.cancel();
    _frameTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.topCenter,
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            _line,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 11),
          ),
        ),
      ),
    ),
  );
}
