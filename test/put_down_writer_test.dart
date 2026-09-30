import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/put_down_writer.dart';

void main() {
  late List<Completer<bool>> writes;
  late PutDownWriter writer;

  setUp(() {
    writes = <Completer<bool>>[];
    writer = PutDownWriter(() {
      final write = Completer<bool>();
      writes.add(write);
      return write.future;
    });
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('writes once per time away, and counts it once written', () async {
    writer.leftFront();
    expect(writes, hasLength(1));
    expect(writer.writing, isTrue);
    expect(writer.putDown, isFalse, reason: 'not written yet');
    writer.leftFront();
    expect(writes, hasLength(1), reason: 'the next step out waits on it');
    writes.single.complete(true);
    await settle();
    expect(writer.putDown, isTrue);
    expect(writer.writing, isFalse);
    writer.leftFront();
    expect(writes, hasLength(1), reason: 'written: not again until back');
  });

  test('a write of nothing lets the next step out try again', () async {
    writer.leftFront();
    writes.single.complete(false);
    await settle();
    expect(writer.putDown, isFalse);
    writer.leftFront();
    expect(writes, hasLength(2));
  });

  test('a write the player came back during does not count', () async {
    writer
      ..leftFront()
      ..cameToFront();
    writes.single.complete(true);
    await settle();
    expect(
      writer.putDown,
      isFalse,
      reason: 'the game has been played since that write began',
    );
    writer.leftFront();
    expect(writes, hasLength(2), reason: 'so the next time away writes anew');
  });

  test('away again before a stale write ends, the game is written again '
      'as it is now', () async {
    writer
      ..leftFront()
      ..cameToFront()
      ..leftFront();
    expect(writes, hasLength(1), reason: 'the slow write is still under way');
    writes.single.complete(true);
    await settle();
    expect(writes, hasLength(2), reason: 'a fresh write of the game as left');
    expect(writer.putDown, isFalse);
    writes.last.complete(true);
    await settle();
    expect(writer.putDown, isTrue);
  });

  test('closed, nothing is written any more', () async {
    writer
      ..leftFront()
      ..cameToFront()
      ..leftFront()
      ..close();
    writes.single.complete(true);
    await settle();
    expect(writes, hasLength(1));
    expect(writer.putDown, isFalse);
    writer.leftFront();
    expect(writes, hasLength(1));
  });

  test('a write that throws lets go of the writer, and the error out to '
      'whoever catches what nobody caught', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      writer = PutDownWriter(() async => throw StateError('broken'))
        ..leftFront();
      await settle();
    }, (error, _) => errors.add(error));
    expect(errors.single, isA<StateError>());
    expect(writer.writing, isFalse);
    expect(writer.putDown, isFalse);
  });
}
