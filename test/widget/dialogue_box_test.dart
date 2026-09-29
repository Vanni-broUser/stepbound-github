import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  // In `runAsync` like every test that loads a game: the pictures are
  // decoded for real, and the ones left half-decoded in fake time would
  // stay in the cache and hold up every later test.
  testWidgets('the controls disappear while a text box is on screen', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Dietro la caserma',
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact', 'ammo', 'shoot'],
        ),
      );
      await tester.pumpWidget(StepboundApp(saves: saves));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      // Mario has the game (the loop that says so does not run here).
      game.freeToMove.value = true;
      await tester.pump();
      const controls = <String>[
        'touch-move',
        'touch-act',
        'touch-ammo',
        'mission-board',
      ];
      for (final key in controls) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }

      game.showPrompt(const <StoryLine>[StoryLine('Un messaggio')]);
      await tester.pump();
      for (final key in controls) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }

      await tester.tap(find.byKey(const ValueKey<String>('gameplay-dialogue')));
      await tester.pump();
      for (final key in controls) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
    });
  });

  testWidgets('thumbs still down when a text box takes the controls away '
      'move and lift without touching the controls that are gone', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      // Far enough apart in time not to be taken for a pinch.
      final left = await tester.createGesture(pointer: 1);
      await left.down(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-move'))),
      );
      final right = await tester.createGesture(pointer: 2);
      await right.down(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-act'))),
        timeStamp: const Duration(seconds: 1),
      );
      await left.moveBy(const Offset(0, -30));
      await right.moveBy(const Offset(4, 0));
      expect(game.pinching.value, isFalse);

      game.showPrompt(const <StoryLine>[StoryLine('Un messaggio')]);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('touch-move')), findsNothing);

      // The same fingers keep going over the text box, then lift.
      await left.moveBy(const Offset(10, -10));
      await right.moveBy(const Offset(-10, 10));
      await left.up();
      await right.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('walking off a map with no next map, thumb still down, '
      'brings up the work-in-progress screen and nothing breaks', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      // East of Termini, two steps from where the piazza runs off the map.
      final piazza = place(PlaceId.piazzaCinquecento);
      final mario = game.simulation.player.component<PositionComponent>()
        ..position = GridPoint(piazza.bounds.right - 2, piazza.origin.y + 8);
      await tester.pump(const Duration(milliseconds: 100));

      final thumb = await tester.createGesture(pointer: 1);
      await thumb.down(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-move'))),
      );
      for (var i = 0; i < 6; i++) {
        await thumb.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final screen = find.byKey(const ValueKey<String>('work-in-progress'));
      for (var i = 0; i < 40 && screen.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(screen, findsOneWidget);
      expect(
        mario.position,
        GridPoint(piazza.bounds.right, piazza.origin.y + 8),
      );
      expect(find.byKey(const ValueKey<String>('touch-move')), findsNothing);

      // The thumb goes on over the screen, then lifts.
      await thumb.moveBy(const Offset(10, 5));
      await thumb.up();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(screen);
      await tester.pump();
      expect(screen, findsNothing);
      expect(
        mario.position,
        GridPoint(piazza.bounds.right - 1, piazza.origin.y + 8),
      );
      expect(mario.facing, Direction.west);
    });
  });

  testWidgets('a story line over a picture already seen comes up with the '
      'tap that turns to it', (tester) async {
    const same = 'assets/story/scenes/mario_luigi_reunion.jpg';
    var finished = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StoryIntro(
          scenes: const <StoryScene>[
            StoryScene(image: same, text: 'Prima'),
            StoryScene(image: same, text: 'Seconda'),
            StoryScene(
              image: 'assets/story/scenes/outbreak.jpg',
              text: 'Terza',
            ),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    final story = find.byKey(const ValueKey<String>('story-intro'));
    Future<void> tap() async {
      await tester.tap(story);
      await tester.pump();
    }

    // A new picture is worth a look before its line covers it.
    expect(find.text('Prima'), findsNothing);
    await tap();
    expect(find.text('Prima'), findsOneWidget);

    // The second line is spoken over the same picture: one tap, not two.
    await tap();
    expect(find.text('Seconda'), findsOneWidget);

    // The third changes the picture, so that one waits for its own tap.
    await tap();
    expect(find.text('Terza'), findsNothing);
    await tap();
    expect(find.text('Terza'), findsOneWidget);

    await tap();
    expect(finished, isTrue);
  });

  testWidgets('a text box ignores the taps of someone still walking', (tester) {
    return tester.runAsync(() async {
      // The opening lines are tapped through with no pause, as everywhere
      // else; the pause is what this test is about, so it starts here.
      final game = await pumpReadyGame(tester);
      GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime;
      final lines = <StoryLine>[
        const StoryLine('Prima battuta'),
        const StoryLine('Seconda battuta'),
      ];
      game.showPrompt(lines);
      await tester.pump();
      final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
      expect(find.text('Prima battuta'), findsOneWidget);

      // The tap that was meant for an arrow button lands on the box.
      await tester.tap(dialogue);
      await tester.pump();
      expect(
        find.text('Prima battuta'),
        findsOneWidget,
        reason: 'the first line was eaten by a walking tap',
      );

      await Future<void>.delayed(GameplayDialogue.defaultSettleTime);
      await tester.pump();
      await tester.tap(dialogue);
      await tester.pump();
      expect(find.text('Seconda battuta'), findsOneWidget);
    });
  });
}
