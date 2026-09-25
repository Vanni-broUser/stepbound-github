import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
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
      seenScenes(Progress.newGame()).length,
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
      ).length,
      introScenes.length + outbreakScenes.length + 3,
    );
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
      seenScenes(Progress(memories: lived)).map((scene) => scene.text),
      <String>[
        for (final memory in lived)
          for (final scene in memoryScenes[memory]!) scene.text,
      ],
    );
  });
}
