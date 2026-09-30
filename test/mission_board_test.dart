import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/mission_board.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/ui/blood_decor.dart';

/// The game a scenario's save loads into, not started: the corner only
/// reads its progress and missions.
StepboundGame _gameOf(TestScenario scenario) {
  final save = scenario.save(1);
  return StepboundGame(
    world: restoreGameWorld(save.world),
    storyState: save.story,
    progress: Progress.fromJson(save.progress),
    unlocked: <HudElement>{
      for (final name in save.hud) HudElement.values.byName(name),
    },
  );
}

Future<void> _pumpCorner(WidgetTester tester, StepboundGame game) =>
    tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: MissionBoard(game: game),
        ),
      ),
    );

String _city(WidgetTester tester) => tester
    .widget<BloodyTitle>(
      find.byKey(const ValueKey<String>('mission-board-city')),
    )
    .text;

void main() {
  testWidgets('aboard the train with the city over, its name is there '
      'alone', (tester) async {
    final game = _gameOf(
      testScenarios.singleWhere(
        (scenario) => scenario.name == 'Treno, dopo la fine del livello',
      ),
    );
    expect(game.missions.value, isEmpty);

    await _pumpCorner(tester, game);
    expect(_city(tester), 'CITTÀ NATALE');
    expect(find.byKey(const ValueKey<String>('mission-board')), findsOneWidget);
  });

  testWidgets('aboard the train at Termini, the city is Rome, over its '
      'missions', (tester) async {
    final game = _gameOf(vanniDeployScenario);

    await _pumpCorner(tester, game);
    expect(_city(tester), 'ROMA');
    expect(
      find.byKey(
        ValueKey<String>('mission-text-${Mission.discoverColosseum.name}'),
      ),
      findsOneWidget,
    );
  });
}
