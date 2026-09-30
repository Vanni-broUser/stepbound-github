import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/main_menu.dart';
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
    bool wardrobe = false,
    Iterable<PlayerOutfit> linkedOutfits = const <PlayerOutfit>[],
    Iterable<PlayerOutfit> giftsBeforeStart = const <PlayerOutfit>[],
  }) async {
    resumes = 0;
    restarts = 0;
    quits = 0;
    closes = 0;
    progress = Progress(
      unlockedOutfits: <PlayerOutfit>[
        ...giftsBeforeStart,
        PlayerOutfit.base,
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

  testWidgets('the clothes are never changed from the menu, only at the '
      'wardrobe aboard, whatever Mario has', (tester) async {
    await pumpMenu(
      tester,
      linkedOutfits: const <PlayerOutfit>[PlayerOutfit.ghost],
    );
    expect(find.text('CAMBIA ABBIGLIAMENTO'), findsNothing);
    expect(find.byKey(const ValueKey<String>('pause-outfits')), findsNothing);
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

  testWidgets('the first time aboard, without the robe: a gift had before '
      'the game began, then the base clothes, and nothing else', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      wardrobe: true,
      cultistFound: false,
      giftsBeforeStart: const <PlayerOutfit>[PlayerOutfit.ghost],
    );
    String label(int index) => tester
        .widget<MenuButton>(find.byKey(ValueKey<String>('pause-outfit-$index')))
        .label;
    expect(
      <String>[label(0), label(1), label(2)],
      <String>['FANTASMA', 'BASE', '???'],
    );
    expect(
      find.byKey(const ValueKey<String>('pause-outfit-portrait-1')),
      findsOneWidget,
      reason: 'open on the base clothes Mario is wearing',
    );
    expect(find.text('OCCULTISTA'), findsNothing);
  });

  testWidgets('the wardrobe aboard changes between unlocked outfits', (
    tester,
  ) async {
    await pumpMenu(tester, wardrobe: true);

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
    expect(closes, 1, reason: 'back to the game');
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
    // Right after the base clothes, the first one Mario had.
    const ghostSlot = 1;
    await tap(tester, 'pause-outfit-$ghostSlot');
    expect(find.text('FANTASMA'), findsWidgets);
    await tap(tester, 'pause-outfit-wear');
    expect(outfitsWorn, <PlayerOutfit>[PlayerOutfit.ghost]);
  });

  testWidgets('the outfits still to come are "???" and cannot be worn', (
    tester,
  ) async {
    await pumpMenu(tester, wardrobe: true);
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

  testWidgets('the outfits come in the order they became his, and every '
      'place still empty looks the same, outfits of the game or not', (
    tester,
  ) async {
    progress = Progress(
      unlockedOutfits: const <PlayerOutfit>[
        PlayerOutfit.jackOLantern,
        PlayerOutfit.base,
        PlayerOutfit.cultist,
        PlayerOutfit.ghost,
      ],
    );
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          progress: progress,
          wardrobe: true,
          resumePoint: ResumePoint.campfire,
          onResumeFromCamp: () {},
          onRestartLevel: () {},
          onMainMenu: () {},
          onClose: () {},
          onWearOutfit: (_) {},
        ),
      ),
    );
    String label(int index) => tester
        .widget<MenuButton>(find.byKey(ValueKey<String>('pause-outfit-$index')))
        .label;
    expect(
      find.byKey(const ValueKey<String>('pause-outfit-portrait-1')),
      findsOneWidget,
      reason: 'it opens on the base clothes Mario is wearing, not the gift',
    );
    expect(
      <String>[label(0), label(1), label(2), label(3)],
      <String>[
        PlayerOutfit.jackOLantern.label.toUpperCase(),
        'BASE',
        'OCCULTISTA',
        PlayerOutfit.ghost.label.toUpperCase(),
      ],
    );

    // Whatever is behind a "???", the vampire and the Roma shirt of the game
    // or a place for outfits still to come, it is the base clothes' shape.
    for (var index = 4; index < outfitSlots; index++) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey<String>('pause-outfit-$index')),
        20,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, 'pause-outfit-$index');
      expect(label(index), '???');
      expect(
        tester.widget<PortraitImage>(find.byType(PortraitImage)).asset,
        PlayerOutfit.base.portrait,
      );
      expect(find.text('NON DISPONIBILE'), findsOneWidget);
    }
  });

  testWidgets('the Halloween catalogue exposes every seasonal skin', (
    tester,
  ) async {
    progress = Progress(
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
          wardrobe: true,
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
    final owned = progress.unlockedOutfits.toList();
    for (final outfit in halloweenOutfits) {
      final slot = owned.indexOf(outfit);
      await tap(tester, 'pause-outfit-$slot');
      expect(find.text(outfit.label.toUpperCase()), findsWidgets);
      final portrait = tester.widget<PortraitImage>(
        find.byKey(ValueKey<String>('pause-outfit-portrait-$slot')),
      );
      expect(portrait.asset, outfit.portrait);
    }

    final zombieSlot = owned.indexOf(PlayerOutfit.zombie);
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
    expect(restart, contains('si azzera'));
    expect(restart, contains('altre città'));
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

  testWidgets('with a way to share, a report can be asked for from here', (
    tester,
  ) async {
    var shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          progress: Progress(),
          resumePoint: null,
          onResumeFromCamp: () {},
          onRestartLevel: () {},
          onMainMenu: () {},
          onClose: () {},
          onWearOutfit: (_) {},
          onShareReport: () => shared++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('pause-share')));
    await tester.pump();
    expect(shared, 1);
    expect(find.text(PauseMenu.shareLabel), findsOneWidget);
  });

  testWidgets('without one, the report is not offered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PauseMenu(
          progress: Progress(),
          resumePoint: null,
          onResumeFromCamp: () {},
          onRestartLevel: () {},
          onMainMenu: () {},
          onClose: () {},
          onWearOutfit: (_) {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('pause-share')), findsNothing);
  });
}
