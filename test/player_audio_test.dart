import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stepbound/game/audio/audio_device.dart';
import 'package:stepbound/game/audio/lingering_shots.dart';
import 'package:stepbound/game/audio/player_audio.dart';
import 'package:stepbound/game/audio/sound.dart';

/// A looping player that remembers what it was told.
final class _FakeLoop implements LoopingPlayer {
  _FakeLoop(this.id);

  final String id;
  String? source;
  double volume = 0;
  bool playing = false;
  bool disposed = false;

  /// How many of the next resumes the browser refuses (before a tap).
  int refusals = 0;

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> setSource(String file) async => source = file;

  @override
  Future<void> resume() async {
    if (refusals > 0) {
      refusals--;
      throw StateError('play() refused before a tap');
    }
    playing = true;
  }

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> dispose() async => disposed = true;
}

/// A device that plays nothing and keeps count.
final class _FakeDevice implements AudioDevice {
  final List<_FakeLoop> loops = <_FakeLoop>[];
  final List<String> preloaded = <String>[];

  /// Every effect started, and whether it is still playing.
  final List<(String, double)> shots = <(String, double)>[];
  final Map<int, bool> shotPlaying = <int, bool>{};
  bool disposed = false;

  _FakeLoop loop(String id) => loops.lastWhere((loop) => loop.id == id);

  @override
  LoopingPlayer loopingPlayer(String id) {
    final loop = _FakeLoop(id);
    loops.add(loop);
    return loop;
  }

  @override
  Future<void> preload(String file, {required int voices}) async =>
      preloaded.add(file);

  @override
  Future<StopShot> shoot(
    String file, {
    required int voices,
    required double volume,
  }) async {
    final index = shots.length;
    shots.add((file, volume));
    shotPlaying[index] = true;
    return () async => shotPlaying[index] = false;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late _FakeDevice device;
  late SharedPreferencesAsync preferences;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    device = _FakeDevice();
  });

  PlayerAudio audio() => PlayerAudio(preferences: preferences, device: device);

  /// Lets the fades run for [seconds] on the test's clock.
  Future<void> run(WidgetTester tester, double seconds) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
    await tester.pump();
  }

  testWidgets('the first sounds of the game are loaded ahead', (tester) async {
    audio();
    await tester.pump();
    expect(device.preloaded, <String>[
      for (final sfx in PlayerAudio.preloaded) ...sfx.files,
    ]);
  });

  testWidgets('music fades in, and a new piece crossfades with the last', (
    tester,
  ) async {
    final sound = audio()..playMusic(Music.menu);
    await run(tester, 2);
    final first = device.loop('music-b');
    expect(first.source, Music.menu.file);
    expect(first.playing, isTrue);
    expect(first.volume, closeTo(PlayerAudio.musicVolume, 0.001));

    sound.playMusic(Music.story);
    await run(tester, 0.4);
    final second = device.loop('music-a');
    expect(second.source, Music.story.file);
    expect(first.volume, greaterThan(0), reason: 'still fading out');
    expect(second.volume, greaterThan(0), reason: 'already fading in');

    await run(tester, 2);
    expect(first.volume, 0);
    expect(first.playing, isFalse, reason: 'paused once silent');
    expect(second.volume, closeTo(PlayerAudio.musicVolume, 0.001));

    // The same piece again changes nothing.
    sound.playMusic(Music.story);
    await run(tester, 1);
    expect(second.volume, closeTo(PlayerAudio.musicVolume, 0.001));
  });

  testWidgets('the music level scales the music, and null fades it out', (
    tester,
  ) async {
    final sound = audio()..playMusic(Music.street);
    await run(tester, 2);
    sound.setMusicLevel(0.5);
    await run(tester, 2);
    final deck = device.loop('music-b');
    expect(deck.volume, closeTo(PlayerAudio.musicVolume * 0.5, 0.001));

    sound.playMusic(null);
    await run(tester, 2);
    expect(deck.volume, 0);
    expect(deck.playing, isFalse);
  });

  testWidgets('ambience fades to its volume, out to nothing and all at '
      'once', (tester) async {
    final sound = audio()
      ..setAmbience(Ambience.fire, 0.8)
      ..setAmbience(Ambience.wind, 0.4)
      // Nothing to fade out: no player is made for it.
      ..setAmbience(Ambience.indoor, 0);
    await run(tester, 3);
    final fire = device.loop(Ambience.fire.name);
    expect(fire.source, Ambience.fire.file);
    expect(fire.volume, closeTo(0.8, 0.001));
    expect(device.loops.where((loop) => loop.id == 'indoor'), isEmpty);

    sound.setAmbience(Ambience.fire, 0);
    await run(tester, 2);
    expect(fire.volume, 0);
    expect(fire.playing, isFalse);

    sound
      ..setAmbience(Ambience.fire, 0.5)
      ..silenceAmbience();
    await run(tester, 2);
    expect(fire.volume, 0);
    expect(device.loop(Ambience.wind.name).volume, 0);
  });

  testWidgets('muting silences everything, keeps playing, and is '
      'remembered', (tester) async {
    final sound = audio()..playMusic(Music.menu);
    await run(tester, 2);
    sound.muted = true;
    await run(tester, 0.1);
    final deck = device.loop('music-b');
    expect(deck.volume, 0);
    expect(deck.playing, isTrue, reason: 'unmuting picks up where it is');
    sound.play(Sfx.uiClick);
    await run(tester, 0.1);
    expect(device.shots, isEmpty, reason: 'no effects while muted');

    final later = audio();
    await run(tester, 0.1);
    expect(later.muted, isTrue);
    expect(await preferences.getBool(PlayerAudio.mutedKey), isTrue);
  });

  testWidgets('in the background everything pauses, and comes back after', (
    tester,
  ) async {
    final sound = audio()
      ..playMusic(Music.menu)
      ..setAmbience(Ambience.wind, 0.5);
    await run(tester, 3);
    sound.pause();
    await run(tester, 0.1);
    final deck = device.loop('music-b');
    final wind = device.loop(Ambience.wind.name);
    expect(deck.playing, isFalse);
    expect(wind.playing, isFalse);

    sound.play(Sfx.step);
    await run(tester, 0.1);
    expect(device.shots, isEmpty, reason: 'no effects in the background');
    // A piece chosen meanwhile waits for the app to come back.
    sound.playMusic(Music.danger);
    await run(tester, 0.5);
    expect(device.loop('music-a').playing, isFalse);

    sound.resume();
    await run(tester, 0.1);
    expect(device.loop('music-a').playing, isTrue);
    expect(wind.playing, isTrue);
    // Resuming twice is resuming once.
    sound.resume();
    await run(tester, 2);
    expect(device.loop('music-a').playing, isTrue);
  });

  testWidgets('the game over sting is cut by stop, and by the background', (
    tester,
  ) async {
    final sound = audio()..play(Sfx.gameOver);
    await run(tester, 0.1);
    expect(device.shots.single.$1, Sfx.gameOver.files.single);
    sound.stop(Sfx.gameOver);
    await run(tester, 0.1);
    expect(device.shotPlaying[0], isFalse);

    sound.play(Sfx.gameOver);
    await run(tester, 0.1);
    sound.pause();
    await run(tester, 0.1);
    expect(device.shotPlaying[1], isFalse);
  });

  testWidgets('an effect plays one of its files at its own volume', (
    tester,
  ) async {
    audio().play(Sfx.step, volume: 0.5);
    await run(tester, 0.1);
    final (file, volume) = device.shots.single;
    expect(Sfx.step.files, contains(file));
    expect(volume, closeTo(Sfx.step.volume * 0.5, 0.001));
  });

  testWidgets('music the browser refused before a tap starts on the tap', (
    tester,
  ) async {
    // The first piece goes on the second deck; it refuses its first start.
    final sound = audio()..playMusic(Music.menu);
    device.loop('music-b').refusals = 1;
    await run(tester, 2);
    expect(device.loop('music-b').playing, isFalse);

    sound.unlock();
    await run(tester, 0.1);
    expect(device.loop('music-b').playing, isTrue);
  });

  testWidgets('dispose lets go of every player and of the effects', (
    tester,
  ) async {
    final sound = audio()
      ..playMusic(Music.menu)
      ..setAmbience(Ambience.fire, 1);
    await run(tester, 0.2);
    await sound.dispose();
    expect(
      device.loops,
      everyElement(
        isA<_FakeLoop>().having((loop) => loop.disposed, 'disposed', isTrue),
      ),
    );
    expect(device.disposed, isTrue);
  });
}
