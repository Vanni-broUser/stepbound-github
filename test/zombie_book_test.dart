import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/zombie_book.dart';

void main() {
  late int closes;

  Future<void> pumpBook(
    WidgetTester tester, {
    Set<EntityKind> known = const <EntityKind>{
      EntityKind.wanderer,
      EntityKind.carabiniere,
    },
  }) async {
    closes = 0;
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ZombieBook(
          key: ValueKey<Object>(known),
          progress: Progress(knownZombies: known),
          onClose: () => closes++,
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('zombie types: known ones by name, the rest as ???', (
    tester,
  ) async {
    await pumpBook(tester);
    expect(zombieCards.length, greaterThan(3));
    expect(find.text('VAGANTE'), findsNWidgets(2), reason: 'list and card');
    expect(find.text('CARABINIERE'), findsOneWidget);
    expect(find.text('VELOCE'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('zombie-book-portrait-0')),
      findsOne,
    );

    await tap(tester, 'zombie-book-2');
    expect(find.text('Non hai ancora incontrato questo zombi.'), findsOne);
    expect(
      find.byKey(const ValueKey<String>('zombie-book-portrait-2')),
      findsNothing,
    );

    await tap(tester, 'zombie-book-1');
    expect(find.textContaining('manganello'), findsOneWidget);
  });

  testWidgets('the sprinter is listed once it has been announced', (
    tester,
  ) async {
    await pumpBook(
      tester,
      known: const <EntityKind>{
        EntityKind.wanderer,
        EntityKind.carabiniere,
        EntityKind.sprinter,
      },
    );
    expect(find.text('VELOCE'), findsOneWidget);
  });

  testWidgets('the mutilated is listed, with its page, once it has been met', (
    tester,
  ) async {
    final index = zombieCards.indexWhere(
      (card) => card.kind == EntityKind.mutilated,
    );
    await pumpBook(tester);
    expect(find.text('MUTILATO'), findsNothing);
    await pumpBook(
      tester,
      known: const <EntityKind>{EntityKind.wanderer, EntityKind.mutilated},
    );
    expect(find.text('MUTILATO'), findsOneWidget);
    await tap(tester, 'zombie-book-$index');
    expect(find.text('MUTILATO'), findsNWidgets(2), reason: 'list and card');
    expect(find.textContaining('gambe'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('zombie-book-portrait-$index')),
      findsOne,
    );
  });

  testWidgets('the cultist zombie has its own book page', (tester) async {
    final index = zombieCards.indexWhere(
      (card) => card.kind == EntityKind.cultist,
    );
    await pumpBook(
      tester,
      known: const <EntityKind>{EntityKind.wanderer, EntityKind.cultist},
    );

    await tap(tester, 'zombie-book-$index');

    expect(find.text('CULTISTA'), findsNWidgets(2), reason: 'list and card');
    expect(find.textContaining('tre per abbatterlo'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('zombie-book-portrait-$index')),
      findsOneWidget,
    );
  });

  test('every zombie type of the game has its card, once, with its lore', () {
    for (final MapEntry(key: kind, value: lore) in zombieLore.entries) {
      final cards = zombieCards.where((card) => card.kind == kind);
      expect(cards, hasLength(1), reason: '$kind');
      expect(cards.single.name, lore.name);
      expect(cards.single.portrait, lore.portrait);
      expect(cards.single.description, lore.description);
    }
  });

  test(
    'every portrait the lessons and the book show is in the assets',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final lore in zombieLore.values) {
        await expectLater(
          rootBundle.load(lore.portrait),
          completes,
          reason: '${lore.name}: ${lore.portrait} is missing',
        );
      }
    },
  );

  testWidgets('the book closes', (tester) async {
    await pumpBook(tester);
    await tap(tester, 'zombie-book-close');
    expect(closes, 1);
  });

  test('the memories are the scenes seen so far', () {
    expect(
      seenScenes(Progress.newGame(), LevelId.hometown).length,
      introScenes.length + outbreakScenes.length,
    );
    expect(
      seenScenes(
        Progress(
          memories: const <StoryMemory>[
            StoryMemory.newsBroadcast,
            StoryMemory.outbreakNight,
            StoryMemory.luigiTrapped,
          ],
        ),
        LevelId.hometown,
      ).length,
      introScenes.length + outbreakScenes.length + 3,
    );
  });

  test("each city keeps its own memories: Rome's are not Molfetta's", () {
    final progress = Progress(
      memories: const <StoryMemory>[
        StoryMemory.newsBroadcast,
        StoryMemory.outbreakNight,
        StoryMemory.luigiAtStation,
        StoryMemory.presidentFled,
      ],
    );
    expect(seenScenes(progress, LevelId.rome), romeScenes);
    expect(
      seenScenes(progress, LevelId.hometown),
      isNot(contains(romeScenes.first)),
    );
    expect(
      seenScenes(progress, LevelId.hometown),
      hasLength(
        introScenes.length +
            outbreakScenes.length +
            memoryScenes[StoryMemory.luigiAtStation]!.length,
      ),
    );
    for (final memory in StoryMemory.values) {
      expect(
        memoryScenes,
        contains(memory),
        reason: '$memory has scenes to play again',
      );
    }
  });

  test('Rome names the president as President of the Council', () {
    expect(
      romeScenes.where((scene) => scene.speaker == 'Presidente del consiglio'),
      hasLength(5),
    );
    expect(romeScenes.any((scene) => scene.speaker == 'Presidente'), isFalse);
  });

  test('memories are replayed in the order they were lived, not in the '
      'order of the enum', () {
    // The Duomo met before the hypermarket, and its second half after it.
    const lived = <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
      StoryMemory.priestMet,
      StoryMemory.luigiTrapped,
      StoryMemory.priestErrand,
      StoryMemory.priestWelcomed,
    ];
    expect(
      seenScenes(
        Progress(memories: lived),
        LevelId.hometown,
      ).map((scene) => scene.text),
      <String>[
        for (final memory in lived)
          for (final scene in memoryScenes[memory]!) scene.text,
      ],
    );
  });

  test('the memories of Luigi set free and of Don Angelo keep their music, '
      'the rest play with the story', () {
    Music? musicOf(StoryMemory memory) =>
        memoryScenes[memory]!.map((scene) => scene.music).toSet().single;
    expect(musicOf(StoryMemory.luigiRescued), Music.luigi);
    expect(musicOf(StoryMemory.luigiAtStation), Music.luigi);
    for (final memory in <StoryMemory>[
      StoryMemory.priestMet,
      StoryMemory.priestErrand,
      StoryMemory.priestWelcomed,
      StoryMemory.priestFamily,
      StoryMemory.priestMass,
      StoryMemory.priestMassacre,
    ]) {
      expect(musicOf(memory), Music.sacred, reason: memory.name);
    }
    for (final memory in <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
      StoryMemory.luigiTrapped,
    ]) {
      expect(musicOf(memory), isNull, reason: memory.name);
    }
  });

  testWidgets('the replay tells of every scene as it comes up, so the music '
      'can follow it', (tester) async {
    const scenes = <StoryScene>[
      StoryScene(image: 'assets/story/scenes/news.png', text: 'a'),
      StoryScene(
        image: 'assets/story/scenes/blackout.png',
        text: 'b',
        music: Music.luigi,
      ),
    ];
    final shown = <Music?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StoryIntro(
          scenes: scenes,
          allowBackNavigation: true,
          onFinished: () {},
          onScene: (scene) => shown.add(scene.music),
        ),
      ),
    );
    expect(shown, <Music?>[null]);
    final story = find.byKey(const ValueKey<String>('story-intro'));
    await tester.tap(story);
    await tester.pump();
    await tester.tap(story);
    await tester.pump();
    expect(shown, <Music?>[null, Music.luigi]);

    final bounds = tester.getRect(story);
    await tester.tapAt(Offset(bounds.left + 10, bounds.center.dy));
    await tester.pump();
    expect(shown, <Music?>[null, Music.luigi, null]);
    expect(find.text('a'), findsOneWidget);
  });
}
