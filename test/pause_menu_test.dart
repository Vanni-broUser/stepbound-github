import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/pause_menu.dart';
import 'package:stepbound/ui/portrait_image.dart';

void main() {
  late int resumes;
  late int restarts;
  late int quits;
  late int closes;
  late Progress progress;
  late List<PlayerOutfit> outfitsWorn;

  Future<void> pumpMenu(
    WidgetTester tester, {
    ResumePoint? resumePoint = ResumePoint.campfire,
    bool cultistFound = true,
    bool duomoCompleted = true,
    bool wardrobe = false,
    Iterable<PlayerOutfit> linkedOutfits = const <PlayerOutfit>[],
  }) async {
    resumes = 0;
    restarts = 0;
    quits = 0;
    closes = 0;
    progress = Progress(
      memories: <StoryMemory>[if (duomoCompleted) StoryMemory.priestMassacre],
      unlockedOutfits: <PlayerOutfit>[
        if (cultistFound) PlayerOutfit.cultist,
        ...linkedOutfits,
      ],
    );
    outfitsWorn = <PlayerOutfit>[];
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          progress: progress,
          key: ValueKey<ResumePoint?>(resumePoint),
          resumePoint: resumePoint,
          wardrobe: wardrobe,
          onResumeFromCamp: () => resumes++,
          onRestartLevel: () => restarts++,
          onMainMenu: () => quits++,
          onClose: () => closes++,
          onWearOutfit: (outfit) {
            if (progress.wearOutfit(outfit)) {
              outfitsWorn.add(outfit);
            }
          },
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('with a campfire behind him, all three ways out', (tester) async {
    await pumpMenu(tester);
    for (final text in <String>[
      'RIPRENDI DAL FALÒ',
      'CAMBIA ABBIGLIAMENTO',
      'RICOMINCIA IL LIVELLO',
      'VAI AL MENÙ PRINCIPALE',
      'TORNA AL GIOCO',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tap(tester, 'pause-close');
    expect(closes, 1);
  });

  testWidgets('saved on the train, it is the train it goes back to', (
    tester,
  ) async {
    await pumpMenu(tester, resumePoint: ResumePoint.train);
    expect(find.text('RIPRENDI DAL TRENO'), findsOneWidget);
    expect(find.text('RIPRENDI DAL FALÒ'), findsNothing);
    await tap(tester, 'pause-resume');
    expect(find.text('SÌ, TORNA AL TRENO'), findsOneWidget);
    expect(find.textContaining('Tornare al treno?'), findsOneWidget);
  });

  testWidgets('without one, there is nothing to resume', (tester) async {
    await pumpMenu(tester, resumePoint: null);
    expect(find.text('RIPRENDI DAL FALÒ'), findsNothing);
    expect(find.text('RICOMINCIA IL LIVELLO'), findsOneWidget);
    expect(find.text('VAI AL MENÙ PRINCIPALE'), findsOneWidget);
  });

  testWidgets('before the first outfit is found, no outfit button', (
    tester,
  ) async {
    await pumpMenu(tester, cultistFound: false, duomoCompleted: false);
    expect(find.text('CAMBIA ABBIGLIAMENTO'), findsNothing);
    expect(find.text('RIPRENDI DAL FALÒ'), findsOneWidget);
  });

  testWidgets('a linked skin does not expose clothes before the Duomo', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      cultistFound: false,
      duomoCompleted: false,
      linkedOutfits: const <PlayerOutfit>[PlayerOutfit.ghost],
    );
    expect(find.text('CAMBIA ABBIGLIAMENTO'), findsNothing);
  });

  testWidgets('the way back to the game sits apart from the choices', (
    tester,
  ) async {
    await pumpMenu(tester);
    double topOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).top;
    double bottomOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key))).bottom;

    final betweenChoices = topOf('pause-quit') - bottomOf('pause-restart');
    final beforeTheWayBack = topOf('pause-close') - bottomOf('pause-quit');

    expect(beforeTheWayBack, greaterThan(betweenChoices * 2));
  });

  testWidgets('the top-right menu changes between unlocked outfits', (
    tester,
  ) async {
    await pumpMenu(tester);
    await tap(tester, 'pause-outfits');

    expect(find.text('BASE'), findsNWidgets(2));
    expect(find.text('OCCULTISTA'), findsOneWidget);
    expect(find.text('GIÀ IN USO'), findsOneWidget);
    final basePortrait = tester.widget<PortraitImage>(
      find.byKey(const ValueKey<String>('pause-outfit-portrait-0')),
    );
    expect(basePortrait.asset, PlayerOutfit.base.portrait);

    await tap(tester, 'pause-outfit-1');
    expect(find.text('INDOSSA'), findsOneWidget);
    final cultistPortrait = tester.widget<PortraitImage>(
      find.byKey(const ValueKey<String>('pause-outfit-portrait-1')),
    );
    expect(cultistPortrait.asset, PlayerOutfit.cultist.portrait);

    await tap(tester, 'pause-outfit-wear');
    expect(outfitsWorn, <PlayerOutfit>[PlayerOutfit.cultist]);
    expect(progress.activeOutfit, PlayerOutfit.cultist);
    expect(find.text('GIÀ IN USO'), findsOneWidget);

    await tap(tester, 'pause-outfit-back');
    expect(find.text('TORNA AL GIOCO'), findsOneWidget);
  });

  testWidgets('from the wardrobe aboard it opens on the outfits, even with '
      'only the base clothes, and going back returns to the game', (
    tester,
  ) async {
    await pumpMenu(tester, wardrobe: true, cultistFound: false);
    expect(
      find.byKey(const ValueKey<String>('pause-outfit-page')),
      findsOneWidget,
    );
    await tap(tester, 'pause-outfit-back');
    expect(closes, 1);
    expect(find.text('TORNA AL GIOCO'), findsNothing);
  });

  testWidgets('the train wardrobe can wear a linked skin before the Duomo', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      wardrobe: true,
      cultistFound: false,
      linkedOutfits: const <PlayerOutfit>[PlayerOutfit.ghost],
    );
    final ghostSlot = PlayerOutfit.values.indexOf(PlayerOutfit.ghost);
    await tap(tester, 'pause-outfit-$ghostSlot');
    expect(find.text('FANTASMA'), findsWidgets);
    await tap(tester, 'pause-outfit-wear');
    expect(outfitsWorn, <PlayerOutfit>[PlayerOutfit.ghost]);
  });

  testWidgets('the outfits still to come are "???" and cannot be worn', (
    tester,
  ) async {
    await pumpMenu(tester);
    await tap(tester, 'pause-outfits');
    // Many places already, only two of them filled.
    expect(outfitSlots, greaterThan(PlayerOutfit.values.length));
    await tap(tester, 'pause-outfit-2');
    expect(find.text('NON DISPONIBILE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('pause-outfit-portrait-2')),
      findsNothing,
      reason: 'only a black shape',
    );
    await tap(tester, 'pause-outfit-wear');
    expect(outfitsWorn, isEmpty);
    expect(find.text('???'), findsWidgets);
  });

  testWidgets('the Halloween catalogue exposes every seasonal skin', (
    tester,
  ) async {
    progress = Progress(
      memories: const <StoryMemory>[StoryMemory.priestMassacre],
      unlockedOutfits: const <PlayerOutfit>[
        PlayerOutfit.cultist,
        ...halloweenOutfits,
      ],
    );
    outfitsWorn = <PlayerOutfit>[];
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          progress: progress,
          resumePoint: ResumePoint.campfire,
          onResumeFromCamp: () {},
          onRestartLevel: () {},
          onMainMenu: () {},
          onClose: () {},
          onWearOutfit: (outfit) {
            outfitsWorn.add(outfit);
            progress.wearOutfit(outfit);
          },
        ),
      ),
    );

    await tap(tester, 'pause-outfits');
    for (final outfit in halloweenOutfits) {
      final slot = PlayerOutfit.values.indexOf(outfit);
      await tap(tester, 'pause-outfit-$slot');
      expect(find.text(outfit.label.toUpperCase()), findsWidgets);
      final portrait = tester.widget<PortraitImage>(
        find.byKey(ValueKey<String>('pause-outfit-portrait-$slot')),
      );
      expect(portrait.asset, outfit.portrait);
    }

    final zombieSlot = PlayerOutfit.values.indexOf(PlayerOutfit.zombie);
    await tap(tester, 'pause-outfit-$zombieSlot');
    await tap(tester, 'pause-outfit-wear');
    expect(outfitsWorn, <PlayerOutfit>[PlayerOutfit.zombie]);
  });

  for (final (choice, name, count) in <(String, String, int Function())>[
    ('pause-resume', 'going back to the fire', () => resumes),
    ('pause-restart', 'starting the level over', () => restarts),
    ('pause-quit', 'leaving for the main menu', () => quits),
  ]) {
    testWidgets('$name asks first, and No comes back', (tester) async {
      await pumpMenu(tester);
      await tap(tester, choice);
      expect(count(), 0, reason: 'nothing happens until it is confirmed');
      expect(find.byKey(const ValueKey<String>('pause-cost')), findsOneWidget);

      await tap(tester, 'pause-back');
      expect(count(), 0);
      expect(find.text('TORNA AL GIOCO'), findsOneWidget);

      await tap(tester, choice);
      await tap(tester, 'pause-confirm');
      expect(count(), 1);
    });
  }

  testWidgets('every confirmation says what it costs', (tester) async {
    Future<String> costOf(WidgetTester tester, String choice) async {
      await tap(tester, choice);
      return tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('pause-cost')),
              matching: find.byType(Text),
            ),
          )
          .data!;
    }

    await pumpMenu(tester);
    expect(await costOf(tester, 'pause-resume'), contains('va perso'));
    await tap(tester, 'pause-back');
    final restart = await costOf(tester, 'pause-restart');
    expect(restart, contains('si azzerano'));
    expect(
      restart,
      contains('ore di gioco'),
      reason: 'the hours are the one thing it keeps',
    );
    await tap(tester, 'pause-back');
    expect(await costOf(tester, 'pause-quit'), contains('ultimo falò'));

    // Never saved: leaving costs the whole game, and it says so.
    await pumpMenu(tester, resumePoint: null);
    expect(await costOf(tester, 'pause-quit'), contains('mai stata salvata'));
  });
}
