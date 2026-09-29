import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/player_audio.dart';
import 'package:stepbound/save/save_game.dart';

/// What the app runs on: where the four save slots live and what plays
/// the sound. Whoever makes an [AppServices] says which of them it made
/// itself, and [dispose] closes only those: a service handed in by a test
/// or by the platform stays its caller's to close.
final class AppServices {
  /// [saves] and [audio] handed in, or the device storage and silence for
  /// whichever is left out; only what is made here is owned here.
  AppServices({SaveRepository? saves, GameAudio? audio})
    : saves = saves ?? PreferencesSaveRepository(),
      audio = audio ?? SilentAudio(),
      ownsAudio = audio == null;

  /// [saves] and [audio] made by the caller for this scope, which owns
  /// them from now on and closes them with [dispose].
  AppServices.made({required this.saves, required this.audio})
    : ownsAudio = true;

  /// The phone's: the device storage and the sound of the game, [silent]
  /// until unmuted (the browser, where the game is only tested, starts
  /// so). Owned: whoever runs the app closes them when it ends.
  factory AppServices.device({required bool silent}) => AppServices.made(
    saves: PreferencesSaveRepository(),
    audio: PlayerAudio(startMuted: silent),
  );

  /// Where the four save slots live.
  final SaveRepository saves;

  /// The sound of the game.
  final GameAudio audio;

  /// Whether [audio] was made here and is closed by [dispose]. The saves
  /// hold nothing that needs closing.
  final bool ownsAudio;

  bool _disposed = false;

  /// Whether [dispose] has run.
  bool get disposed => _disposed;

  /// Closes what was made here, once; what was handed in is left alone.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (ownsAudio) {
      await audio.dispose();
    }
  }
}
