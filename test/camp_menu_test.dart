import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/camp_menu.dart';
import 'package:stepbound/ui/story_intro.dart';

void main() {
  late int saves;
  late int restarts;
  late int closes;
  late List<bool> memoryCalls;

  Future<void> pumpMenu(
    WidgetTester tester, {
    Set<EntityKind> known = const <EntityKind>{
      EntityKind.wanderer,
      EntityKind.carabiniere,
    },
    bool luigi = false,
  }) async {
    saves = 0;
    restarts = 0;
    closes = 0;
    memoryCalls = <bool>[];
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CampMenu(
          key: ValueKey<Object>((known, luigi)),
          progress: Progress(
            knownZombies: known,
            memories: <StoryMemory>[
              StoryMemory.newsBroadcast,
              StoryMemory.outbreakNight,
              if (luigi) StoryMemory.luigiTrapped,
            ],
          ),
          onSave: () async => saves++,
          onRestartLevel: () => restarts++,
          onClose: () => closes++,
          onMemories: memoryCalls.add,
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('the camp offers its four actions and a way back', (
    tester,
  ) async {
    await pumpMenu(tester);
    for (final text in <String>[
      'SALVA IL GIOCO',
      'RICOMINCIA IL LIVELLO',
      'TIPI DI ZOMBI',
      'RIVEDI I RICORDI',
      'TORNA AL GIOCO',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tap(tester, 'camp-close');
    expect(closes, 1);
  });

  testWidgets('saving stores the game once and says so', (tester) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-save');
    expect(saves, 1);
    expect(find.text('SALVATAGGIO COMPLETATO'), findsOneWidget);
    await tap(tester, 'camp-save');
    expect(saves, 1);
  });

  testWidgets('starting the level over asks first', (tester) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-restart');
    expect(restarts, 0);
    await tap(tester, 'camp-back');
    expect(find.text('SALVA IL GIOCO'), findsOneWidget);
    await tap(tester, 'camp-restart');
    await tap(tester, 'camp-restart-confirm');
    expect(restarts, 1);
  });

  testWidgets('zombie types: known ones by name, the rest as ???', (
    tester,
  ) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-zombies');
    expect(zombieCards.length, greaterThan(3));
    expect(find.text('VAGANTE'), findsNWidgets(2), reason: 'list and card');
    expect(find.text('CARABINIERE'), findsOneWidget);
    expect(find.text('VELOCE'), findsNothing);
    expect(find.byKey(const ValueKey<String>('camp-portrait-0')), findsOne);

    await tap(tester, 'camp-zombie-2');
    expect(find.text('Non hai ancora incontrato questo zombi.'), findsOne);
    expect(find.byKey(const ValueKey<String>('camp-portrait-2')), findsNothing);

    await tap(tester, 'camp-zombie-1');
    expect(find.textContaining('manganello'), findsOneWidget);
  });

  testWidgets('the sprinter is listed once it has been announced', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      known: const <EntityKind>{
        EntityKind.wanderer,
        EntityKind.carabiniere,
        EntityKind.sprinter,
      },
    );
    await tap(tester, 'camp-zombies');
    expect(find.text('VELOCE'), findsOneWidget);
  });

  testWidgets('memories play the story scenes seen so far straight away, '
      'and can be left at any moment', (tester) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-memories');
    final story = tester.widget<StoryIntro>(find.byType(StoryIntro));
    expect(
      story.scenes.length,
      introScenes.length + outbreakScenes.length,
      reason: "Luigi's scene not played yet",
    );
    expect(find.byKey(const ValueKey<String>('story-image-0')), findsOne);
    expect(memoryCalls, <bool>[true], reason: "the story's sound starts");
    await tap(tester, 'story-exit');
    expect(memoryCalls, <bool>[true, false], reason: "the game's comes back");
    expect(find.byType(StoryIntro), findsNothing);
    expect(find.text('RIVEDI I RICORDI'), findsOneWidget);

    await pumpMenu(tester, luigi: true);
    await tap(tester, 'camp-memories');
    expect(
      tester.widget<StoryIntro>(find.byType(StoryIntro)).scenes.length,
      introScenes.length + outbreakScenes.length + 3,
    );
  });

  testWidgets('after the last memory the camp menu is back', (tester) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-memories');
    final scenes = introScenes.length + outbreakScenes.length;
    for (var i = 0; i < scenes * 2; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
      await tester.pump();
    }
    expect(find.byType(StoryIntro), findsNothing);
    expect(find.text('SALVA IL GIOCO'), findsOneWidget);
  });
}
