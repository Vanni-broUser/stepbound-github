import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/crash_guard.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/story_intro.dart';

/// Waits for the report of a failed save to reach [shared]: it is put
/// together off the frame loop, reading the slot and asking the phone.
Future<void> untilShared(WidgetTester tester, List<String> shared) async {
  for (var i = 0; i < 100 && shared.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
}

/// Empty storage that cannot be written, as a full disk.
final class ReadOnlyRepository extends StoredSaveRepository {
  @override
  Future<String?> readValue(String key) async => null;

  @override
  Future<void> writeValue(String key, String value) async =>
      throw StateError('disk full');

  @override
  Future<void> removeValue(String key) async {}
}

/// Opens the app on the main menu and starts a new game in slot 1.
Future<SaveRepository> startNewGame(
  WidgetTester tester, {
  SaveRepository? saves,
  GameAudio? audio,
  ShareReport? share,
}) async {
  final repository = saves ?? MemorySaveRepository();
  await tester.pumpWidget(
    StepboundApp(saves: repository, audio: audio, share: share),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
  await tester.pump();
  await tester.pump();
  return repository;
}

/// The blood splats left on the screen.
List<LiveSplat> splats(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('blood-splats')),
                )
                .painter!
            as BloodSplatPainter)
        .splats;

/// Two taps per scene (image, then text) across the three intro scenes.
const int introTapCount = 6;

/// Waits for the game to load, as the opening dialogue only shows then.
/// Image decoding needs real time: call it from inside `tester.runAsync`.
Future<void> waitForGame(WidgetTester tester) async {
  final state = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await state.loaderFuture;
  await state.currentGame.ready();
  await tester.pump();
}

/// From inside `tester.runAsync`, like everything that loads the game.
Future<void> pumpAppThroughIntro(
  WidgetTester tester, {
  GameAudio? audio,
  SaveRepository? saves,
  ShareReport? share,
}) async {
  await startNewGame(tester, audio: audio, saves: saves, share: share);
  final intro = find.byKey(const ValueKey<String>('story-intro'));
  for (var i = 0; i < introTapCount; i++) {
    await tester.tap(intro);
    await tester.pump();
  }
  await tapThroughOutbreak(tester);
  await waitForGame(tester);
  final dialogue = find.byKey(const ValueKey<String>('gameplay-dialogue'));
  for (var i = 0; i < tutorialOpening.length; i++) {
    await tester.tap(dialogue);
    await tester.pump();
  }
}

/// Two taps per scene (image, then text) across the post-title scenes.
Future<void> tapThroughOutbreak(WidgetTester tester) async {
  final story = find.byKey(const ValueKey<String>('story-intro'));
  for (var i = 0; i < outbreakScenes.length * 2; i++) {
    await tester.tap(story);
    await tester.pump();
  }
  await pumpBlackFade(tester);
}

/// Lets a [BlackFade] started by the last pump run to completion.
Future<void> pumpBlackFade(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(
    BlackFade.defaultDuration + const Duration(milliseconds: 50),
  );
  await tester.pump();
}

/// One step: an arrow pressed and let go at once.
void tapOn(StepboundGame game, Direction direction) => game.input
  ..pressDirection(direction)
  ..releaseDirection(direction);

/// Only from inside `tester.runAsync`.
Future<StepboundGame> pumpReadyGame(
  WidgetTester tester, {
  GameAudio? audio,
  SaveRepository? saves,
  ShareReport? share,
}) async {
  await pumpAppThroughIntro(tester, audio: audio, saves: saves, share: share);
  final gameState = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await gameState.loaderFuture;
  final game = gameState.currentGame;
  await game.ready();
  return game;
}

/// The way out as Android walks it: inactive, hidden, paused.
Future<void> leaveApp(WidgetTester tester) async {
  <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ].forEach(tester.binding.handleAppLifecycleStateChanged);
  await tester.pump();
}

/// And back to the front.
Future<void> backToApp(WidgetTester tester) async {
  <AppLifecycleState>[
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ].forEach(tester.binding.handleAppLifecycleStateChanged);
  await tester.pump();
}

/// Tests tap through the lines without waiting: only the one about the
/// pause that keeps a walking tap from eating them sets the pause back.
void tapThroughDialogueAtOnce() {
  setUp(() => GameplayDialogue.settleTime = Duration.zero);
  tearDown(
    () => GameplayDialogue.settleTime = GameplayDialogue.defaultSettleTime,
  );
}
