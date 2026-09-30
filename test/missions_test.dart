import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/level_complete.dart';

void main() {
  group('the missions log', () {
    test('a new game opens with the survivors to find, handed out once '
        'however often the train comes back; Rome waits for Luigi', () {
      final progress = Progress.newGame();
      expect(progress.missions.open, <Mission>[Mission.findSurvivors]);
      progress.travel(LevelId.rome, rounds: 3);
      expect(
        progress.missions.open,
        <Mission>[Mission.findSurvivors],
        reason: 'the supplies come with the end of his welcome',
      );
      progress
        ..travel(LevelId.hometown, rounds: 3)
        ..travel(LevelId.rome, rounds: 3);
      expect(progress.missions.open, <Mission>[Mission.findSurvivors]);
    });

    test('done ones keep the order they were done in, and one handed out '
        'again counts once', () {
      final log = MissionLog()
        ..give(Mission.clearGate)
        ..give(Mission.freeLuigi)
        ..complete(Mission.freeLuigi)
        ..complete(Mission.clearGate)
        ..give(Mission.findIncense)
        ..give(Mission.clearGate);
      expect(log.open, <Mission>[Mission.findIncense, Mission.clearGate]);
      expect(log.done, <Mission>[Mission.freeLuigi, Mission.clearGate]);
      final revision = log.revision;
      log
        ..complete(Mission.clearGate)
        ..complete(Mission.findIncense);
      expect(log.revision, greaterThan(revision));
      expect(log.open, isEmpty);
      expect(log.done, <Mission>[
        Mission.freeLuigi,
        Mission.clearGate,
        Mission.findIncense,
      ]);
      final unchanged = log.revision;
      log.complete(Mission.findIncense);
      expect(log.revision, unchanged, reason: 'nothing changed');
    });

    test('a save keeps both lists and their order', () {
      final progress = Progress.newGame();
      progress.missions
        ..give(Mission.freeLuigi)
        ..complete(Mission.freeLuigi)
        ..give(Mission.reachLuigi);
      final read = Progress.fromJson(progress.toJson()).missions;
      expect(read.open, <Mission>[Mission.findSurvivors, Mission.reachLuigi]);
      expect(read.done, <Mission>[Mission.freeLuigi]);
    });

    test('every level has its missions, and the texts are as written', () {
      expect(
        Mission.of(LevelId.hometown).map((mission) => mission.text),
        <String>[
          'Trova altri sopravvissuti',
          'Trova un modo per liberare Luigi',
          'Raggiungi Luigi alla stazione',
          'Spara o allontana gli zombi dal cancello',
          "Trova dell'incenso",
          "Trova l'anello episcopale",
          'Partecipa alla cerimonia di iniziazione',
          'Usa il rampino per esplorare i terrazzi',
          "Raggiungi Chiara dall'altra parte degli uffici",
        ],
      );
      expect(Mission.of(LevelId.rome).map((mission) => mission.text), <String>[
        'Trova delle provviste in città',
        'Cerca qualcosa di prezioso per avanzare',
      ]);
      expect(Mission.finaleOf(LevelId.hometown), Mission.reachLuigi);
    });
  });

  group('the missions card', () {
    // The results screen comes at the end of the level: its totals show.
    LevelStats statsOf(Progress progress) => LevelStats.of(
      createGameWorld(),
      progress..remember(StoryMemory.luigiAtStation),
      LevelId.hometown,
    );

    Future<void> pump(
      WidgetTester tester,
      LevelStats stats, {
      Mission? finale,
    }) async {
      tester.view.physicalSize = const Size(768, 432);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LevelComplete(stats: stats, finale: finale, onContinue: () {}),
        ),
      );
      await tester.pump();
    }

    String score(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey<String>('mission-stat')))
        .data!;

    testWidgets('done ones first in the order they were done, then the '
        'rest, and the score out of all of them', (tester) async {
      final progress = Progress.newGame();
      progress.missions
        ..complete(Mission.clearGate)
        ..complete(Mission.freeLuigi)
        ..complete(Mission.findSurvivors);
      await pump(tester, statsOf(progress));
      expect(score(tester), '3 / 9');
      double top(Mission mission) => tester
          .getTopLeft(
            find.byKey(ValueKey<String>('mission-row-${mission.name}')),
          )
          .dy;
      expect(top(Mission.clearGate), lessThan(top(Mission.freeLuigi)));
      expect(top(Mission.freeLuigi), lessThan(top(Mission.findSurvivors)));
      // Past the fourth row, the list has to be scrolled.
      final list = tester.getRect(
        find.byKey(const ValueKey<String>('missions-list')),
      );
      final unit = list.height / (MissionsCard.rowHeight * 3.5);
      expect(unit, closeTo(2, 0.01));
      expect(
        tester.getRect(find.text(Mission.findSurvivors.text)).bottom,
        lessThanOrEqualTo(list.bottom),
      );
      expect(
        find.text(Mission.initiation.text).hitTestable(),
        findsNothing,
        reason: 'the last ones are below the fold',
      );
    });

    testWidgets('missions never handed out stay off the list, but count', (
      tester,
    ) async {
      final progress = Progress.newGame();
      progress.missions
        ..give(Mission.findSurvivors)
        ..give(Mission.freeLuigi)
        ..complete(Mission.findSurvivors);
      await pump(tester, statsOf(progress));
      expect(score(tester), '1 / 9');
      Finder row(Mission mission) =>
          find.byKey(ValueKey<String>('mission-row-${mission.name}'));
      expect(row(Mission.findSurvivors), findsOneWidget);
      expect(row(Mission.freeLuigi), findsOneWidget);
      for (final mission in <Mission>[
        Mission.reachLuigi,
        Mission.clearGate,
        Mission.findIncense,
        Mission.findRing,
        Mission.initiation,
        Mission.exploreTerraces,
      ]) {
        expect(row(mission), findsNothing, reason: mission.name);
      }
    });

    testWidgets('the terraces count from the start, but are listed only '
        'once handed out, not crossed out', (tester) async {
      final progress = Progress.newGame();
      var stats = statsOf(progress);
      expect(stats.missions, contains(Mission.exploreTerraces));
      expect(stats.openMissions, isNot(contains(Mission.exploreTerraces)));
      await pump(tester, stats);
      expect(score(tester), '0 / 9');
      final row = find.byKey(
        ValueKey<String>('mission-row-${Mission.exploreTerraces.name}'),
      );
      expect(row, findsNothing);

      progress.missions.give(Mission.exploreTerraces);
      stats = statsOf(progress);
      expect(stats.openMissions, contains(Mission.exploreTerraces));
      await pump(tester, stats);
      expect(score(tester), '0 / 9');
      await tester.scrollUntilVisible(
        row,
        50,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('missions-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(row, findsOneWidget);
    });

    testWidgets('the gate, cleared twice, is one mission done', (tester) async {
      final progress = Progress.newGame();
      progress.missions
        ..give(Mission.clearGate)
        ..complete(Mission.clearGate)
        ..give(Mission.findIncense)
        ..give(Mission.clearGate)
        ..complete(Mission.clearGate)
        ..complete(Mission.findIncense);
      final stats = statsOf(progress);
      expect(stats.doneMissions, <Mission>[
        Mission.clearGate,
        Mission.findIncense,
      ]);
      await pump(tester, stats);
      expect(score(tester), '2 / 9');
      expect(
        find.byKey(ValueKey<String>('mission-row-${Mission.clearGate.name}')),
        findsOneWidget,
      );
    });

    testWidgets('the finale is crossed out in front of the player, the '
        'score going up with it', (tester) async {
      final progress = Progress.newGame();
      progress.missions
        ..complete(Mission.findSurvivors)
        ..complete(Mission.freeLuigi)
        ..complete(Mission.reachLuigi);
      await pump(tester, statsOf(progress), finale: Mission.reachLuigi);
      expect(score(tester), '2 / 9', reason: 'not crossed out yet');
      // A moment to take the screen in, then down the list and the cross.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(score(tester), '3 / 9');
      expect(
        find.text(Mission.reachLuigi.text).hitTestable(),
        findsOneWidget,
        reason: 'the list ran down to it',
      );
    });
  });
}
