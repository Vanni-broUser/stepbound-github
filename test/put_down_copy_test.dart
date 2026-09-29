import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/game_snapshot.dart';
import 'package:stepbound/game/put_down_copy.dart';

void main() {
  var taken = 0;
  GameSnapshot take() => (
    world: const <String, Object?>{},
    story: const <String, Object?>{},
    progress: const <String, Object?>{},
    hud: const <String>[],
    place: 'copia ${++taken}',
  );

  setUp(() => taken = 0);

  test('nothing is copied while the game cannot be put down', () {
    final copy = PutDownCopy()..keep(1, canBePutDown: false, take: take);
    expect(copy.copy, isNull);
    expect(taken, 0);
    expect(copy.snapshot(canBePutDown: false, take: take), isNull);
  });

  test('a copy is taken as soon as the game can be put down, then on the '
      'interval', () {
    final copy = PutDownCopy(interval: 2)
      ..keep(0.1, canBePutDown: true, take: take);
    expect(copy.copy?.place, 'copia 1', reason: 'at once');
    copy.keep(1, canBePutDown: true, take: take);
    expect(copy.copy?.place, 'copia 1', reason: 'too soon');
    copy.keep(1, canBePutDown: true, take: take);
    expect(copy.copy?.place, 'copia 2', reason: 'two seconds later');
  });

  test('back from a moment it could not be, a fresh copy is taken at once', () {
    final copy = PutDownCopy(interval: 10)
      ..keep(0.1, canBePutDown: true, take: take)
      ..keep(0.1, canBePutDown: false, take: take)
      ..keep(0.1, canBePutDown: true, take: take);
    expect(copy.copy?.place, 'copia 2');
  });

  test('the snapshot is the game itself when it can be put down, the copy '
      'otherwise', () {
    final copy = PutDownCopy()..keep(0.1, canBePutDown: true, take: take);
    expect(copy.snapshot(canBePutDown: false, take: take)?.place, 'copia 1');
    expect(copy.snapshot(canBePutDown: true, take: take)?.place, 'copia 2');
    expect(copy.copy?.place, 'copia 1', reason: 'the copy is not renewed');
  });

  test('a dropped copy is gone until the interval renews it', () {
    final copy = PutDownCopy()
      ..keep(0.1, canBePutDown: true, take: take)
      ..drop();
    expect(copy.snapshot(canBePutDown: false, take: take), isNull);
    copy.keep(0.1, canBePutDown: true, take: take);
    expect(copy.copy, isNull, reason: 'a save does not reset the cadence');
    copy.keep(PutDownCopy.defaultInterval, canBePutDown: true, take: take);
    expect(copy.copy?.place, 'copia 2');
  });
}
