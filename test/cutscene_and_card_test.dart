import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/game_cutscene.dart';
import 'package:stepbound/ui/location_card.dart';

void main() {
  Future<void> pumpIn(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(768, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  group('the location card', () {
    late int blacks;
    late int finishes;

    Future<void> pumpCard(WidgetTester tester) {
      blacks = 0;
      finishes = 0;
      return pumpIn(
        tester,
        LocationCard(
          name: 'Porto e centro storico',
          image: 'assets/story/scene_harbour.jpg',
          onBlack: () => blacks++,
          onFinished: () => finishes++,
        ),
      );
    }

    testWidgets('goes black, names the place, and lifts on the new map', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text('Porto e centro storico'), findsOneWidget);
      await tester.pump(
        LocationCard.blackIn - const Duration(milliseconds: 50),
      );
      expect(blacks, 0, reason: 'not black yet');
      await tester.pump(const Duration(milliseconds: 100));
      expect(blacks, 1, reason: 'the game can move behind it now');
      await tester.pump(LocationCard.total);
      expect(blacks, 1, reason: 'only once');
      expect(finishes, 1);
    });

    testWidgets('a tap skips the hold, straight to the fade out', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey<String>('location-card')));
      await tester.pump();
      await tester.pump(
        LocationCard.imageOut +
            LocationCard.blackOut +
            const Duration(milliseconds: 50),
      );
      expect(finishes, 1, reason: 'well before the full five seconds');
      expect(blacks, 1);
    });

    testWidgets('a tap during the fade out changes nothing', (tester) async {
      await pumpCard(tester);
      await tester.pump(LocationCard.total - LocationCard.blackOut);
      await tester.tap(find.byKey(const ValueKey<String>('location-card')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(finishes, 0);
      await tester.pump(LocationCard.blackOut);
      expect(finishes, 1);
    });
  });

  group('the in-game cutscene', () {
    const frames = <CutsceneFrame>[
      CutsceneFrame(
        image: 'assets/story/scene_luigi_trapped.jpg',
        speaker: 'Luigi Rovaga',
        text: 'Mario! Sono qui dentro!',
      ),
      CutsceneFrame(
        image: 'assets/story/scene_luigi_rescue.jpg',
        text: 'La saracinesca si alza.',
      ),
    ];

    Future<int Function()> playThrough(
      WidgetTester tester, {
      required bool stayBlack,
    }) async {
      var finishes = 0;
      await pumpIn(
        tester,
        GameCutscene(
          frames: frames,
          stayBlack: stayBlack,
          onFinished: () => finishes++,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('cutscene-to-black')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('cutscene-story')),
        findsOneWidget,
      );
      // Two taps a picture: the picture, then its text.
      for (var i = 0; i < frames.length * 2; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('story-intro')));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      return () => finishes;
    }

    testWidgets('fades to black, plays the pictures and fades back to the '
        'game', (tester) async {
      final finishes = await playThrough(tester, stayBlack: false);
      expect(
        find.byKey(const ValueKey<String>('cutscene-from-black')),
        findsOneWidget,
      );
      expect(finishes(), 0, reason: 'the game is still fading back in');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(finishes(), 1);
    });

    testWidgets('one that ends the level stays black', (tester) async {
      final finishes = await playThrough(tester, stayBlack: true);
      expect(finishes(), 1);
      expect(
        find.byKey(const ValueKey<String>('cutscene-from-black')),
        findsNothing,
      );
    });
  });
}
