import 'package:stepbound/core/core.dart';

/// What Mario has been asked to do, level by level: listed in the corner
/// of the screen while they are open, crossed out in blood once done, and
/// counted among the level's figures.
enum Mission {
  findSurvivors(LevelId.hometown, 'Trova altri sopravvissuti', fromStart: true),
  freeLuigi(LevelId.hometown, 'Trova un modo per liberare Luigi'),
  reachLuigi(LevelId.hometown, 'Raggiungi Luigi alla stazione'),
  clearGate(LevelId.hometown, 'Spara o allontana gli zombi dal cancello'),
  findIncense(LevelId.hometown, "Trova dell'incenso"),
  findRing(LevelId.hometown, "Trova l'anello episcopale"),
  initiation(LevelId.hometown, 'Partecipa alla cerimonia di iniziazione'),

  /// Handed out once Mario is back in Molfetta with the grappling hook
  /// found in Rome; done once he has used it across all three gaps.
  exploreTerraces(LevelId.hometown, 'Usa il rampino per esplorare i terrazzi'),

  /// Handed out once Chiara has been seen on the phone behind the glass in
  /// the company past the palazzo.
  reachSurvivor(
    LevelId.hometown,
    "Raggiungi Chiara dall'altra parte degli uffici",
  ),
  findSupplies(LevelId.rome, 'Trova delle provviste in città'),
  findValuable(LevelId.rome, 'Cerca qualcosa di prezioso per avanzare');

  const Mission(this.level, this.text, {this.fromStart = false});

  /// The city the mission belongs to.
  final LevelId level;
  final String text;

  /// Open as soon as Mario is in [level], before anyone asks anything.
  final bool fromStart;

  /// Every mission of [level], in the order the story hands them out.
  static List<Mission> of(LevelId level) => <Mission>[
    for (final mission in values)
      if (mission.level == level) mission,
  ];

  /// The mission that ends [level]: it is done on the way out of it, so it
  /// is crossed out on the results screen instead of the corner.
  static Mission? finaleOf(LevelId level) => switch (level) {
    LevelId.hometown => reachLuigi,
    LevelId.rome => null,
  };
}

/// A row of the missions in the corner: open, or just done and waiting
/// to be crossed out before it goes.
typedef BoardMission = ({Mission mission, bool done});

/// The missions open and done, each list in the order it came about: the
/// corner shows the open ones as they were handed out, the results the
/// done ones in the order the player got through them.
final class MissionLog {
  MissionLog({
    Iterable<Mission> open = const <Mission>[],
    Iterable<Mission> done = const <Mission>[],
  }) : _open = List<Mission>.of(open),
       _done = List<Mission>.of(done);

  factory MissionLog.fromJson(Map<String, Object?> json) => MissionLog(
    open: <Mission>[
      for (final name in (json['open']! as List<Object?>).cast<String>())
        Mission.values.byName(name),
    ],
    done: <Mission>[
      for (final name in (json['done']! as List<Object?>).cast<String>())
        Mission.values.byName(name),
    ],
  );

  final List<Mission> _open;
  final List<Mission> _done;

  /// Goes up at every change, for whoever draws the log to catch up.
  int get revision => _revision;
  int _revision = 0;

  List<Mission> get open => List<Mission>.unmodifiable(_open);
  List<Mission> get done => List<Mission>.unmodifiable(_done);

  bool isOpen(Mission mission) => _open.contains(mission);
  bool isDone(Mission mission) => _done.contains(mission);

  /// Hands [mission] out, at the bottom of the list. One already done can
  /// be handed out again (the zombies back at Don Angelo's gate): it is
  /// open once more, and keeps its place among the done ones.
  void give(Mission mission) {
    if (_open.contains(mission)) {
      return;
    }
    _open.add(mission);
    _revision++;
  }

  /// Hands out the missions of [level] that are there from the start,
  /// unless they already have been.
  void arriveIn(LevelId level) {
    for (final mission in Mission.of(level)) {
      if (mission.fromStart && !isOpen(mission) && !isDone(mission)) {
        give(mission);
      }
    }
  }

  /// [mission] is done: it leaves the open ones and, the first time,
  /// joins the done ones after the last.
  void complete(Mission mission) {
    final wasOpen = _open.remove(mission);
    if (_done.contains(mission)) {
      if (wasOpen) {
        _revision++;
      }
      return;
    }
    _done.add(mission);
    _revision++;
  }

  /// Drops every mission of [level], open or done, as if never handed
  /// out: the city starts over.
  void forget(LevelId level) {
    final before = _open.length + _done.length;
    _open.removeWhere((mission) => mission.level == level);
    _done.removeWhere((mission) => mission.level == level);
    if (_open.length + _done.length != before) {
      _revision++;
    }
  }

  /// Takes on the missions [other] has handed out and done that this log
  /// has not, after its own.
  void absorb(MissionLog other) {
    for (final mission in other._done) {
      if (!_done.contains(mission)) {
        _open.remove(mission);
        _done.add(mission);
        _revision++;
      }
    }
    for (final mission in other._open) {
      if (!_done.contains(mission)) {
        give(mission);
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'open': <String>[for (final mission in _open) mission.name],
    'done': <String>[for (final mission in _done) mission.name],
  };
}
