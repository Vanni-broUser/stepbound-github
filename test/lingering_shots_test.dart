import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/audio/lingering_shots.dart';
import 'package:stepbound/game/audio/sound.dart';

/// One copy of the sting as the pool plays it: it starts when [start]
/// completes, and plays until its stop function is called.
final class _Copy {
  final Completer<StopShot> start = Completer<StopShot>();
  bool playing = false;

  void started() {
    playing = true;
    start.complete(() async => playing = false);
  }
}

void main() {
  late LingeringShots shots;

  setUp(() => shots = LingeringShots());

  test('a stop that comes in while the sting is still starting cuts it as '
      'soon as it has started', () async {
    // Resuming from the fire before the pool has even loaded the file.
    final copy = _Copy();
    shots
      ..add(Sfx.gameOver, copy.start.future)
      ..stop(Sfx.gameOver);
    copy.started();
    await pumpEventQueue();
    expect(copy.playing, isFalse);
    expect(shots.length, 0);
  });

  test('a second game over cuts the first sting, even one whose stop was '
      'lost', () async {
    final first = _Copy()..started();
    shots.add(Sfx.gameOver, first.start.future);
    await pumpEventQueue();
    expect(first.playing, isTrue);

    final second = _Copy();
    shots.add(Sfx.gameOver, second.start.future);
    second.started();
    await pumpEventQueue();
    expect(first.playing, isFalse, reason: 'never two stings at once');
    expect(second.playing, isTrue);

    // And the one left is still in reach of the buttons.
    shots.stop(Sfx.gameOver);
    await pumpEventQueue();
    expect(second.playing, isFalse);
  });

  test('going to the background cuts the sting', () async {
    final copy = _Copy()..started();
    shots.add(Sfx.gameOver, copy.start.future);
    await pumpEventQueue();
    shots.stopAll();
    await pumpEventQueue();
    expect(copy.playing, isFalse);
    expect(shots.length, 0);
  });

  test('going to the background while the sting is starting cuts it once '
      'it has started', () async {
    final copy = _Copy();
    shots
      ..add(Sfx.gameOver, copy.start.future)
      ..stopAll();
    copy.started();
    await pumpEventQueue();
    expect(copy.playing, isFalse);
  });

  test('a sting nobody stops plays to its end', () async {
    final copy = _Copy()..started();
    shots.add(Sfx.gameOver, copy.start.future);
    await pumpEventQueue();
    expect(copy.playing, isTrue);
    expect(shots.length, 1);
  });

  test('a copy that fails to start is forgotten, not thrown', () async {
    final failing = Completer<StopShot>();
    shots.add(Sfx.gameOver, failing.future);
    failing.completeError(StateError('no audio device'));
    await pumpEventQueue();
    shots.stop(Sfx.gameOver);
    expect(shots.length, 0);
  });

  test('only the game over sting lingers', () {
    expect(
      <Sfx>[
        for (final sfx in Sfx.values)
          if (sfx.lingers) sfx,
      ],
      <Sfx>[Sfx.gameOver],
    );
  });
}
