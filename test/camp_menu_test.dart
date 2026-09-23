import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/camp_menu.dart';
import 'package:stepbound/ui/story_intro.dart';

void main() {
  late int saves;
  late int closes;
  late List<bool> memoryCalls;

  Future<void> pumpMenu(
    WidgetTester tester, {
    Set<EntityKind> known = const <EntityKind>{
      EntityKind.wanderer,
      EntityKind.carabiniere,
    },
    bool luigi = false,
    List<StoryMemory>? memories,
  }) async {
    saves = 0;
    closes = 0;
    memoryCalls = <bool>[];
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CampMenu(
          key: ValueKey<Object>((known, luigi, memories)),
          progress: Progress(
            knownZombies: known,
            memories:
                memories ??
                <StoryMemory>[
                  StoryMemory.newsBroadcast,
                  StoryMemory.outbreakNight,
                  if (luigi) StoryMemory.luigiTrapped,
                ],
          ),
          onSave: () async => saves++,
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

  testWidgets('the camp offers its three actions and a way back', (
    tester,
  ) async {
    await pumpMenu(tester);
    for (final text in <String>[
      'SALVA IL GIOCO',
      'TIPI DI ZOMBI',
      'RIVEDI I RICORDI',
      'TORNA AL GIOCO',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(
      find.text('RICOMINCIA IL LIVELLO'),
      findsNothing,
      reason: 'starting over belongs to the menu the corner button opens',
    );
    await tap(tester, 'camp-close');
    expect(closes, 1);
  });

  testWidgets('the way back sits apart from the choices', (tester) async {
    await pumpMenu(tester);
    double topOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).top;
    double bottomOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).bottom;

    final betweenChoices = topOf('camp-memories') - bottomOf('camp-zombies');
    final beforeTheWayBack = topOf('camp-close') - bottomOf('camp-memories');

    expect(
      beforeTheWayBack,
      greaterThan(betweenChoices * 2),
      reason: 'leaving the fire must not look like one more choice',
    );
  });

  testWidgets('saving stores the game once and says so', (tester) async {
    await pumpMenu(tester);
    await tap(tester, 'camp-save');
    expect(saves, 1);
    expect(find.text('SALVATAGGIO COMPLETATO'), findsOneWidget);
    await tap(tester, 'camp-save');
    expect(saves, 1);
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

  testWidgets('memories are replayed in the order they were lived, not in '
      'the order of the enum', (tester) async {
    // The Duomo met before the hypermarket, and its second half after it.
    const lived = <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
      StoryMemory.priestMet,
      StoryMemory.luigiTrapped,
      StoryMemory.priestErrand,
    ];
    await pumpMenu(tester, memories: lived);
    await tap(tester, 'camp-memories');
    expect(
      tester
          .widget<StoryIntro>(find.byType(StoryIntro))
          .scenes
          .map((scene) => scene.text),
      <String>[
        for (final memory in lived)
          for (final scene in memoryScenes[memory]!) scene.text,
      ],
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
