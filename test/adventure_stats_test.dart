import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/level_complete.dart';

void main() {
  late int closes;
  late int replays;

  Future<void> pumpStats(WidgetTester tester, Progress progress) async {
    closes = 0;
    replays = 0;
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureStats(
          world: createGameWorld(),
          progress: progress,
          onClose: () => closes++,
          onReplayMemories: () => replays++,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pump();
  }

  Finder city(LevelId level) =>
      find.byKey(ValueKey<String>('adventure-stats-${level.name}'));

  testWidgets('before Rome only the hometown is there, with no arrows, '
      'even after the train has taken Mario back to it from the map', (
    tester,
  ) async {
    final progress = Progress()..steps[LevelId.hometown] = 42;
    await pumpStats(tester, progress);
    expect(city(LevelId.hometown), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('adventure-stats-next')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('adventure-stats-prev')),
      findsNothing,
    );

    progress.travel(LevelId.hometown, rounds: 3);
    await pumpStats(tester, progress);
    expect(city(LevelId.hometown), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('adventure-stats-next')),
      findsNothing,
    );
    await tap(tester, 'adventure-stats-close');
    expect(closes, 1);
  });

  testWidgets('once in Rome, the arrows go from one city to the other, '
      'each with its own figures', (tester) async {
    final progress = Progress()
      ..steps[LevelId.hometown] = 42
      ..steps[LevelId.rome] = 7
      ..travel(LevelId.rome, rounds: 3);
    await pumpStats(tester, progress);
    expect(city(LevelId.rome), findsOneWidget, reason: 'where the train is');
    expect(find.text('7'), findsOneWidget);
    await tap(tester, 'adventure-stats-next');
    expect(city(LevelId.hometown), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    await tap(tester, 'adventure-stats-prev');
    expect(city(LevelId.rome), findsOneWidget);
  });

  testWidgets('back in Molfetta after Rome, it opens on Molfetta, with the '
      'arrows to Rome', (tester) async {
    final progress = Progress()
      ..travel(LevelId.rome, rounds: 3)
      ..travel(LevelId.hometown, rounds: 2);
    await pumpStats(tester, progress);
    expect(city(LevelId.hometown), findsOneWidget);
    await tap(tester, 'adventure-stats-next');
    expect(city(LevelId.rome), findsOneWidget);
  });

  testWidgets('beside the way out, the memories to live again and, once '
      'the city is played to its end, the secret missions, which open in '
      'place of the figures', (tester) async {
    await pumpStats(tester, Progress());
    await tap(tester, 'adventure-stats-memories');
    expect(replays, 1);
    expect(
      find.byKey(const ValueKey<String>('adventure-stats-secrets')),
      findsNothing,
      reason: 'Molfetta is not over yet',
    );

    await pumpStats(
      tester,
      Progress(memories: const <StoryMemory>[StoryMemory.luigiAtStation]),
    );
    await tap(tester, 'adventure-stats-secrets');
    expect(find.byKey(const ValueKey<String>('secret-missions')), findsOne);
    expect(city(LevelId.hometown), findsNothing);

    await tap(tester, 'secret-missions-back');
    expect(city(LevelId.hometown), findsOneWidget);
    expect(closes, 0);
  });

  testWidgets('while a city is being played its totals are not given away', (
    tester,
  ) async {
    await pumpStats(tester, Progress());
    expect(find.textContaining('/ ???'), findsWidgets);

    await pumpStats(
      tester,
      Progress(memories: const <StoryMemory>[StoryMemory.luigiAtStation]),
    );
    expect(find.textContaining('/ ???'), findsNothing);
  });

  testWidgets('a secret mission is dared on its page until done; then it '
      'is listed with its city missions and counted apart', (tester) async {
    final progress = Progress(
      memories: const <StoryMemory>[StoryMemory.luigiAtStation],
    );
    await pumpStats(tester, progress);
    await tap(tester, 'adventure-stats-secrets');
    expect(
      find.byKey(const ValueKey<String>('secret-mission-unarmedToLuigi')),
      findsOneWidget,
    );
    expect(find.text(SecretMission.unarmedToLuigi.text), findsOneWidget);
    await tap(tester, 'secret-missions-back');
    expect(find.byKey(const ValueKey<String>('secret-stat')), findsNothing);

    progress.secretMissions.add(SecretMission.unarmedToLuigi);
    await pumpStats(tester, progress);
    expect(find.byKey(const ValueKey<String>('secret-stat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('secret-row-unarmedToLuigi')),
      findsOneWidget,
    );
    await tap(tester, 'adventure-stats-secrets');
    expect(find.text("Nessun'altra missione segreta per ora"), findsOneWidget);
  });
}
