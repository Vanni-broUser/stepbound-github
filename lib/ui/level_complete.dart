import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/mission_marks.dart';

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
    this.openMissions = const <Mission>[],
    this.doneSecrets = const <SecretMission>[],
    this.completed = true,
  });

  /// How [level] stands in [world], as far as [progress] has got: only
  /// what belongs to that city is counted.
  factory LevelStats.of(WorldState world, Progress progress, LevelId level) {
    Set<StoryMemory> scenes(Iterable<StoryMemory> memories) => <StoryMemory>{
      for (final memory in memories) memory.scene,
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
      foundMemories: scenes(progress.memories.where(ofLevel)).length,
      totalMemories: scenes(StoryMemory.values.where(ofLevel)).length,
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
      knownZombieKinds: progress
          .zombiesKnownIn(level)
          .where(zombies.contains)
          .length,
      totalZombieKinds: zombies.toSet().length,
      litCampfires: progress.litCampfires.where(campfires.contains).length,
      totalCampfires: campfires.length,
      steps: progress.steps[level] ?? 0,
      doneMissions: <Mission>[
        for (final mission in progress.missions.done)
          if (mission.level == level) mission,
      ],
      missions: Mission.of(level),
      openMissions: <Mission>[
        for (final mission in progress.missions.open)
          if (mission.level == level) mission,
      ],
      doneSecrets: <SecretMission>[
        for (final mission in progress.secretMissions)
          if (mission.level == level) mission,
      ],
      completed: progress.completed(level),
    );
  }

  final int foundBackpacks;
  final int totalBackpacks;

  /// Story scenes, each counted whole: not its pictures, nor its lines
  /// (see [StoryMemoryLevel.scene]).
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

  /// Every mission of the level: counted, but listed only once found.
  final List<Mission> missions;

  /// The level's missions handed out and not done yet, in the order they
  /// were handed out. Those never handed out stay off the list.
  final List<Mission> openMissions;

  /// The level's secret missions done: listed with the rest, and counted
  /// apart, as a bonus over them.
  final List<SecretMission> doneSecrets;

  /// Whether the level has been played to its end. Until then its totals
  /// are not given away: each count stands over "???".
  final bool completed;

  /// Out of [total], or of "???" while the level is not over.
  String outOf(int count, int total) => '$count / ${completed ? total : '???'}';
}

/// The black results screen shown between the last story scene and the
/// Europe map.
final class LevelComplete extends StatelessWidget {
  const LevelComplete({
    required this.stats,
    required this.onContinue,
    this.finale,
    this.secret,
    this.saveFailed = false,
    this.onShareReport,
    super.key,
  });

  /// Shares the report of the failed save; the button shows only with
  /// [saveFailed].
  final VoidCallback? onShareReport;

  static String get shareLabel => strings.shareReport;

  /// From the bottom of a title's letters down to the card under it, whose
  /// top the title's drips run over.
  static const double titleGap = 14;

  final LevelStats stats;
  final VoidCallback onContinue;

  /// Whether the save aboard the train could not be written: said here,
  /// once, since the slot goes on holding the campfire before it.
  final bool saveFailed;

  static String get saveFailedLine => strings.levelCompleteSaveFailed;

  /// The mission the level ended on, crossed out here for all to see.
  final Mission? finale;

  /// A secret mission done as the level ended: crossed out with [finale].
  final SecretMission? secret;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('level-complete'),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit =
              constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
          // The failed-save line can push the column past the picture:
          // then, and only then, it all shrinks a little rather than
          // scroll. Without it the screen is laid out as it always was.
          return Center(
            child: FittedBox(
              fit: saveFailed ? BoxFit.scaleDown : BoxFit.none,
              child: DrippingOver(
                title: BloodyTitle(
                  strings.levelComplete,
                  fontSize: 20 * unit,
                  hangDrips: true,
                ),
                gap: LevelComplete.titleGap * unit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    StatsCard(stats: stats, unit: unit),
                    SizedBox(height: 4 * unit),
                    MissionsCard(
                      stats: stats,
                      unit: unit,
                      finale: finale,
                      secret: secret,
                    ),
                    if (saveFailed) ...<Widget>[
                      SizedBox(height: 3 * unit),
                      SizedBox(
                        width: StatsCard.cardWidth * unit,
                        child: Text(
                          saveFailedLine,
                          key: const ValueKey<String>(
                            'level-complete-save-failed',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BloodColors.bright,
                            fontFamily: 'monospace',
                            fontSize: 7 * unit,
                            height: 1.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      if (onShareReport case final share?) ...<Widget>[
                        SizedBox(height: 3 * unit),
                        MenuButton(
                          key: const ValueKey<String>('level-complete-share'),
                          label: shareLabel,
                          unit: unit,
                          width: 120,
                          compact: true,
                          onPressed: share,
                        ),
                      ],
                    ],
                    SizedBox(height: 6 * unit),
                    MenuButton(
                      key: const ValueKey<String>('level-complete-continue'),
                      label: strings.continueLabel,
                      unit: unit,
                      onPressed: onContinue,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The figures of a level on a dark plate, in two columns: what the end
/// of a level shows, and what the cot aboard the train shows again.
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
                strings.statBackpacks,
                stats.outOf(stats.foundBackpacks, stats.totalBackpacks),
                'backpack-stat',
              ),
              (
                strings.statMemories,
                stats.outOf(stats.foundMemories, stats.totalMemories),
                'memory-stat',
              ),
              (
                strings.statCampfires,
                stats.outOf(stats.litCampfires, stats.totalCampfires),
                'campfire-stat',
              ),
            ]),
          ),
          SizedBox(width: columnGap * unit),
          Expanded(
            child: _column(unit, <(String, String, String)>[
              (
                strings.statZombieKinds,
                stats.outOf(stats.knownZombieKinds, stats.totalZombieKinds),
                'zombie-kind-stat',
              ),
              (
                strings.statKills,
                stats.outOf(stats.killedZombies, stats.totalZombies),
                'kill-stat',
              ),
              (strings.statSteps, '${stats.steps}', 'step-stat'),
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

/// Mario's cot aboard the train: the same figures as at the end of a
/// level, for any city Mario has been to, its name written in blood above
/// them. The arrows go from one city to the next, and show only once there
/// is more than one: Rome is there once the train has taken him there.
/// They do not go round: none before the first city, none after the last
/// one reached, only the room it would take, so the cards stay put. It
/// opens on [level] or, without one, on the city the train stands in.
/// Under the figures, beside the way out, the memories of the city shown
/// to live again and, while some are left to do, its secret missions.
final class AdventureStats extends StatefulWidget {
  const AdventureStats({
    required this.world,
    required this.progress,
    required this.onClose,
    required this.onReplayMemories,
    this.level,
    super.key,
  });

  final WorldState world;
  final Progress progress;
  final VoidCallback onClose;

  /// The memories of the city shown, played again.
  final ValueChanged<LevelId> onReplayMemories;

  /// The city to open on, if not the one the train stands in.
  final LevelId? level;

  /// The three buttons under the figures share the cards' width.
  static const double buttonGap = 6;
  static const double buttonWidth = (StatsCard.cardWidth - 2 * buttonGap) / 3;

  /// Dims the whole screen behind the figures, the world still in view.
  static const Color backdrop = Letterbox.veil;

  /// What each city is called over its figures.
  static String cityName(LevelId level) => switch (level) {
    LevelId.hometown => strings.levelHometown.toUpperCase(),
    LevelId.rome => strings.levelRome.toUpperCase(),
  };

  @override
  State<AdventureStats> createState() => _AdventureStatsState();
}

final class _AdventureStatsState extends State<AdventureStats> {
  late final List<LevelId> _cities = <LevelId>[
    for (final level in LevelId.values)
      if (widget.progress.visited(level)) level,
  ];
  late int _index = _cities
      .indexOf(widget.level ?? widget.progress.level)
      .clamp(0, 99);

  /// Whether the secret missions are open in place of the figures.
  bool _secrets = false;

  void _turn(int by) => setState(() => _index += by);

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
        const arrowWidth = 22.0;
        Widget arrow(String label, int by) {
          final to = _index + by;
          if (to < 0 || to >= _cities.length) {
            return SizedBox(width: arrowWidth * unit);
          }
          return MenuButton(
            key: ValueKey<String>(
              'adventure-stats-${by < 0 ? 'prev' : 'next'}',
            ),
            label: label,
            unit: unit,
            compact: true,
            width: arrowWidth,
            onPressed: () => _turn(by),
          );
        }

        // The secret missions only of a city played to its end, Molfetta
        // once Luigi has been reached at the station, and only while some
        // are left to do: with none, there is no page to open.
        final open = <SecretMission>[
          if (stats.completed)
            for (final mission in SecretMission.values)
              if (mission.level == level &&
                  !widget.progress.secretMissions.contains(mission))
                mission,
        ];
        if (_secrets && open.isNotEmpty) {
          return _SecretMissions(
            open: open,
            unit: unit,
            onBack: () => setState(() => _secrets = false),
          );
        }
        final secrets = open.isNotEmpty;
        final buttonWidth = secrets
            ? AdventureStats.buttonWidth
            : (StatsCard.cardWidth - AdventureStats.buttonGap) / 2;
        Widget button(String key, String label, VoidCallback onPressed) =>
            MenuButton(
              key: ValueKey<String>(key),
              label: label,
              unit: unit,
              compact: true,
              width: buttonWidth,
              onPressed: onPressed,
            );
        return SizedBox.expand(
          key: const ValueKey<String>('adventure-stats'),
          child: Center(
            child: DrippingOver(
              title: BloodyTitle(
                AdventureStats.cityName(level),
                key: ValueKey<String>('adventure-stats-${level.name}'),
                fontSize: 20 * unit,
                hangDrips: true,
              ),
              gap: LevelComplete.titleGap * unit,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
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
                        strings.statsReplayMemories,
                        () => widget.onReplayMemories(level),
                      ),
                      if (secrets) ...<Widget>[
                        SizedBox(width: AdventureStats.buttonGap * unit),
                        button(
                          'adventure-stats-secrets',
                          strings.secretMissions,
                          () => setState(() => _secrets = true),
                        ),
                      ],
                      SizedBox(width: AdventureStats.buttonGap * unit),
                      button(
                        'adventure-stats-close',
                        strings.statsExit,
                        widget.onClose,
                      ),
                    ],
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

/// The secret missions, open from the figures in their place: those not
/// done yet, each dared beside a big empty box. A done one leaves the page
/// for the missions of its city.
final class _SecretMissions extends StatelessWidget {
  const _SecretMissions({
    required this.open,
    required this.unit,
    required this.onBack,
  });

  /// The city's secret missions not done yet: never none.
  final List<SecretMission> open;
  final double unit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey<String>('secret-missions'),
      child: Center(
        child: SingleChildScrollView(
          child: DrippingOver(
            title: BloodyTitle(
              strings.secretMissions,
              fontSize: 20 * unit,
              hangDrips: true,
            ),
            gap: LevelComplete.titleGap * unit,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MenuPanel(
                  unit: unit,
                  width: StatsCard.cardWidth,
                  child: Column(
                    children: <Widget>[
                      for (final mission in open)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 2 * unit),
                          child: Row(
                            key: ValueKey<String>(
                              'secret-mission-${mission.name}',
                            ),
                            children: <Widget>[
                              CustomPaint(
                                size: Size.square(14 * unit),
                                painter: MissionBoxPainter(
                                  border: 1.6 * unit,
                                  seed: 50 + mission.index,
                                ),
                              ),
                              SizedBox(width: 7 * unit),
                              Expanded(
                                child: Text(
                                  mission.text,
                                  style: missionTextStyle(8.5 * unit),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 8 * unit),
                MenuButton(
                  key: const ValueKey<String>('secret-missions-back'),
                  label: strings.back,
                  unit: unit,
                  compact: true,
                  onPressed: onBack,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The level's missions under its figures: on the left the done ones in
/// the order the player got through them, then those handed out and left
/// undone with an empty box (those never found are not given away), in a
/// list that shows three and a half rows so the half one says there is
/// more below; on the right how many are done out of all.
/// With a [finale] done, the list runs down to it and crosses it out in
/// front of the player, and the count goes up with it.
final class MissionsCard extends StatefulWidget {
  const MissionsCard({
    required this.stats,
    required this.unit,
    this.finale,
    this.secret,
    super.key,
  });

  final LevelStats stats;
  final double unit;
  final Mission? finale;

  /// Crossed out together with [finale], on a row of its own under it.
  final SecretMission? secret;

  /// One mission's row, at its shortest: a mission too long for one line
  /// goes on to the next, and its row grows with it. And how many of the
  /// one-line rows show at once.
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

  /// The last row crossed out on this screen: the finale's, or the
  /// secret's under it.
  final GlobalKey _lastCelebrated = GlobalKey();

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
    // Down just far enough for its row, and the secret's under it, to be
    // the last ones whole in view: their bottom where the third one-line
    // row ends, whatever the rows above or the row itself take.
    final row = _lastCelebrated.currentContext?.findRenderObject();
    if (row is RenderBox && row.hasSize && _scroll.hasClients) {
      final rowHeight = MissionsCard.rowHeight * widget.unit;
      final view = rowHeight * MissionsCard.visibleRows;
      final bottom = rowHeight * MissionsCard.visibleRows.floor();
      final height = row.size.height;
      final alignment = height >= view
          ? 0.0
          : ((bottom - height) / (view - height)).clamp(0.0, 1.0);
      final target = RenderAbstractViewport.of(
        row,
      ).getOffsetToReveal(row, alignment).offset;
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
    final celebratedSecret = celebrated == null ? null : widget.secret;
    final undone = <Mission>[
      for (final mission in stats.openMissions)
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
          final secrets =
              stats.doneSecrets.length -
              (celebratedSecret != null && !landed ? 1 : 0);
          final swell = celebrated == null
              ? 0.0
              : math.sin(math.pi * ((_finale.value - 0.55) / 0.45).clamp(0, 1));
          return Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: listHeight,
                  // Every row built, however far down: the finale's has to
                  // be measured to be scrolled to.
                  child: SingleChildScrollView(
                    key: const ValueKey<String>('missions-list'),
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final mission in stats.doneMissions)
                          _celebratedLast(
                            last:
                                mission == celebrated &&
                                celebratedSecret == null,
                            child: _row(
                              mission,
                              crossed: mission == celebrated ? strokes : 1,
                              boxScale: mission == celebrated
                                  ? 1 + swell * 0.5
                                  : 1,
                            ),
                          ),
                        for (final secret in stats.doneSecrets)
                          _celebratedLast(
                            last: secret == celebratedSecret,
                            child: _secretRow(
                              secret,
                              crossed: secret == celebratedSecret ? strokes : 1,
                              boxScale: secret == celebratedSecret
                                  ? 1 + swell * 0.5
                                  : 1,
                            ),
                          ),
                        for (final mission in undone) _row(mission, crossed: 0),
                      ],
                    ),
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
                      strings.missions,
                      style: TextStyle(
                        color: menuTextColour,
                        fontFamily: 'monospace',
                        fontSize: 8 * unit,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 3 * unit),
                    // The secrets as a bonus over the count, in blood,
                    // scrawled on at a slant past its top right corner:
                    // laid over it, so the count keeps its room.
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Transform.scale(
                          scale: 1 + swell * 0.35,
                          child: Text(
                            stats.outOf(done, stats.missions.length),
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
                        if (secrets > 0)
                          Positioned(
                            right: -16 * unit,
                            top: 4 * unit,
                            // Tilted down to the right, the plus in line
                            // with the number and close to it.
                            child: Transform.rotate(
                              angle: 0.2,
                              child: BloodyTitle(
                                '+$secrets',
                                key: const ValueKey<String>('secret-stat'),
                                fontSize: 13 * unit,
                                spacing: -0.05,
                              ),
                            ),
                          ),
                      ],
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

  /// [child], found again by [_lastCelebrated] when it is [last].
  Widget _celebratedLast({required bool last, required Widget child}) =>
      last ? KeyedSubtree(key: _lastCelebrated, child: child) : child;

  Widget _row(
    Mission mission, {
    required double crossed,
    double boxScale = 1,
  }) => _line(
    key: 'mission-row-${mission.name}',
    text: mission.text,
    seed: mission.index,
    crossed: crossed,
    boxScale: boxScale,
  );

  /// A secret mission among the level's, said to be one.
  Widget _secretRow(
    SecretMission mission, {
    required double crossed,
    double boxScale = 1,
  }) => _line(
    key: 'secret-row-${mission.name}',
    text: strings.secretMissionRow(mission.short),
    seed: 50 + mission.index,
    crossed: crossed,
    boxScale: boxScale,
    colour: BloodColors.bright,
  );

  Widget _line({
    required String key,
    required String text,
    required int seed,
    required double crossed,
    double boxScale = 1,
    Color? colour,
  }) {
    final unit = widget.unit;
    final box = 7 * unit;
    return ConstrainedBox(
      key: ValueKey<String>(key),
      constraints: BoxConstraints(minHeight: MissionsCard.rowHeight * unit),
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
                seed: seed,
              ),
            ),
          ),
          SizedBox(width: 5 * unit),
          Expanded(
            child: Opacity(
              opacity: crossed > 0 ? 1 : 0.62,
              // A line on its own keeps to the row's height; the gap only
              // shows between wrapped missions.
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 0.5 * unit),
                child: Text(
                  text,
                  style: colour == null
                      ? missionTextStyle(7 * unit)
                      : missionTextStyle(7 * unit).copyWith(color: colour),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
