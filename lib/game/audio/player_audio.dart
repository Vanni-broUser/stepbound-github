import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/game/audio/audio_device.dart';
import 'package:stepbound/game/audio/audioplayers_device.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/lingering_shots.dart';
import 'package:stepbound/game/audio/sound.dart';

/// The game's sound on an [AudioDevice], the phone's through audioplayers
/// unless another is given. Music and ambience are looping players whose
/// volumes glide towards a target on a small timer; effects are shots the
/// device plays side by side.
///
/// With `startMuted` the game starts silent whatever was saved, and does not
/// read the saved setting: the browser build, which is only for testing,
/// starts that way, so a tab left open does not play on.
final class PlayerAudio implements GameAudio {
  PlayerAudio({
    SharedPreferencesAsync? preferences,
    AudioDevice? device,
    bool startMuted = false,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _device = device ?? AudioplayersDevice(),
       _muted = startMuted {
    if (!startMuted) {
      unawaited(_loadMuted());
    }
    // The sounds of the first minutes are loaded ahead, so they are not
    // late the first time.
    for (final sfx in preloaded) {
      for (final file in sfx.files) {
        unawaited(_guard(_device.preload(file, voices: sfx.voices)));
      }
    }
  }

  /// Loaded as soon as the audio starts.
  static const List<Sfx> preloaded = <Sfx>[
    Sfx.step,
    Sfx.uiClick,
    Sfx.zombieAlert,
  ];

  static const String mutedKey = 'stepbound.audio.muted';

  /// Loudness of the music at level 1, under the effects.
  static const double musicVolume = 0.55;

  static const Duration _tick = Duration(milliseconds: 50);
  static const double _crossfadeSeconds = 1.6;

  final SharedPreferencesAsync _preferences;
  final AudioDevice _device;
  final Random _random = Random();

  /// Two decks, so the next piece fades in while the last one fades out.
  late final List<_Channel> _decks = <_Channel>[
    _Channel(_newPlayer('music-a')),
    _Channel(_newPlayer('music-b')),
  ];
  int _activeDeck = 0;
  Music? _music;
  double _musicLevel = 1;

  final Map<Ambience, _Channel> _ambience = <Ambience, _Channel>{};

  /// The copies of the long effects, playing or still starting.
  final LingeringShots _lingering = LingeringShots();

  Timer? _fader;
  bool _muted;
  bool _paused = false;

  LoopingPlayer _newPlayer(String id) => _device.loopingPlayer(id);

  Future<void> _loadMuted() async {
    try {
      muted = await _preferences.getBool(mutedKey) ?? false;
    } on Object catch (error) {
      debugPrint('audio: could not read the mute setting ($error)');
    }
  }

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    if (_muted == value) {
      return;
    }
    _muted = value;
    unawaited(_guard(_preferences.setBool(mutedKey, value)));
    for (final channel in _channels) {
      channel.applyVolume(master: _master);
    }
  }

  double get _master => _muted ? 0 : 1;

  Iterable<_Channel> get _channels => <_Channel>[
    ..._decks,
    ..._ambience.values,
  ];

  @override
  void playMusic(Music? music) {
    if (music == _music) {
      return;
    }
    _music = music;
    _decks[_activeDeck].fadeTo(0, _crossfadeSeconds);
    if (music == null) {
      _startFader();
      return;
    }
    // The decks alternate: the other one takes the new music.
    _activeDeck = 1 - _activeDeck;
    _decks[_activeDeck]
      ..load(music.file, master: _master, paused: _paused)
      ..fadeTo(musicVolume * _musicLevel, _crossfadeSeconds);
    _startFader();
  }

  @override
  void setMusicLevel(double level) {
    final clamped = level.clamp(0.0, 1.0);
    if ((clamped - _musicLevel).abs() < 0.01) {
      return;
    }
    _musicLevel = clamped;
    if (_music != null) {
      _decks[_activeDeck].fadeTo(musicVolume * _musicLevel, 1.2);
      _startFader();
    }
  }

  @override
  void setAmbience(Ambience ambience, double volume) {
    final target = volume.clamp(0.0, 1.0);
    final channel = _ambience[ambience];
    if (channel == null) {
      if (target <= 0) {
        return;
      }
      _ambience[ambience] = _Channel(_newPlayer(ambience.name))
        ..load(ambience.file, master: _master, paused: _paused)
        ..fadeTo(target, 2);
    } else {
      if ((channel.target - target).abs() < 0.01) {
        return;
      }
      // The new target first: coming back from silence it is what says
      // the loop has to start again.
      channel
        ..fadeTo(target, 1.5)
        ..ensurePlaying(paused: _paused);
    }
    _startFader();
  }

  @override
  void silenceAmbience() {
    for (final channel in _ambience.values) {
      channel.fadeTo(0, 1.2);
    }
    _startFader();
  }

  @override
  void play(Sfx sfx, {double volume = 1}) {
    if (_muted || _paused) {
      return;
    }
    final file = sfx.files[_random.nextInt(sfx.files.length)];
    final level = (sfx.volume * volume).clamp(0.0, 1.0);
    final starting = _device.shoot(file, voices: sfx.voices, volume: level);
    if (sfx.lingers) {
      _lingering.add(sfx, starting);
    } else {
      // A short one is over before anything could want it stopped.
      unawaited(_guard(starting));
    }
  }

  @override
  void stop(Sfx sfx) => _lingering.stop(sfx);

  @override
  void unlock() {
    if (_paused) {
      return;
    }
    for (final channel in _channels) {
      channel.retryIfBlocked();
    }
  }

  @override
  void pause() {
    _paused = true;
    for (final channel in _channels) {
      channel.pause();
    }
    // The effects play from their own pools, not from the channels, so
    // pausing those leaves them running: the game over sting is long
    // enough to carry on over whatever the phone does next. Cut every
    // long one, even one still starting; a one-shot has nothing to come
    // back to.
    _lingering.stopAll();
  }

  @override
  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    for (final channel in _channels) {
      channel.ensurePlaying(paused: false);
    }
  }

  void _startFader() {
    _fader ??= Timer.periodic(_tick, (_) => _fade());
  }

  void _fade() {
    final seconds = _tick.inMicroseconds / Duration.microsecondsPerSecond;
    var moving = false;
    for (final channel in _channels) {
      moving = channel.step(seconds, master: _master) || moving;
    }
    if (!moving) {
      _fader?.cancel();
      _fader = null;
    }
  }

  @override
  Future<void> dispose() async {
    _fader?.cancel();
    for (final channel in _channels) {
      await channel.dispose();
    }
    await _guard(_device.dispose());
  }
}

/// A looping player and the volume it is gliding to.
///
/// Every call that changes what the player plays -- its source, starting,
/// pausing, stopping -- goes through one queue and waits for the one before.
/// Overlapping them is what broke the sound: on the web a start that landed
/// while a new source was still being set up made a second audio element,
/// which nothing held any more, so it looped on for good, over the fades,
/// over the pause, even with the app in the background. Whether it should
/// be heard is a wish ([_wanted]) that the queue carries out when its turn
/// comes, so a burst of changes settles on the last one.
final class _Channel {
  _Channel(this.player);

  final LoopingPlayer player;
  double volume = 0;
  double target = 0;

  /// Volume change per second of the current fade.
  double _rate = 1;
  String? _file;
  Future<void> _queue = Future<void>.value();

  /// Whether it should be playing, and whether the player is.
  bool _wanted = false;
  bool _playing = false;

  /// The browser refused to start it before the first tap.
  bool _blocked = false;

  void _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) => _guard(operation()));
  }

  void load(String file, {required double master, required bool paused}) {
    _file = file;
    volume = 0;
    _enqueue(() async {
      await player.stop();
      _playing = false;
      await player.setVolume(0);
      await player.setSource(file);
    });
    _want(playing: !paused);
  }

  void fadeTo(double value, double seconds) {
    target = value;
    _rate = max((target - volume).abs() / seconds, 0.05);
  }

  void ensurePlaying({required bool paused}) {
    if (_file == null || paused || target <= 0) {
      return;
    }
    _want(playing: true);
  }

  void retryIfBlocked() {
    if (_blocked && target > 0) {
      _want(playing: true);
    }
  }

  void pause() => _want(playing: false);

  void _want({required bool playing}) {
    _wanted = playing;
    _enqueue(_settle);
  }

  /// Brings the player in line with [_wanted], as it is now.
  Future<void> _settle() async {
    if (_wanted == _playing) {
      return;
    }
    if (!_wanted) {
      _playing = false;
      await player.pause();
      return;
    }
    try {
      await player.resume();
      _playing = true;
      _blocked = false;
    } on Object {
      _blocked = true;
    }
  }

  void applyVolume({required double master}) {
    unawaited(_guard(player.setVolume(volume * master)));
  }

  /// Moves the volume one tick towards the target; true while it moves.
  bool step(double seconds, {required double master}) {
    if (volume == target) {
      return false;
    }
    final delta = _rate * seconds;
    volume = (target - volume).abs() <= delta
        ? target
        : volume + delta * (target > volume ? 1 : -1);
    applyVolume(master: master);
    if (volume == 0 && target == 0) {
      pause();
    }
    return volume != target;
  }

  /// Lets go of the player once whatever it is doing is done.
  Future<void> dispose() {
    _enqueue(player.dispose);
    return _queue;
  }
}

/// Sound is never worth crashing over: a file that fails to load or a
/// browser that refuses to play is logged and forgotten.
Future<void> _guard(Future<void> future) async {
  try {
    await future;
  } on Object catch (error) {
    debugPrint('audio: $error');
  }
}
