import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/app_services.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/crash_guard.dart';

/// Sound that only remembers whether it was closed.
final class _Audio implements GameAudio {
  int disposals = 0;

  @override
  bool muted = false;

  @override
  void playMusic(Music? music) {}

  @override
  void setMusicLevel(double level) {}

  @override
  void setAmbience(Ambience ambience, double volume) {}

  @override
  void silenceAmbience() {}

  @override
  void play(Sfx sfx, {double volume = 1}) {}

  @override
  void stop(Sfx sfx) {}

  @override
  void unlock() {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  group('AppServices', () {
    test('what is handed in stays the caller’s', () async {
      final audio = _Audio();
      final services = AppServices(saves: MemorySaveRepository(), audio: audio);
      expect(services.ownsAudio, isFalse);
      await services.dispose();
      expect(audio.disposals, 0);
      expect(services.disposed, isTrue);
    });

    test('what is made for the scope is closed with it, once', () async {
      final audio = _Audio();
      final services = AppServices.made(
        saves: MemorySaveRepository(),
        audio: audio,
      );
      expect(services.ownsAudio, isTrue);
      await services.dispose();
      await services.dispose();
      expect(audio.disposals, 1);
    });

    test('with nothing handed in, the sound is silence of its own', () async {
      final services = AppServices(saves: MemorySaveRepository());
      expect(services.audio, isA<SilentAudio>());
      expect(services.ownsAudio, isTrue);
      await services.dispose();
    });
  });

  group('the app', () {
    testWidgets('leaves the services it was handed to whoever made them: '
        'the guard over it builds it anew on them after an error', (
      tester,
    ) async {
      final audio = _Audio();
      final services = AppServices.made(
        saves: MemorySaveRepository(),
        audio: audio,
      );
      await tester.pumpWidget(StepboundApp(services: services));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(audio.disposals, 0);
      expect(services.disposed, isFalse);
    });

    testWidgets('leaves alone the sound a test hands it', (tester) async {
      final audio = _Audio();
      await tester.pumpWidget(
        StepboundApp(saves: MemorySaveRepository(), audio: audio),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(audio.disposals, 0);
    });
  });

  group('the guard', () {
    Widget guarded(AppServices services) => CrashGuard(
      reporter: ErrorReporter(),
      services: services,
      share: (_, _) async {},
      child: StepboundApp(services: services),
    );

    testWidgets('closes the services it owns when it goes', (tester) async {
      final audio = _Audio();
      final services = AppServices.made(
        saves: MemorySaveRepository(),
        audio: audio,
      );
      await tester.pumpWidget(guarded(services));
      await tester.pump();
      expect(audio.disposals, 0, reason: 'still running');
      await tester.pumpWidget(const SizedBox());
      expect(audio.disposals, 1);
      expect(services.disposed, isTrue);
    });

    testWidgets('closes them when the engine lets go of the app too', (
      tester,
    ) async {
      final audio = _Audio();
      final services = AppServices.made(
        saves: MemorySaveRepository(),
        audio: audio,
      );
      await tester.pumpWidget(guarded(services));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(audio.disposals, 1);
      await tester.pumpWidget(const SizedBox());
      expect(audio.disposals, 1, reason: 'once');
    });
  });
}
