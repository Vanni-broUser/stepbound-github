import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/mission_marks.dart';

/// What Mario has to do, in the top-left corner: the city's name written
/// in blood and underlined by hand, then the open missions one under the
/// other, each beside its box. One just done is crossed out in blood and
/// goes. With nothing to do, the corner is empty.
final class MissionBoard extends StatelessWidget {
  const MissionBoard({required this.game, super.key});

  final StepboundGame game;

  /// As wide as the corner lets a mission run before it wraps.
  static const double maxWidth = 196;
  static const double titleSize = 12;
  static const double textSize = 9;
  static const double boxSize = 10;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BoardMission>>(
      valueListenable: game.missions,
      builder: (context, rows, _) {
        if (rows.isEmpty) {
          return const SizedBox.shrink();
        }
        return ConstrainedBox(
          key: const ValueKey<String>('mission-board'),
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            // A shade behind, so white reads over any street, fading out
            // towards the middle of the screen.
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0x8c000000), Color(0x00000000)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 10, 4),
              // As wide as the longest mission, the boxes one under the
              // other down its left edge, the city over them.
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: _CityHeading(
                        AdventureStats.cityName(game.progress.level),
                      ),
                    ),
                    for (final row in rows)
                      _MissionRow(
                        key: ValueKey<Mission>(row.mission),
                        mission: row.mission,
                        done: row.done,
                        onGone: () => game.missionCrossedOut(row.mission),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The city's name in blood, a smear drawn under it slightly uphill.
final class _CityHeading extends StatelessWidget {
  const _CityHeading(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    const size = MissionBoard.titleSize;
    return SizedBox(
      // The title reserves room under it for its drips: only the top of
      // that is kept, so the list starts close under the line.
      height: size * 1.95,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: <Widget>[
          const Positioned(
            // Under the letters, rising only a little from left to right.
            left: -2,
            right: -6,
            top: size * 0.98,
            height: size * 0.52,
            child: CustomPaint(painter: BloodSlashPainter(thickness: 3.2)),
          ),
          BloodyTitle(
            name,
            key: const ValueKey<String>('mission-board-city'),
            fontSize: size,
          ),
        ],
      ),
    );
  }
}

/// One mission and its box. It fades in when handed out; once [done], it
/// waits a moment, is crossed out stroke by stroke, stays crossed a moment
/// and folds away, then [onGone].
final class _MissionRow extends StatefulWidget {
  const _MissionRow({
    required this.mission,
    required this.done,
    required this.onGone,
    super.key,
  });

  final Mission mission;
  final bool done;
  final VoidCallback onGone;

  /// Waiting, crossing, looking at it crossed, folding away.
  static const Duration crossOut = Duration(milliseconds: 2300);

  @override
  State<_MissionRow> createState() => _MissionRowState();
}

final class _MissionRowState extends State<_MissionRow>
    with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _cross = AnimationController(
    vsync: this,
    duration: _MissionRow.crossOut,
  );

  /// The strokes, then the fold, as parts of [_cross].
  late final Animation<double> _strokes = CurvedAnimation(
    parent: _cross,
    curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _fold = CurvedAnimation(
    parent: _cross,
    curve: const Interval(0.78, 1, curve: Curves.easeInCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.done) {
      _appear.value = 1;
      unawaited(_crossOut());
    } else {
      unawaited(_appear.forward());
    }
  }

  @override
  void didUpdateWidget(_MissionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      unawaited(_crossOut());
    } else if (!widget.done && oldWidget.done) {
      // Handed out again before it was gone.
      _cross.value = 0;
    }
  }

  Future<void> _crossOut() async {
    try {
      await _cross.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && widget.done) {
      widget.onGone();
    }
  }

  @override
  void dispose() {
    _appear.dispose();
    _cross.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_appear, _cross]),
      builder: (context, _) {
        final shown = _appear.value * (1 - _fold.value);
        return Align(
          alignment: Alignment.topLeft,
          heightFactor: 1 - _fold.value,
          child: Opacity(
            opacity: shown.clamp(0, 1),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: CustomPaint(
                      key: ValueKey<String>(
                        'mission-box-${widget.mission.name}',
                      ),
                      size: const Size.square(MissionBoard.boxSize),
                      painter: MissionBoxPainter(
                        crossed: _strokes.value,
                        seed: widget.mission.index,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      widget.mission.text,
                      key: ValueKey<String>(
                        'mission-text-${widget.mission.name}',
                      ),
                      style: missionTextStyle(MissionBoard.textSize),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
