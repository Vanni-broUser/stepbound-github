import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/mission_marks.dart';
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
    this.doneMissions = const <Mission>[],
    this.missions = const <Mission>[],
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
      doneMissions: <Mission>[
        for (final mission in progress.missions.done)
          if (mission.level == level) mission,
      ],
      missions: Mission.of(level),
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

  /// The level's missions done, in the order the player got through them.
  final List<Mission> doneMissions;

  /// Every mission of the level.
  final List<Mission> missions;
}

/// The black results screen shown between the last story scene and the
/// Europe map.
final class LevelComplete extends StatelessWidget {
  const LevelComplete({
    required this.stats,
    required this.onContinue,
    this.finale,
    super.key,
  });

  final LevelStats stats;
  final VoidCallback onContinue;

  /// The mission the level ended on, crossed out here for all to see.
  final Mission? finale;

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
                SizedBox(height: 4 * unit),
                StatsCard(stats: stats, unit: unit),
                SizedBox(height: 4 * unit),
                MissionsCard(stats: stats, unit: unit, finale: finale),
                SizedBox(height: 6 * unit),
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
/// stands in. Under the figures, beside the way out, the memories to live
/// again and the secret missions.
final class AdventureStats extends StatefulWidget {
  const AdventureStats({
    required this.world,
    required this.progress,
    required this.onClose,
    required this.onReplayMemories,
    super.key,
  });

  final WorldState world;
  final Progress progress;
  final VoidCallback onClose;

  /// The memories of the level, as the cot plays them.
  final VoidCallback onReplayMemories;

  /// The three buttons under the figures share the cards' width.
  static const double buttonGap = 6;
  static const double buttonWidth = (StatsCard.cardWidth - 2 * buttonGap) / 3;

  /// Dims the whole screen behind the figures, the world still in view.
  static const Color backdrop = Letterbox.veil;

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

  /// Whether the secret missions are open in place of the figures.
  bool _secrets = false;

  void _turn(int by) => setState(() => _index = (_index + by) % _cities.length);

  @override
  Widget build(BuildContext context) {
    final level = _cities[_index];
    final stats = LevelStats.of(widget.world, widget.progress, level);
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
        if (_secrets) {
          return _SecretMissions(
            unit: unit,
            onBack: () => setState(() => _secrets = false),
          );
        }
        Widget button(String key, String label, VoidCallback onPressed) =>
            MenuButton(
              key: ValueKey<String>(key),
              label: label,
              unit: unit,
              compact: true,
              width: AdventureStats.buttonWidth,
              onPressed: onPressed,
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        StatsCard(stats: stats, unit: unit),
                        SizedBox(height: 4 * unit),
                        MissionsCard(
                          key: ValueKey<LevelId>(level),
                          stats: stats,
                          unit: unit,
                        ),
                      ],
                    ),
                    if (several) ...<Widget>[
                      SizedBox(width: 6 * unit),
                      arrow('>', 1),
                    ],
                  ],
                ),
                SizedBox(height: 8 * unit),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    button(
                      'adventure-stats-memories',
                      'RIVIVI I RICORDI',
                      widget.onReplayMemories,
                    ),
                    SizedBox(width: AdventureStats.buttonGap * unit),
                    button(
                      'adventure-stats-secrets',
                      'MISSIONI SEGRETE',
                      () => setState(() => _secrets = true),
                    ),
                    SizedBox(width: AdventureStats.buttonGap * unit),
                    button('adventure-stats-close', 'ESCI', widget.onClose),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The secret missions, open from the figures in their place. None has
/// been hidden in the cities yet.
final class _SecretMissions extends StatelessWidget {
  const _SecretMissions({required this.unit, required this.onBack});

  final double unit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey<String>('secret-missions'),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BloodyTitle('MISSIONI SEGRETE', fontSize: 20 * unit),
            SizedBox(height: 6 * unit),
            MenuPanel(
              unit: unit,
              width: StatsCard.cardWidth,
              child: MenuParagraph(
                'Nessuna missione segreta scoperta. Guardati intorno: '
                'qualcuno, in città, ha ancora bisogno di te',
                unit: unit,
                center: true,
              ),
            ),
            SizedBox(height: 8 * unit),
            MenuButton(
              key: const ValueKey<String>('secret-missions-back'),
              label: 'INDIETRO',
              unit: unit,
              compact: true,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

/// The level's missions under its figures: on the left the done ones in
/// the order the player got through them, then those left undone with an
/// empty box, in a list that shows three and a half rows so the half one
/// says there is more below; on the right how many are done out of all.
/// With a [finale] done, the list runs down to it and crosses it out in
/// front of the player, and the count goes up with it.
final class MissionsCard extends StatefulWidget {
  const MissionsCard({
    required this.stats,
    required this.unit,
    this.finale,
    super.key,
  });

  final LevelStats stats;
  final double unit;
  final Mission? finale;

  /// One mission's row, and how many of them show at once.
  static const double rowHeight = 10;
  static const double visibleRows = 3.5;

  @override
  State<MissionsCard> createState() => _MissionsCardState();
}

final class _MissionsCardState extends State<MissionsCard>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _finale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// The finale being crossed out on this screen, if there is one.
  Mission? get _celebrated => switch (widget.finale) {
    final finale? when widget.stats.doneMissions.contains(finale) => finale,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    if (_celebrated != null) {
      unawaited(_celebrate());
    }
  }

  /// A moment to read the screen, down to the finale, then the cross.
  Future<void> _celebrate() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    // Down just far enough for its row to be the last one whole in view.
    final row = widget.stats.doneMissions.indexOf(_celebrated!);
    if (_scroll.hasClients) {
      final rowHeight = MissionsCard.rowHeight * widget.unit;
      final target = (row + 1 - MissionsCard.visibleRows.floor()) * rowHeight;
      await _scroll.animateTo(
        target.clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
    if (!mounted) {
      return;
    }
    try {
      await _finale.forward().orCancel;
    } on TickerCanceled {
      return;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _finale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final stats = widget.stats;
    final celebrated = _celebrated;
    final undone = <Mission>[
      for (final mission in stats.missions)
        if (!stats.doneMissions.contains(mission)) mission,
    ];
    final listHeight = MissionsCard.rowHeight * MissionsCard.visibleRows * unit;
    return MenuPanel(
      key: const ValueKey<String>('missions-card'),
      unit: unit,
      width: StatsCard.cardWidth,
      child: AnimatedBuilder(
        animation: _finale,
        builder: (context, _) {
          // The strokes take the first half; the count goes up as the
          // second lands, and swells with it.
          final strokes = Curves.easeOut.transform(
            (_finale.value / 0.6).clamp(0, 1),
          );
          final landed = celebrated == null || strokes >= 1;
          final done = stats.doneMissions.length - (landed ? 0 : 1);
          final swell = celebrated == null
              ? 0.0
              : math.sin(math.pi * ((_finale.value - 0.55) / 0.45).clamp(0, 1));
          return Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: listHeight,
                  child: ListView(
                    key: const ValueKey<String>('missions-list'),
                    controller: _scroll,
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      for (final mission in stats.doneMissions)
                        _row(
                          mission,
                          crossed: mission == celebrated ? strokes : 1,
                          boxScale: mission == celebrated ? 1 + swell * 0.5 : 1,
                        ),
                      for (final mission in undone) _row(mission, crossed: 0),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6 * unit),
              Container(
                width: 1.5 * unit,
                height: listHeight,
                color: BloodColors.fresh,
              ),
              SizedBox(width: 6 * unit),
              SizedBox(
                width: 62 * unit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'MISSIONI',
                      style: TextStyle(
                        color: menuTextColour,
                        fontFamily: 'monospace',
                        fontSize: 8 * unit,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 3 * unit),
                    Transform.scale(
                      scale: 1 + swell * 0.35,
                      child: Text(
                        '$done / ${stats.missions.length}',
                        key: const ValueKey<String>('mission-stat'),
                        style: TextStyle(
                          color: swell > 0.05
                              ? Color.lerp(
                                  menuTextColour,
                                  BloodColors.bright,
                                  swell,
                                )
                              : menuTextColour,
                          fontFamily: 'monospace',
                          fontSize: 14 * unit,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Mission mission, {required double crossed, double boxScale = 1}) {
    final unit = widget.unit;
    final box = 7 * unit;
    return SizedBox(
      key: ValueKey<String>('mission-row-${mission.name}'),
      height: MissionsCard.rowHeight * unit,
      child: Row(
        children: <Widget>[
          SizedBox(width: 1.5 * unit),
          Transform.scale(
            scale: boxScale,
            child: CustomPaint(
              size: Size.square(box),
              painter: MissionBoxPainter(
                crossed: crossed,
                border: unit,
                seed: mission.index,
              ),
            ),
          ),
          SizedBox(width: 5 * unit),
          Expanded(
            child: Opacity(
              opacity: crossed > 0 ? 1 : 0.62,
              child: Text(
                mission.text,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: missionTextStyle(7 * unit),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
