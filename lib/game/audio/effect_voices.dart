import 'package:stepbound/game/audio/lingering_shots.dart';

/// One player loaded with an effect, ready to play it from the top.
abstract interface class EffectPlayer {
  bool get isPlaying;
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> resume();
  Future<void> dispose();
}

/// The players of one effect: never more than [count], whatever is asked.
///
/// audioplayers' own `AudioPool` makes a new player whenever all of its
/// are busy, and when that one is done it only releases it: the player
/// itself, its platform side and its streams stay for good. A horde's
/// groans, three seconds each, outnumber their voices every few turns, so
/// a long session left more and more dead players behind, and the game
/// slowed down until it was restarted. Here a shot with every voice busy
/// takes over the one that started first, as an old sound chip would.
final class EffectVoices {
  EffectVoices({required this.count, required this.newPlayer})
    : assert(count > 0, 'an effect needs a voice');

  final int count;

  /// Makes and loads one more player of this effect.
  final Future<EffectPlayer> Function() newPlayer;

  final List<_Voice> _voices = <_Voice>[];
  int _shots = 0;

  /// One change at a time, in the order asked.
  Future<void> _queue = Future<void>.value();

  /// How many players there are, for tests.
  int get players => _voices.length;

  Future<T> _serially<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Makes the first voice, so the first shot is not late.
  Future<void> preload() => _serially(() async {
    if (_voices.isEmpty) {
      _voices.add(_Voice(await newPlayer()));
    }
  });

  /// Plays the effect once at [volume]; completes with the way to cut
  /// this copy short.
  Future<StopShot> start({required double volume}) => _serially(() async {
    final voice = await _freeVoice();
    final shot = voice.shot = ++_shots;
    final player = voice.player;
    // From the top, even over what it was still playing.
    await player.stop();
    await player.setVolume(volume);
    await player.resume();
    return () => _serially(() async {
      // Only the copy this shot started: the voice may be playing another.
      if (voice.shot == shot) {
        await player.stop();
      }
    });
  });

  /// A voice that is not playing, a new one while there are fewer than
  /// [count], or else the one playing for the longest.
  Future<_Voice> _freeVoice() async {
    for (final voice in _voices) {
      if (!voice.player.isPlaying) {
        return voice;
      }
    }
    if (_voices.length < count) {
      final voice = _Voice(await newPlayer());
      _voices.add(voice);
      return voice;
    }
    return _voices.reduce((a, b) => a.shot <= b.shot ? a : b);
  }

  Future<void> dispose() => _serially(() async {
    for (final voice in _voices) {
      await voice.player.dispose();
    }
    _voices.clear();
  });
}

final class _Voice {
  _Voice(this.player);

  final EffectPlayer player;

  /// Which shot it last started: the higher, the more recent.
  int shot = 0;
}
