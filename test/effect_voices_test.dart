import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/audio/effect_voices.dart';

final class _FakePlayer implements EffectPlayer {
  _FakePlayer(this.id);

  final int id;
  int starts = 0;
  double volume = 1;
  bool disposed = false;

  @override
  bool isPlaying = false;

  @override
  Future<void> stop() async => isPlaying = false;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> resume() async {
    starts += 1;
    isPlaying = true;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late List<_FakePlayer> made;
  EffectVoices voices(int count) => EffectVoices(
    count: count,
    newPlayer: () async {
      final player = _FakePlayer(made.length);
      made.add(player);
      return player;
    },
  );

  setUp(() => made = <_FakePlayer>[]);

  test('a horde of shots never makes more players than the voices', () async {
    final groans = voices(3);
    for (var i = 0; i < 500; i++) {
      await groans.start(volume: 0.5);
    }
    expect(made, hasLength(3));
    expect(groans.players, 3);
    // Each took its turn: the one that started first is taken over.
    expect(made.map((player) => player.starts), <int>[167, 167, 166]);
  });

  test('a voice that has finished is used again before a new one', () async {
    final steps = voices(4);
    for (var i = 0; i < 20; i++) {
      await steps.start(volume: 1);
      made.last.isPlaying = false;
    }
    expect(made, hasLength(1));
    expect(made.single.starts, 20);
  });

  test('preloading makes the first voice ahead of the first shot', () async {
    final alert = voices(3);
    await alert.preload();
    await alert.preload();
    expect(made, hasLength(1));
    await alert.start(volume: 0.8);
    expect(made, hasLength(1));
    expect(made.single.volume, 0.8);
  });

  test('stopping a shot leaves alone a newer shot on the same voice', () async {
    final shot = voices(1);
    final first = await shot.start(volume: 1);
    final second = await shot.start(volume: 1);
    await first();
    expect(made.single.isPlaying, isTrue);
    await second();
    expect(made.single.isPlaying, isFalse);
  });

  test('disposing lets go of every player', () async {
    final hits = voices(2);
    await hits.start(volume: 1);
    await hits.start(volume: 1);
    await hits.dispose();
    expect(made.every((player) => player.disposed), isTrue);
    expect(hits.players, 0);
  });
}
