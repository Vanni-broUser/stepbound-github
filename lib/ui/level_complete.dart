import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/zombie_book.dart';

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

  /// How [level] stands in [world], as far as [progress] has got: only
  /// what belongs to that city is counted.
  factory LevelStats.of(WorldState world, Progress progress, LevelId level) {
    Set<String> pictures(Iterable<StoryMemory> memories) => <String>{
      for (final memory in memories)
        for (final scene in memoryScenes[memory] ?? const <StoryScene>[])
          scene.image,
    };
    // The level's own: Rome's story is not left behind in Molfetta.
    bool ofLevel(StoryMemory memory) => memory.level == level;
    final zombies = levelZombieKinds(level);
    final campfires = levelCampfires(level);
    final pickups = world.pickups.values.where(
      (pickup) => isInLevel(pickup.position, level),
    );
    return LevelStats(
      foundBackpacks: pickups.where((pickup) => pickup.collected).length,
      totalBackpacks: pickups.length,
      foundMemories: pictures(progress.memories.where(ofLevel)).length,
      totalMemories: pictures(StoryMemory.values.where(ofLevel)).length,
      killedZombies: world.entities.values
          .where(
            (entity) =>
                entity.kind != EntityKind.player &&
                !entity.isAlive &&
                isInLevel(
                  entity.component<PositionComponent>().position,
                  level,
                ),
          )
          .length,
      totalZombies: zombies.length,
      knownZombieKinds: progress.knownZombies.where(zombies.contains).length,
      totalZombieKinds: zombies.toSet().length,
      litCampfires: progress.litCampfires.where(campfires.contains).length,
      totalCampfires: campfires.length,
      steps: progress.steps[level] ?? 0,
    );
  }

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
                StatsCard(stats: stats, unit: unit),
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
}

/// The figures of a level on a dark plate, in two columns: what the end
/// of a level shows, and what the abacus aboard the train shows again.
final class StatsCard extends StatelessWidget {
  const StatsCard({required this.stats, required this.unit, super.key});

  final LevelStats stats;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return MenuPanel(
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
                'ZOMBI CONOSCIUTI',
                '${stats.knownZombieKinds} / ${stats.totalZombieKinds}',
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
              color: menuTextColour,
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
            color: menuTextColour,
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

/// The abacus and the calculator on Mario's desk aboard the train: the
/// same figures as at the end of a level, for any city Mario has been to,
/// its name written in blood above them. The arrows go from one city to
/// the next, and show only once there is more than one: Rome is there
/// once the train has taken him there. It opens on the city the train
/// stands in.
final class AdventureStats extends StatefulWidget {
  const AdventureStats({
    required this.world,
    required this.progress,
    required this.onClose,
    super.key,
  });

  final WorldState world;
  final Progress progress;
  final VoidCallback onClose;

  /// Dims the whole screen behind the figures, the world still in view.
  static const Color backdrop = Color(0xe0100a08);

  /// What each city is called over its figures.
  static String cityName(LevelId level) => switch (level) {
    LevelId.hometown => 'CITTÀ NATALE',
    LevelId.rome => 'ROMA',
  };

  @override
  State<AdventureStats> createState() => _AdventureStatsState();
}

final class _AdventureStatsState extends State<AdventureStats> {
  late final List<LevelId> _cities = <LevelId>[
    for (final level in LevelId.values)
      if (widget.progress.visited(level)) level,
  ];
  late int _index = _cities.indexOf(widget.progress.level).clamp(0, 99);

  void _turn(int by) => setState(() => _index = (_index + by) % _cities.length);

  @override
  Widget build(BuildContext context) {
    final level = _cities[_index];
    final several = _cities.length > 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        Widget arrow(String label, int by) => MenuButton(
          key: ValueKey<String>('adventure-stats-${by < 0 ? 'prev' : 'next'}'),
          label: label,
          unit: unit,
          compact: true,
          width: 22,
          onPressed: () => _turn(by),
        );
        return SizedBox.expand(
          key: const ValueKey<String>('adventure-stats'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BloodyTitle(
                  AdventureStats.cityName(level),
                  key: ValueKey<String>('adventure-stats-${level.name}'),
                  fontSize: 20 * unit,
                ),
                SizedBox(height: 6 * unit),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (several) ...<Widget>[
                      arrow('<', -1),
                      SizedBox(width: 6 * unit),
                    ],
                    StatsCard(
                      stats: LevelStats.of(
                        widget.world,
                        widget.progress,
                        level,
                      ),
                      unit: unit,
                    ),
                    if (several) ...<Widget>[
                      SizedBox(width: 6 * unit),
                      arrow('>', 1),
                    ],
                  ],
                ),
                SizedBox(height: 8 * unit),
                MenuButton(
                  key: const ValueKey<String>('adventure-stats-close'),
                  label: 'ESCI',
                  unit: unit,
                  compact: true,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
