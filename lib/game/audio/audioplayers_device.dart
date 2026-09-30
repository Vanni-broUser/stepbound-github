import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:stepbound/game/audio/audio_device.dart';
import 'package:stepbound/game/audio/effect_voices.dart';
import 'package:stepbound/game/audio/lingering_shots.dart';

/// The device's sound through audioplayers: every looping player and every
/// set of effect voices mixes with the rest of the phone's sound.
///
/// It needs the native player, so it is exercised on devices and not by the
/// tests, which give `PlayerAudio` a fake instead: keep it this thin.
final class AudioplayersDevice implements AudioDevice {
  AudioplayersDevice() {
    // Plays along with the other sounds of the game (and of the phone):
    // with the default focus every effect would pause the music on Android.
    unawaited(_logged(AudioPlayer.global.setAudioContext(_context)));
  }

  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  final AudioCache _cache = AudioCache(prefix: 'assets/audio/');
  final Map<String, EffectVoices> _voices = <String, EffectVoices>{};

  @override
  LoopingPlayer loopingPlayer(String id) {
    final player = AudioPlayer(playerId: 'stepbound-$id')..audioCache = _cache;
    return _AudioplayersLoop(player);
  }

  @override
  Future<void> preload(String file, {required int voices}) =>
      _voicesOf(file, voices: voices).preload();

  @override
  Future<StopShot> shoot(
    String file, {
    required int voices,
    required double volume,
  }) => _voicesOf(file, voices: voices).start(volume: volume);

  EffectVoices _voicesOf(String file, {required int voices}) =>
      _voices.putIfAbsent(
        file,
        () => EffectVoices(
          count: voices,
          newPlayer: () => _AudioplayersEffect.load(file, _cache),
        ),
      );

  @override
  Future<void> dispose() async {
    for (final voices in _voices.values) {
      await voices.dispose();
    }
  }
}

/// One voice of an effect, as `EffectVoices` wants it.
final class _AudioplayersEffect implements EffectPlayer {
  _AudioplayersEffect(this._player);

  static Future<EffectPlayer> load(String file, AudioCache cache) async {
    final player = AudioPlayer()..audioCache = cache;
    await player.setAudioContext(AudioplayersDevice._context);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(file));
    return _AudioplayersEffect(player);
  }

  final AudioPlayer _player;

  @override
  bool get isPlaying => _player.state == PlayerState.playing;

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> dispose() => _player.dispose();
}

final class _AudioplayersLoop implements LoopingPlayer {
  _AudioplayersLoop(this._player) {
    unawaited(_logged(_player.setAudioContext(AudioplayersDevice._context)));
    unawaited(_logged(_player.setReleaseMode(ReleaseMode.loop)));
  }

  final AudioPlayer _player;

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSource(String file) => _player.setSource(AssetSource(file));

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Setting a player up is never worth crashing over: a platform that
/// refuses is logged and the sound goes on without it.
Future<void> _logged(Future<void> future) async {
  try {
    await future;
  } on Object catch (error) {
    debugPrint('audio: $error');
  }
}
