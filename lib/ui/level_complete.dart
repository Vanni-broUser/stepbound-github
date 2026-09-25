import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

/// How a level went: each count out of what the level holds, but for the
/// steps, which have no end.
final class LevelStats {
  const LevelStats({
    required this.foundBackpacks,
    required this.totalBackpacks,
    required this.foundMemories,
    required this.totalMemories,
    required this.killedZombies,
    required this.totalZombies,
    required this.knownZombieKinds,
    required this.totalZombieKinds,
    required this.litCampfires,
    required this.totalCampfires,
    required this.steps,
  });

  final int foundBackpacks;
  final int totalBackpacks;

  /// Distinct story pictures, not dialogue lines.
  final int foundMemories;
  final int totalMemories;
  final int killedZombies;
  final int totalZombies;
  final int knownZombieKinds;
  final int totalZombieKinds;
  final int litCampfires;
  final int totalCampfires;
  final int steps;
}

/// The black results screen shown between the last story scene and the
/// Europe map.
final class LevelComplete extends StatelessWidget {
  const LevelComplete({
    required this.stats,
    required this.onContinue,
    super.key,
  });

  final LevelStats stats;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('level-complete'),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit =
              constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BloodyTitle('LIVELLO COMPLETATO', fontSize: 20 * unit),
                SizedBox(height: 6 * unit),
                MenuPanel(
                  unit: unit,
                  width: cardWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _column(unit, <(String, String, String)>[
                          (
                            'ZAINI TROVATI',
                            '${stats.foundBackpacks} / ${stats.totalBackpacks}',
                            'backpack-stat',
                          ),
                          (
                            'RICORDI VISSUTI',
                            '${stats.foundMemories} / ${stats.totalMemories}',
                            'memory-stat',
                          ),
                          (
                            'FALÒ TROVATI',
                            '${stats.litCampfires} / ${stats.totalCampfires}',
                            'campfire-stat',
                          ),
                        ]),
                      ),
                      SizedBox(width: columnGap * unit),
                      Expanded(
                        child: _column(unit, <(String, String, String)>[
                          (
                            'TIPI DI ZOMBI CONOSCIUTI',
                            '${stats.knownZombieKinds} / '
                                '${stats.totalZombieKinds}',
                            'zombie-kind-stat',
                          ),
                          (
                            'ZOMBI UCCISI',
                            '${stats.killedZombies} / ${stats.totalZombies}',
                            'kill-stat',
                          ),
                          ('PASSI FATTI', '${stats.steps}', 'step-stat'),
                        ]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8 * unit),
                MenuButton(
                  key: const ValueKey<String>('level-complete-continue'),
                  label: 'CONTINUA',
                  unit: unit,
                  onPressed: onContinue,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Wider than the menu's panels, for the two columns of figures.
  static const double cardWidth = 300;
  static const double columnGap = 12;

  /// One column of the card: label and figure, row after row.
  Widget _column(double unit, List<(String, String, String)> rows) => Column(
    children: <Widget>[
      for (final (index, (label, value, key)) in rows.indexed) ...<Widget>[
        if (index > 0) SizedBox(height: 4 * unit),
        _stat(label, value, unit, ValueKey<String>(key)),
      ],
    ],
  );

  Widget _stat(String label, String value, double unit, Key key) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: const Color(0xffe8dccb),
              fontFamily: 'monospace',
              fontSize: 8 * unit,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        SizedBox(width: 5 * unit),
        Text(
          value,
          style: TextStyle(
            color: BloodColors.bright,
            fontFamily: 'monospace',
            fontSize: 10 * unit,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
