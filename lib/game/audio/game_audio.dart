import 'package:stepbound/game/audio/sound.dart';

/// Everything the game and its screens ask of the sound. The calls never
/// wait: fades and loading happen behind them.
abstract interface class GameAudio {
  /// Silences everything without stopping it, so unmuting picks up where
  /// the music is.
  bool get muted;
  set muted(bool value);

  /// Crossfades to [music]; null fades the music out.
  void playMusic(Music? music);

  /// Scales the music, 0 to 1, easing to it (the fire's crackle pushes the
  /// music back).
  void setMusicLevel(double level);

  /// Eases [ambience] to [volume], 0 to 1; at 0 it stops.
  void setAmbience(Ambience ambience, double volume);

  /// Fades every ambience out.
  void silenceAmbience();

  void play(Sfx sfx, {double volume = 1});

  /// Cuts [sfx] short if it is still playing, or as soon as it has started
  /// if it is still starting. Only the long ones ([Sfx.lingers]) are kept
  /// track of: the game over sting would otherwise play on over the game
  /// that starts again.
  void stop(Sfx sfx);

  /// A tap happened: browsers only let sound start after one, so what they
  /// refused earlier is started again.
  void unlock();

  /// The app went to the background, or came back.
  void pause();
  void resume();

  Future<void> dispose();
}

/// Plays nothing; tests use it, and so does the game when it is given no
/// audio. It remembers what it was asked, for tests to check.
final class SilentAudio implements GameAudio {
  SilentAudio();

  @override
  bool muted = false;

  Music? music;
  double musicLevel = 1;
  final Map<Ambience, double> ambience = <Ambience, double>{};
  final List<Sfx> played = <Sfx>[];
  final List<Sfx> stopped = <Sfx>[];

  /// Whether the app is in the background, as the lifecycle last said.
  bool paused = false;

  @override
  void playMusic(Music? music) => this.music = music;

  @override
  void setMusicLevel(double level) => musicLevel = level;

  @override
  void setAmbience(Ambience ambience, double volume) =>
      this.ambience[ambience] = volume;

  @override
  void silenceAmbience() => ambience.clear();

  @override
  void play(Sfx sfx, {double volume = 1}) => played.add(sfx);

  @override
  void stop(Sfx sfx) => stopped.add(sfx);

  @override
  void unlock() {}

  @override
  void pause() => paused = true;

  @override
  void resume() => paused = false;

  @override
  Future<void> dispose() async {}
}
