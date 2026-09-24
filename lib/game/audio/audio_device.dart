import 'package:stepbound/game/audio/lingering_shots.dart';

/// A looping player: one of the two music decks, or an ambience bed.
abstract interface class LoopingPlayer {
  Future<void> stop();
  Future<void> setVolume(double volume);

  /// [file] under `assets/audio/`.
  Future<void> setSource(String file);
  Future<void> resume();
  Future<void> pause();
  Future<void> dispose();
}

/// What `PlayerAudio` plays its sound on: the device, through audioplayers,
/// or a fake that tests can inspect. Everything that decides what plays,
/// how loud and when lives in `PlayerAudio`; this is only the hardware.
abstract interface class AudioDevice {
  /// A new looping player, [id] naming it in the platform's logs.
  LoopingPlayer loopingPlayer(String id);

  /// Loads the effect [file] ahead, so its first shot is not late.
  Future<void> preload(String file, {required int voices});

  /// Starts one copy of the effect [file], up to [voices] of them side by
  /// side; completes with the way to cut it short.
  Future<StopShot> shoot(
    String file, {
    required int voices,
    required double volume,
  });

  /// Lets go of every effect loaded.
  Future<void> dispose();
}
