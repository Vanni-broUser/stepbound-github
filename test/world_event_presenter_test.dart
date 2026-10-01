import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/haptics/game_haptics.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/world_event_presenter.dart';
import 'package:stepbound/report/breadcrumbs.dart';

import 'fake_telemetry.dart';

import 'test_world.dart';

/// A stage that writes down what it is asked, and runs what is put off
/// for later only when told to.
final class _Stage implements EventStage {
  final List<String> log = <String>[];
  final List<(double, void Function())> pending = <(double, void Function())>[];
  String place = 'Via Roma';

  @override
  String get playerId => 'player';

  @override
  String get placeName => place;

  @override
  void play(String entityId, CharacterCue cue) =>
      log.add('$entityId:${cue.name}');

  @override
  void later(double seconds, void Function() then) =>
      pending.add((seconds, then));

  @override
  void launchMolotov({
    required GridPoint origin,
    required GridPoint target,
    required void Function() onLanded,
  }) {
    log.add('molotov:$origin>$target');
    onLanded();
  }

  @override
  void launchRocket({
    required GridPoint origin,
    required GridPoint impact,
    required Direction direction,
    required void Function() onImpact,
  }) {
    log.add('rocket:$origin>$impact');
    onImpact();
  }

  @override
  void restAt(GridPoint campfire) => log.add('rest:$campfire');

  @override
  void goThrough({required GridPoint from, required GridPoint to}) =>
      log.add('through:$from>$to');

  @override
  void grapple({
    required GridPoint from,
    required GridPoint anchor,
    required GridPoint to,
  }) => log.add('grapple:$from>$anchor>$to');

  @override
  void groundCaughtFire(GridPoint at) => log.add('fire:$at');

  @override
  void playerDied() => log.add('player:died');

  /// Runs everything put off, in order.
  void runPending() {
    for (final (_, then) in pending) {
      then();
    }
    pending.clear();
  }
}

void main() {
  late _Stage stage;
  late SilentAudio audio;
  late List<HapticCue> haptics;
  late List<WorldEvent> storyEvents;
  late Breadcrumbs trail;
  late Progress progress;
  late WorldEventPresenter presenter;

  setUp(() {
    stage = _Stage();
    audio = SilentAudio();
    haptics = <HapticCue>[];
    storyEvents = <WorldEvent>[];
    trail = Breadcrumbs();
    progress = Progress.newGame();
    presenter = WorldEventPresenter(
      stage: stage,
      audio: audio,
      soundscape: Soundscape(world: corridorWorld(EntityKind.wanderer)),
      haptics: GameplayHaptics(sink: haptics.add),
      progress: progress,
      onStoryEvents: storyEvents.addAll,
      trail: trail,
    );
  });

  const damaged = DamagedEvent(
    entityId: 'zombie',
    amount: 1,
    sourceEntityId: 'player',
  );

  test('a turn is presented once, and turn zero never', () {
    presenter.present(0, const <WorldEvent>[damaged]);
    expect(stage.log, isEmpty, reason: 'turn 0 is the one before any');
    presenter
      ..present(1, const <WorldEvent>[damaged])
      ..present(1, const <WorldEvent>[damaged]);
    expect(stage.log, <String>['zombie:hit']);
    expect(presenter.presentedTurn, 1);
  });

  test('the story, the haptics and the sounds all hear the turn', () {
    const bitten = DamagedEvent(
      entityId: 'player',
      amount: 1,
      sourceEntityId: 'zombie',
    );
    presenter.present(1, const <WorldEvent>[bitten]);
    expect(storyEvents, const <WorldEvent>[bitten]);
    expect(haptics, <HapticCue>[HapticCue.playerHurt]);
    expect(stage.log, <String>['zombie:bite']);
  });

  test('the trail names the place once and skips the steps', () {
    presenter
      ..present(1, const <WorldEvent>[
        MovedEvent(
          entityId: 'player',
          from: GridPoint(1, 1),
          to: GridPoint(2, 1),
        ),
        WaitedEvent('zombie'),
        damaged,
      ])
      ..present(2, const <WorldEvent>[damaged]);
    final texts = trail.entries.map((entry) => entry.text).toList();
    expect(texts.first, 'posto: Via Roma (turno 1)');
    expect(texts.where((text) => text.startsWith('posto')), hasLength(1));
    expect(texts.where((text) => text.startsWith('evento')), hasLength(2));
    expect(texts.any((text) => text.contains('Mario')), isFalse);
    stage.place = 'Porto';
    presenter.present(3, const <WorldEvent>[]);
    expect(trail.entries.last.text, 'posto: Porto (turno 3)');
  });

  test('Mario’s steps are counted, nobody else’s', () {
    presenter.present(1, const <WorldEvent>[
      MovedEvent(
        entityId: 'player',
        from: GridPoint(1, 1),
        to: GridPoint(2, 1),
      ),
      MovedEvent(
        entityId: 'zombie',
        from: GridPoint(5, 1),
        to: GridPoint(4, 1),
      ),
    ]);
    expect(progress.steps[progress.level], 1);
  });

  test('a swing with the grappling hook: Mario throws it as he throws a '
      'molotov, and it catches on the edge just behind where it lands him; '
      'no door, no fade', () {
    presenter.present(1, const <WorldEvent>[
      TeleportedEvent(
        entityId: 'player',
        from: GridPoint(16, 19),
        to: GridPoint(25, 19),
        grappled: true,
      ),
    ]);
    expect(stage.log, <String>[
      'player:throwGrapple',
      'grapple:(16, 19)>(24, 19)>(25, 19)',
    ]);
  });

  test('each event plays its animation', () {
    presenter.present(1, const <WorldEvent>[
      ShotEvent(
        entityId: 'player',
        origin: GridPoint(1, 1),
        impact: GridPoint(3, 1),
        direction: Direction.east,
      ),
      AlertedEvent(entityId: 'zombie', at: GridPoint(5, 1)),
      DiedEvent('zombie'),
      CampfireUsedEvent(at: GridPoint(2, 2)),
      TeleportedEvent(
        entityId: 'player',
        from: GridPoint(1, 1),
        to: GridPoint(9, 9),
      ),
      FireStartedEvent(at: GridPoint(4, 1), entityId: 'zombie'),
    ]);
    expect(stage.log, <String>[
      'player:fire',
      'zombie:alert',
      'zombie:death',
      'rest:(2, 2)',
      'through:(1, 1)>(9, 9)',
      'fire:(4, 1)',
    ]);
    expect(stage.pending, isEmpty);
  });

  test('a shot by someone else is nothing of Mario’s', () {
    presenter.present(1, const <WorldEvent>[
      ShotEvent(
        entityId: 'zombie',
        origin: GridPoint(1, 1),
        impact: GridPoint(3, 1),
        direction: Direction.east,
      ),
    ]);
    expect(stage.log, isEmpty);
  });

  test('Mario’s death takes the controls away', () {
    presenter.present(1, const <WorldEvent>[DiedEvent('player')]);
    expect(stage.log, <String>['player:died']);
  });

  test('a molotov flies from Mario’s hand and is heard as it breaks', () {
    presenter.present(1, const <WorldEvent>[
      MolotovThrownEvent(
        entityId: 'player',
        origin: GridPoint(1, 1),
        target: GridPoint(4, 1),
      ),
    ]);
    expect(stage.log, <String>['player:throwWeapon']);
    expect(stage.pending.map((job) => job.$1), <double>[
      CharacterComponent.throwReleaseDelay,
    ]);
    expect(audio.played, isNot(contains(Sfx.molotov)));
    stage.runPending();
    expect(stage.log, <String>['player:throwWeapon', 'molotov:(1, 1)>(4, 1)']);
    expect(audio.played, contains(Sfx.molotov));
  });

  test('a rocket flies from Mario’s shoulder down its line, and is heard '
      'going off and bursting at the end of it', () {
    presenter.present(1, const <WorldEvent>[
      RocketFiredEvent(
        entityId: 'player',
        origin: GridPoint(1, 1),
        impact: GridPoint(6, 1),
        direction: Direction.east,
        hitEntityIds: <String>['zombie'],
      ),
    ]);
    expect(stage.log, <String>['player:fireRocket', 'rocket:(1, 1)>(6, 1)']);
    expect(audio.played, contains(Sfx.rocket));
    expect(audio.played, contains(Sfx.explosion));
    expect(haptics, contains(HapticCue.hitLanded));
    expect(stage.pending, isEmpty);
  });

  test('the burst’s hits and deaths show as its turn is played', () {
    presenter.present(1, const <WorldEvent>[damaged, DiedEvent('zombie')]);
    expect(stage.log, <String>['zombie:hit', 'zombie:death']);
    expect(stage.pending, isEmpty);
  });

  group('telemetry', () {
    test('counts places reached, zombies killed by kind, and who killed '
        'Mario', () async {
      final server = FakeServer();
      final telemetry = await startedTelemetry(server: server);
      final kinds = <String, EntityKind>{
        'zombie': EntityKind.wanderer,
        'brute': EntityKind.brute,
      };
      final counted = WorldEventPresenter(
        stage: stage,
        audio: audio,
        soundscape: Soundscape(world: corridorWorld(EntityKind.wanderer)),
        haptics: GameplayHaptics(sink: haptics.add),
        progress: progress,
        onStoryEvents: storyEvents.addAll,
        trail: trail,
        telemetry: telemetry,
        kindOf: (id) => kinds[id],
      )..present(1, const <WorldEvent>[damaged, DiedEvent('zombie')]);
      stage.place = 'Porto';
      counted
        ..present(2, const <WorldEvent>[DiedEvent('ghost')])
        ..present(3, const <WorldEvent>[
          DamagedEvent(entityId: 'player', amount: 1, sourceEntityId: 'zombie'),
          DamagedEvent(entityId: 'player', amount: 2, sourceEntityId: 'brute'),
          DiedEvent('player'),
        ])
        ..present(4, const <WorldEvent>[DiedEvent('player')]);
      await telemetry.flush(force: true);
      List<Object?> data(String type) => <Object?>[
        for (final event in server.events(type)) event['data'],
      ];
      expect(data('place_entered'), <Object?>[
        <String, Object?>{'level': 'hometown', 'place': 'Via Roma'},
        <String, Object?>{'level': 'hometown', 'place': 'Porto'},
      ]);
      expect(data('zombie_killed'), <Object?>[
        <String, Object?>{
          'level': 'hometown',
          'place': 'Via Roma',
          'kind': 'wanderer',
        },
        <String, Object?>{
          'level': 'hometown',
          'place': 'Porto',
          'kind': 'unknown',
        },
      ]);
      expect(data('player_died'), <Object?>[
        <String, Object?>{
          'level': 'hometown',
          'place': 'Porto',
          'killer': 'brute',
        },
        <String, Object?>{
          'level': 'hometown',
          'place': 'Porto',
          'killer': 'unknown',
        },
      ]);
      telemetry.dispose();
    });

    test('nothing is counted while telemetry is off', () {
      presenter.present(1, const <WorldEvent>[DiedEvent('zombie')]);
      expect(stage.log, contains('zombie:death'));
    });
  });
}
